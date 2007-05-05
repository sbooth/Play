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

#import "MonkeysAudioStreamDecoder.h"
#import "AudioStream.h"
#include <mac/All.h>
#include <mac/MACLib.h>
#include <mac/APEDecompress.h>
#include <mac/CharacterHelper.h>

#define SELF_DECOMPRESSOR	(reinterpret_cast<IAPEDecompress *>(_decompressor))
#define APE_DECODER_BUFFER_LENGTH 1024

@implementation MonkeysAudioStreamDecoder

- (NSString *) sourceFormatDescription
{
	return [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@, %u channels, %u Hz", @"Formats", @""), NSLocalizedStringFromTable(@"Monkey's Audio", @"Formats", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate];
}

- (BOOL) supportsSeeking
{
	return YES;
}

- (SInt64) performSeekToFrame:(SInt64)frame
{
	int result = SELF_DECOMPRESSOR->Seek(frame);
	return (ERROR_SUCCESS == result ? frame : -1);
}

- (BOOL) setupDecoder:(NSError **)error
{
	[super setupDecoder:error];
	
	// Setup converter
	str_utf16 *chars = GetUTF16FromANSI([[[[self stream] valueForKey:StreamURLKey] path] fileSystemRepresentation]);
	NSAssert(NULL != chars, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	
	int result;
	_decompressor = (void *)CreateIAPEDecompress(chars, &result);
	NSAssert(NULL != _decompressor && ERROR_SUCCESS == result, @"Unable to open the input file.");

	delete [] chars;

	// Setup input format descriptor
	_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
	_pcmFormat.mFormatFlags			= kAudioFormatFlagsNativeFloatPacked;
	
	_pcmFormat.mSampleRate			= SELF_DECOMPRESSOR->GetInfo(APE_INFO_SAMPLE_RATE);
	_pcmFormat.mChannelsPerFrame	= SELF_DECOMPRESSOR->GetInfo(APE_INFO_CHANNELS);
	_pcmFormat.mBitsPerChannel		= 32;
	
	_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
	_pcmFormat.mFramesPerPacket		= 1;
	_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
	
	[self setTotalFrames:SELF_DECOMPRESSOR->GetInfo(APE_DECOMPRESS_TOTAL_BLOCKS)];

	// FIXME: Grab the WAVEFORMATEX and figure out the channel mapping
/*	if(1 != _pcmFormat.mChannelsPerFrame && 2 != _pcmFormat.mChannelsPerFrame) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [[[self stream] valueForKey:StreamURLKey] path];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The format of the file \"%@\" is not supported.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Unsupported Monkey's Audio format", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Only mono and stereo is supported for Monkey's Audio.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
			
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
	delete SELF_DECOMPRESSOR;
	_decompressor = NULL;
	
	[super cleanupDecoder:error];
	
	return YES;
}

- (void) fillPCMBuffer
{
	void			*writePointer				= NULL;
	int8_t			*inputBuffer				= NULL;
	unsigned		sample						= 0;
	UInt32			bytesToWrite				= RING_BUFFER_WRITE_CHUNK_SIZE;
	UInt32			bytesAvailableToWrite		= [[self pcmBuffer] lengthAvailableToWriteReturningPointer:&writePointer];
	float			*floatBuffer				= (float *)writePointer;
	UInt32			totalBytesWritten			= 0;
	UInt32			currentBytesWritten			= 0;
	int				samplesRead					= 0;
	
	if(bytesToWrite > bytesAvailableToWrite) {
		return;
	}
	
	int bitsPerChannel = SELF_DECOMPRESSOR->GetInfo(APE_INFO_BITS_PER_SAMPLE);
	NSAssert(0 != bitsPerChannel, @"Unable to determine the Monkey's Audio bits per sample.");
	
	int bytesPerChannel = SELF_DECOMPRESSOR->GetInfo(APE_INFO_BYTES_PER_SAMPLE);
	NSAssert(0 != bytesPerChannel, @"Unable to determine the Monkey's Audio bytes per sample.");
	
	// frameSize is the size (in bytes) of an audio frame (a single sample across all channels)
	int frameSize = SELF_DECOMPRESSOR->GetInfo(APE_INFO_BLOCK_ALIGN);
	NSAssert(0 != frameSize, @"Unable to determine the Monkey's Audio block alignment.");

	// Determine the ratio of the APE sample size to our float sample size of 32 bits
	unsigned sampleSizeRatio = (32 / 8) / bytesPerChannel;
	
	// Allocate input buffer large enough for APE_DECODER_BUFFER_LENGTH frames
	inputBuffer = (int8_t *)calloc(APE_DECODER_BUFFER_LENGTH * frameSize, sizeof(int8_t));
	NSAssert(NULL != inputBuffer, @"Unable to allocate memory.");
	
	unsigned inputBufferSize = APE_DECODER_BUFFER_LENGTH * frameSize * sizeof(int8_t);

	while(0 < bytesAvailableToWrite) {

		UInt32 bytesToRead = (bytesAvailableToWrite / sampleSizeRatio) > inputBufferSize ? inputBufferSize : bytesAvailableToWrite / sampleSizeRatio;

		int result = SELF_DECOMPRESSOR->GetData((char *)inputBuffer, bytesToRead / frameSize, &samplesRead);
		if(ERROR_SUCCESS != result) {
			NSLog(@"Monkey's Audio invalid checksum.");
			free(inputBuffer);
			return;
		}
				
		double		scaleFactor		= (1LL << (((bitsPerChannel + 7) / 8) * 8));
		float		audioSample		= 0;
		int32_t		actualSample	= 0;
		int8_t		sample8			= 0;
		int16_t		sample16		= 0;
		int32_t		sample32		= 0;
		
		for(sample = 0; sample < samplesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
			
			switch(bytesPerChannel) {
				case (8 / 8):
					sample8 = *((int8_t *)(inputBuffer + (sample * bytesPerChannel)));
					actualSample = sample8;
					break;
					
				case (16 / 8):
					sample16 = *((int16_t *)(inputBuffer + (sample * bytesPerChannel)));
					actualSample = sample16;
					break;
				
				case (24 / 8):
					memcpy((&sample32) + sizeof(int8_t), inputBuffer + (sample * bytesPerChannel), bytesPerChannel);
					actualSample = sample32;
					break;

				case (32 / 8):
					sample32 = *((int32_t *)(inputBuffer + (sample * bytesPerChannel)));
					actualSample = sample32;
					break;
			}

			if(0 <= actualSample) {
				audioSample = (float)(actualSample / (scaleFactor - 1));
			}
			else {
				audioSample = (float)(actualSample / scaleFactor);
			}
			
			*floatBuffer++ = (float)(audioSample < -1.0 ? -1.0 : (audioSample > 1.0 ? 1.0 : audioSample));
		}
		
		currentBytesWritten		= samplesRead * [self pcmFormat].mChannelsPerFrame * (32 / 8);
		totalBytesWritten		+= currentBytesWritten;
		bytesAvailableToWrite	-= currentBytesWritten;

		if(0 == samplesRead) {
			break;
		}
	}
	
	if(0 < totalBytesWritten) {
		[[self pcmBuffer] didWriteLength:totalBytesWritten];				
	}
	
	if(0 == samplesRead) {
		[self setAtEndOfStream:YES];
	}	
	
	free(inputBuffer);
}

@end
