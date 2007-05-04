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

#import "WavPackStreamDecoder.h"
#import "AudioStream.h"

#define WP_INPUT_BUFFER_LEN		1024

@implementation WavPackStreamDecoder

- (NSString *) sourceFormatDescription
{
	return [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@, %u channels, %u Hz", @"Formats", @""), NSLocalizedStringFromTable(@"WavPack", @"Formats", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate];
}

- (BOOL) supportsSeeking
{
	return YES;
}

- (SInt64) performSeekToFrame:(SInt64)frame
{
	int result = WavpackSeekSample(_wpc, frame);
	return (result ? frame : -1);
}

- (BOOL) setupDecoder:(NSError **)error
{
	char errorBuf [80];
	
	[super setupDecoder:error];
	
	// Setup converter
	_wpc = WavpackOpenFileInput([[[[self stream] valueForKey:StreamURLKey] path] fileSystemRepresentation], errorBuf, OPEN_NORMALIZE, 0);
	if(NULL == _wpc) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" could not be found.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:[[[self stream] valueForKey:StreamURLKey] path]]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"File Not Found", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file may have been renamed or deleted, or exist on removable media.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:AudioStreamDecoderErrorDomain 
										 code:AudioStreamDecoderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		return NO;
	}
	
	// Setup input format descriptor
	_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
	_pcmFormat.mFormatFlags			= kAudioFormatFlagsNativeFloatPacked;
	
	_pcmFormat.mSampleRate			= WavpackGetSampleRate(_wpc);
	_pcmFormat.mChannelsPerFrame	= WavpackGetNumChannels(_wpc);
	_pcmFormat.mBitsPerChannel		= 32;
	
	_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
	_pcmFormat.mFramesPerPacket		= 1;
	_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
	
	[self setTotalFrames:WavpackGetNumSamples(_wpc)];

	// WavPack doesn't have default channel mappings so for now only support mono and stereo
/*	if(1 != _pcmFormat.mBitsPerChannel && 2 != _pcmFormat.mBitsPerChannel) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [[[self stream] valueForKey:StreamURLKey] path];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The format of the file \"%@\" is not supported.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Unsupported WavPack format", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Only mono and stereo is supported for WavPack.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:AudioStreamDecoderErrorDomain 
										 code:AudioStreamDecoderFileFormatNotSupportedError 
									 userInfo:errorDictionary];
		}		
		
		return NO;
	}
	
	// Setup the channel layout
	_channelLayout.mChannelLayoutTag  = (1 == _pcmFormat.mChannelsPerFrame ? kAudioChannelLayoutTag_Mono : kAudioChannelLayoutTag_Stereo);
*/
	return YES;
}

- (BOOL) cleanupDecoder:(NSError **)error
{
	if(NULL != _wpc) {
		WavpackCloseFile(_wpc);
		_wpc = NULL;
	}

	[super cleanupDecoder:error];
	
	return YES;
}

- (void) fillPCMBuffer
{
	void				*writePointer;
	int32_t				inputBuffer [WP_INPUT_BUFFER_LEN];
	uint32_t			sample;
	
	for(;;) {
		UInt32	bytesToWrite				= RING_BUFFER_WRITE_CHUNK_SIZE;
		UInt32	bytesAvailableToWrite		= [[self pcmBuffer] lengthAvailableToWriteReturningPointer:&writePointer];
		UInt32	spaceRequired				= WP_INPUT_BUFFER_LEN /* * [self pcmFormat].mChannelsPerFrame */ * ([self pcmFormat].mBitsPerChannel / 8);	
		
		if(bytesAvailableToWrite < bytesToWrite || spaceRequired > bytesAvailableToWrite) {
			break;
		}
				
		// Wavpack uses "complete" samples (one sample across all channels), i.e. a Core Audio frame
		uint32_t samplesRead = WavpackUnpackSamples(_wpc, inputBuffer, WP_INPUT_BUFFER_LEN / [self pcmFormat].mChannelsPerFrame);

		// Handle floating point files
		if(MODE_FLOAT & WavpackGetMode(_wpc)) {
			
			if(127 != WavpackGetFloatNormExp(_wpc)) {
				NSLog(@"Floating point data not scaled to +/- 1.0");
				return;
			}
			
			float	*inputFloatBuffer	= (float *)inputBuffer;
			float	*floatBuffer		= (float *)writePointer;
			float	audioSample			= 0;

			for(sample = 0; sample < samplesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
				audioSample		= inputFloatBuffer[sample];
				*floatBuffer++	= (audioSample < -1.0 ? -1.0 : (audioSample > 1.0 ? 1.0 : audioSample));
			}

			[[self pcmBuffer] didWriteLength:samplesRead * (32 / 8)];
		}
		else {
			float	*floatBuffer	= (float *)writePointer;
			double	scaleFactor		= (1LL << WavpackGetBitsPerSample(_wpc));
			double	audioSample		= 0;

			for(sample = 0; sample < samplesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {

				if(0 <= inputBuffer[sample]) {
					audioSample = (double)(inputBuffer[sample] / (scaleFactor - 1));
				}
				else {
					audioSample = (double)(inputBuffer[sample] / scaleFactor);
				}
				
				*floatBuffer++ = (float)(audioSample < -1.0 ? -1.0 : (audioSample > 1.0 ? 1.0 : audioSample));
			}
			
			[[self pcmBuffer] didWriteLength:samplesRead * (32 / 8)];
		}

		// EOS?
		if(0 == samplesRead) {
			[self setAtEndOfStream:YES];
			break;
		}		
	}
}

@end
