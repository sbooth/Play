/*
 *  $Id$
 *
 *  Copyright (C) 2006 - 2007 Stephen F. Booth <me@sbooth.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import "WavPackDecoder.h"
#import "AudioStream.h"

@implementation WavPackDecoder

- (id) initWithURL:(NSURL *)url error:(NSError **)error
{
	NSParameterAssert(nil != url);
	
	if((self = [super initWithURL:url error:error])) {
		char errorBuf [80];
		
		// Setup converter
		_wpc = WavpackOpenFileInput([[[self URL] path] fileSystemRepresentation], errorBuf, OPEN_WVC | OPEN_NORMALIZE, 0);
		if(NULL == _wpc) {
			if(nil != error) {
				NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
				
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" could not be found.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:[[self URL] path]]] forKey:NSLocalizedDescriptionKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"File Not Found", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"The file may have been renamed or deleted, or exist on removable media.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
				
				*error = [NSError errorWithDomain:AudioDecoderErrorDomain 
											 code:AudioDecoderFileNotFoundError 
										 userInfo:errorDictionary];
			}
			[self release];
			return nil;
		}
		
		_format.mSampleRate			= WavpackGetSampleRate(_wpc);
		_format.mChannelsPerFrame	= WavpackGetNumChannels(_wpc);
		
		// The source's PCM format
		_sourceFormat.mFormatID				= kAudioFormatLinearPCM;
		_sourceFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian;
		
		_sourceFormat.mSampleRate			= WavpackGetSampleRate(_wpc);
		_sourceFormat.mChannelsPerFrame		= WavpackGetNumChannels(_wpc);
		_sourceFormat.mBitsPerChannel		= WavpackGetBitsPerSample(_wpc);
		
		_sourceFormat.mBytesPerPacket		= ((_sourceFormat.mBitsPerChannel + 7) / 8) * _sourceFormat.mChannelsPerFrame;
		_sourceFormat.mFramesPerPacket		= 1;
		_sourceFormat.mBytesPerFrame		= _sourceFormat.mBytesPerPacket * _sourceFormat.mFramesPerPacket;		
		
		_totalFrames = WavpackGetNumSamples(_wpc);
		
		// Setup the channel layout
		switch(_format.mChannelsPerFrame) {
			case 1:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;				break;
			case 2:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;			break;
		}
	}
	return self;
}

- (void) dealloc
{
	if(_wpc)
		WavpackCloseFile(_wpc), _wpc = NULL;
	
	[super dealloc];
}

- (SInt64)			totalFrames							{ return _totalFrames; }
- (SInt64)			currentFrame						{ return _currentFrame; }

- (BOOL)			supportsSeeking						{ return YES; }

- (SInt64) seekToFrame:(SInt64)frame
{
	NSParameterAssert(0 <= frame && frame < [self totalFrames]);
	
	int result = WavpackSeekSample(_wpc, frame);
	if(result)
		_currentFrame = frame;
	
	return (result ? _currentFrame : -1);
}

- (UInt32) readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount
{
	NSParameterAssert(NULL != bufferList);
	NSParameterAssert(bufferList->mNumberBuffers == _format.mChannelsPerFrame);
	NSParameterAssert(0 < frameCount);
	
	int32_t *buffer = calloc(frameCount * _format.mChannelsPerFrame, sizeof(int32_t));
	if(NULL == buffer) {
		NSLog(@"Unable to allocate memory");
		return 0;
	}
	
	// Wavpack uses "complete" samples (one sample across all channels), i.e. a Core Audio frame
	uint32_t samplesRead = WavpackUnpackSamples(_wpc, buffer, frameCount);
	
	// Handle floating point files
	if(MODE_FLOAT & WavpackGetMode(_wpc)) {
		float		*inputBuffer	= (float *)buffer;
		float		audioSample		= 0;
		unsigned	channel, sample;
		
		// Deinterleave the normalized samples
		for(channel = 0; channel < _format.mChannelsPerFrame; ++channel) {
			float *floatBuffer = bufferList->mBuffers[channel].mData;
			
			for(sample = channel; sample < samplesRead * _format.mChannelsPerFrame; sample += _format.mChannelsPerFrame) {
				audioSample = inputBuffer[sample];				
				*floatBuffer++	= (audioSample < -1.0 ? -1.0 : (audioSample > 1.0 ? 1.0 : audioSample));
			}
			
			bufferList->mBuffers[channel].mNumberChannels	= 1;
			bufferList->mBuffers[channel].mDataByteSize		= samplesRead * sizeof(float);
		}
	}
	else {
		float		scaleFactor		= (1L << ((WavpackGetBytesPerSample(_wpc) * 8) - 1));
		int32_t		rawSample;
		unsigned	channel, sample;
		
		// Deinterleave the 32-bit samples and convert to float
		for(channel = 0; channel < _format.mChannelsPerFrame; ++channel) {
			float *floatBuffer = bufferList->mBuffers[channel].mData;
			
			for(sample = channel; sample < samplesRead * _format.mChannelsPerFrame; sample += _format.mChannelsPerFrame) {				
				rawSample = buffer[sample];				
				*floatBuffer++ = rawSample / scaleFactor;
			}
			
			bufferList->mBuffers[channel].mNumberChannels	= 1;
			bufferList->mBuffers[channel].mDataByteSize		= samplesRead * sizeof(float);
		}		
	}
	
	free(buffer);
	
	_currentFrame += samplesRead;
	return samplesRead;
}

- (NSString *) sourceFormatDescription
{
	return [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@, %u channels, %u Hz", @"Formats", @""), NSLocalizedStringFromTable(@"WavPack", @"Formats", @""), [self format].mChannelsPerFrame, (unsigned)[self format].mSampleRate];
}

@end
