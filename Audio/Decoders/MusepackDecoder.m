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

#import "MusepackDecoder.h"
#import "AudioStream.h"

@implementation MusepackDecoder

- (id) initWithURL:(NSURL *)url error:(NSError **)error
{
	NSParameterAssert(nil != url);
	
	if((self = [super initWithURL:url error:error])) {
		
		_file = fopen([[[self URL] path] fileSystemRepresentation], "r");
		if(NULL == _file) {		
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
		
		mpc_reader_setup_file_reader(&_reader_file, _file);
		
		// Get input file information
		mpc_streaminfo streaminfo;
		mpc_streaminfo_init(&streaminfo);
		mpc_int32_t intResult = mpc_streaminfo_read(&streaminfo, &_reader_file.reader);
		if(ERROR_CODE_OK != intResult) {
			if(nil != error) {
				NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
				
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Musepack file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:[[self URL] path]]] forKey:NSLocalizedDescriptionKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a Musepack file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
				
				*error = [NSError errorWithDomain:AudioDecoderErrorDomain 
											 code:AudioDecoderFileFormatNotRecognizedError 
										 userInfo:errorDictionary];
			}
			[self release];
			return nil;
		}
		
		// Set up the decoder
		mpc_decoder_setup(&_decoder, &_reader_file.reader);
		mpc_bool_t boolResult = mpc_decoder_initialize(&_decoder, &streaminfo);
		NSAssert(YES == boolResult, NSLocalizedStringFromTable(@"Unable to intialize the Musepack decoder.", @"Errors", @""));
		
		// MPC doesn't have default channel mappings so for now only support mono and stereo
		/*	if(1 != streaminfo.channels && 2 != streaminfo.channels) {
			if(nil != error) {
				NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
				NSString				*path				= [[[self stream] valueForKey:StreamURLKey] path];
				
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The format of the file \"%@\" is not supported.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"Unsupported Musepack format", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"Only mono and stereo is supported for Musepack.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
				
				*error = [NSError errorWithDomain:AudioStreamDecoderErrorDomain 
											 code:AudioStreamDecoderFileFormatNotSupportedError 
										 userInfo:errorDictionary];
			}		
		
		return NO;
		}*/
		
		_format.mSampleRate			= streaminfo.sample_freq;
		_format.mChannelsPerFrame	= streaminfo.channels;
		
		_totalFrames = mpc_streaminfo_get_length_samples(&streaminfo);
		
		// Setup the channel layout
		switch(streaminfo.channels) {
			case 1:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;				break;
			case 2:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;			break;
		}
		
		// Allocate the buffer list
		_bufferList = calloc(sizeof(AudioBufferList) + (sizeof(AudioBuffer) * (_format.mChannelsPerFrame - 1)), 1);
		NSAssert(NULL != _bufferList, @"Unable to allocate memory");
		
		_bufferList->mNumberBuffers = _format.mChannelsPerFrame;
		
		unsigned i;
		for(i = 0; i < _bufferList->mNumberBuffers; ++i) {
			_bufferList->mBuffers[i].mData = calloc(MPC_FRAME_LENGTH, sizeof(float));
			NSAssert(NULL != _bufferList->mBuffers[i].mData, @"Unable to allocate memory");
			
			_bufferList->mBuffers[i].mNumberChannels = 1;
		}		
	}
	return self;
}

- (void) dealloc
{
	if(_file)
		fclose(_file), _file = NULL;
	
	if(_bufferList) {
		unsigned i;
		for(i = 0; i < _bufferList->mNumberBuffers; ++i)
			free(_bufferList->mBuffers[i].mData), _bufferList->mBuffers[i].mData = NULL;	
		free(_bufferList), _bufferList = NULL;
	}
	
	[super dealloc];
}

- (SInt64)			totalFrames						{ return _totalFrames; }
- (SInt64)			currentFrame					{ return _currentFrame; }

- (BOOL)			supportsSeeking					{ return YES; }

- (SInt64) seekToFrame:(SInt64)frame
{
	NSParameterAssert(0 <= frame && frame < [self totalFrames]);
	
	mpc_bool_t result = mpc_decoder_seek_sample(&_decoder, frame);
	if(result)
		_currentFrame = frame;
	
	return (result ? _currentFrame : -1);
}

- (UInt32) readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount
{
	NSParameterAssert(NULL != bufferList);
	NSParameterAssert(bufferList->mNumberBuffers == _format.mChannelsPerFrame);
	NSParameterAssert(0 < frameCount);
	
	MPC_SAMPLE_FORMAT	buffer			[MPC_DECODER_BUFFER_LENGTH];
	UInt32				framesRead		= 0;
	
	// Reset output buffer data size
	unsigned i;
	for(i = 0; i < bufferList->mNumberBuffers; ++i)
		bufferList->mBuffers[i].mDataByteSize = 0;
	
	for(;;) {
		UInt32	framesRemaining	= frameCount - framesRead;
		UInt32	framesToSkip	= bufferList->mBuffers[0].mDataByteSize / sizeof(float);
		UInt32	framesInBuffer	= _bufferList->mBuffers[0].mDataByteSize / sizeof(float);
		UInt32	framesToCopy	= (framesInBuffer > framesRemaining ? framesRemaining : framesInBuffer);
		
		// Copy data from the buffer to output
		for(i = 0; i < _bufferList->mNumberBuffers; ++i) {
			float *floatBuffer = bufferList->mBuffers[i].mData;
			memcpy(floatBuffer + framesToSkip, _bufferList->mBuffers[i].mData, framesToCopy * sizeof(float));
			bufferList->mBuffers[i].mDataByteSize += (framesToCopy * sizeof(float));
			
			// Move remaining data in buffer to beginning
			if(framesToCopy != framesInBuffer) {
				floatBuffer = _bufferList->mBuffers[i].mData;
				memmove(floatBuffer, floatBuffer + framesToCopy, (framesInBuffer - framesToCopy) * sizeof(float));
			}
			
			_bufferList->mBuffers[i].mDataByteSize -= (framesToCopy * sizeof(float));
		}
		
		framesRead += framesToCopy;
		
		// All requested frames were read
		if(framesRead == frameCount)
			break;
		
		// Decode one frame of MPC data
		mpc_uint32_t framesDecoded = mpc_decoder_decode(&_decoder, buffer, 0, 0);
		if((mpc_uint32_t)-1 == framesDecoded) {
			NSLog(NSLocalizedStringFromTable(@"Musepack decoding error.", @"Errors", @""));
			break;
		}
		
		// End of input
		if(0 == framesDecoded)
			break;
		
#ifdef MPC_FIXED_POINT
#error "Fixed point not yet supported"
#else
		float		*inputBuffer	= (float *)buffer;
		float		audioSample		= 0;
		unsigned	channel, sample;
		
		// Deinterleave the normalized samples
		for(channel = 0; channel < _format.mChannelsPerFrame; ++channel) {
			float *floatBuffer = _bufferList->mBuffers[channel].mData;
			
			for(sample = channel; sample < framesDecoded * _format.mChannelsPerFrame; sample += _format.mChannelsPerFrame) {
				audioSample = inputBuffer[sample];				
				*floatBuffer++	= (audioSample < -1.0 ? -1.0 : (audioSample > 1.0 ? 1.0 : audioSample));
			}
			
			_bufferList->mBuffers[channel].mNumberChannels	= 1;
			_bufferList->mBuffers[channel].mDataByteSize	= framesDecoded * sizeof(float);
		}
#endif /* MPC_FIXED_POINT */		
	}
	
	_currentFrame += framesRead;
	return framesRead;
}

- (NSString *) sourceFormatDescription
{
	return [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@, %u channels, %u Hz", @"Formats", @""), NSLocalizedStringFromTable(@"Musepack", @"Formats", @""), [self format].mChannelsPerFrame, (unsigned)[self format].mSampleRate];
}

@end
