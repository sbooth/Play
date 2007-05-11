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

#import "OggVorbisStreamDecoder.h"
#import "AudioStream.h"

#define OV_DECODER_BUFFER_LENGTH 1024

@implementation OggVorbisStreamDecoder

- (NSString *) sourceFormatDescription
{
	return [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@, %u channels, %u Hz", @"Formats", @""), NSLocalizedStringFromTable(@"Ogg (Vorbis)", @"Formats", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate];
}

- (BOOL) supportsSeeking
{
	return YES;
}

- (SInt64) performSeekToFrame:(SInt64)frame
{
	int		result		= ov_pcm_seek(&_vf, frame); 
	return (0 == result ? frame : -1);
}

- (BOOL) setupDecoder:(NSError **)error
{
	[super setupDecoder:error];

	FILE *file = fopen([[[[self stream] valueForKey:StreamURLKey] path] fileSystemRepresentation], "r");
	if(NULL == file) {		
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
	
	int result = ov_test(file, &_vf, NULL, 0);
	if(0 != result) {		
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Ogg file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:[[[self stream] valueForKey:StreamURLKey] path]]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not an Ogg file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioStreamDecoderErrorDomain 
										 code:AudioStreamDecoderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		fclose(file);
		return NO;
	}
	
	result = ov_test_open(&_vf);
	NSAssert(0 == result, NSLocalizedStringFromTable(@"Unable to open the input file.", @"Errors", @""));
	
	// Get input file information
	vorbis_info *ovInfo = ov_info(&_vf, -1);
	NSAssert(NULL != ovInfo, @"Unable to get information on Ogg Vorbis stream.");
	
	// Vorbis doesn't have default channel mappings so for now only support mono and stereo
/*	if(1 != ovInfo->channels && 2 != ovInfo->channels) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [[[self stream] valueForKey:StreamURLKey] path];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The format of the file \"%@\" is not supported.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Unsupported Ogg Vorbis format", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Only mono and stereo is supported for Ogg Vorbis.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:AudioStreamDecoderErrorDomain 
										 code:AudioStreamDecoderFileFormatNotSupportedError 
									 userInfo:errorDictionary];
		}		
		
		return NO;
	}*/

	[self setTotalFrames:ov_pcm_total(&_vf, -1)];

	// Setup input format descriptor
	_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
	_pcmFormat.mFormatFlags			= kAudioFormatFlagsNativeFloatPacked;
	
	_pcmFormat.mSampleRate			= ovInfo->rate;
	_pcmFormat.mChannelsPerFrame	= ovInfo->channels;
	_pcmFormat.mBitsPerChannel		= 32;
	
	_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
	_pcmFormat.mFramesPerPacket		= 1;
	_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
	
	// Setup the channel layout
//	_channelLayout.mChannelLayoutTag  = (1 == _pcmFormat.mChannelsPerFrame ? kAudioChannelLayoutTag_Mono : kAudioChannelLayoutTag_Stereo);

	return YES;
}

- (BOOL) cleanupDecoder:(NSError **)error
{
	int result = ov_clear(&_vf); 
	
	if(0 != result) {
		NSLog(@"ov_clear failed");
	}

	[super cleanupDecoder:error];
	
	return YES;
}

- (void) fillPCMBuffer
{
	void			*writePointer				= NULL;
	int16_t			inputBuffer					[OV_DECODER_BUFFER_LENGTH];
	unsigned		inputBufferSize				= OV_DECODER_BUFFER_LENGTH * sizeof(int16_t);
	unsigned		sample						= 0;
	UInt32			bytesToWrite				= RING_BUFFER_WRITE_CHUNK_SIZE;
	UInt32			bytesAvailableToWrite		= [[self pcmBuffer] lengthAvailableToWriteReturningPointer:&writePointer];
	float			*floatBuffer				= (float *)writePointer;
	int				currentSection				= 0;
	UInt32			totalBytesWritten			= 0;
	UInt32			currentBytesWritten			= 0;
	long			bytesRead					= 0;

	if(bytesToWrite > bytesAvailableToWrite) {
		return;
	}

	while(0 < bytesAvailableToWrite) {

		UInt32 bytesToRead = (bytesAvailableToWrite / 2) > inputBufferSize ? inputBufferSize : bytesAvailableToWrite / 2;
		
		// Always grab in host byte order
#if __BIG_ENDIAN__
		bytesRead = ov_read(&_vf, (char *)inputBuffer, bytesToRead, YES, sizeof(int16_t), YES, &currentSection);
#else
		bytesRead = ov_read(&_vf, (char *)inputBuffer, bytesToRead, NO, sizeof(int16_t), YES, &currentSection);
#endif
		
		if(0 > bytesRead) {
			NSLog(@"Ogg Vorbis decode error.");
			return;
		}
		
		unsigned	framesRead		= (bytesRead / sizeof(int16_t)) / [self pcmFormat].mChannelsPerFrame;
		float		scaleFactor		= (1L << (16 - 1));
		float		audioSample		= 0;
		
		for(sample = 0; sample < framesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
			
			if(0 <= inputBuffer[sample]) {
				audioSample = (float)(inputBuffer[sample] / (scaleFactor - 1));
			}
			else {
				audioSample = (float)(inputBuffer[sample] / scaleFactor);
			}
			
			*floatBuffer++ = (float)(audioSample < -1.0 ? -1.0 : (audioSample > 1.0 ? 1.0 : audioSample));
		}

		currentBytesWritten		= framesRead * [self pcmFormat].mChannelsPerFrame * (32 / 8);
		totalBytesWritten		+= currentBytesWritten;
		bytesAvailableToWrite	-= currentBytesWritten;

		if(0 == bytesRead) {
			break;
		}
	}

	if(0 < totalBytesWritten) {
		[[self pcmBuffer] didWriteLength:totalBytesWritten];				
	}
	
	if(0 == bytesRead) {
		[self setAtEndOfStream:YES];
	}
}

@end
