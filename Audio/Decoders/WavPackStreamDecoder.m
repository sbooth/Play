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
	int				result		= WavpackSeekSample(_wpc, frame);
	return (result ? frame : -1);
}

- (BOOL) setupDecoder:(NSError **)error
{
	char errorBuf [80];
	
	[super setupDecoder:error];
	
	// Setup converter
	_wpc = WavpackOpenFileInput([[[[self stream] valueForKey:StreamURLKey] path] fileSystemRepresentation], errorBuf, 0, 0);
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
	_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
	
	_pcmFormat.mSampleRate			= WavpackGetSampleRate(_wpc);
	_pcmFormat.mChannelsPerFrame	= WavpackGetNumChannels(_wpc);
	_pcmFormat.mBitsPerChannel		= WavpackGetBitsPerSample(_wpc);
	
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
	UInt32				bytesToWrite, bytesAvailableToWrite;
	UInt32				spaceRequired;
	void				*writePointer;
	int32_t				inputBuffer [WP_INPUT_BUFFER_LEN];
	uint32_t			samplesRead;
	uint32_t			sample;
	int32_t				audioSample;
	int8_t				*alias8;
	int16_t				*alias16;
	int32_t				*alias32;
	
	for(;;) {
		bytesToWrite				= RING_BUFFER_WRITE_CHUNK_SIZE;
		bytesAvailableToWrite		= [[self pcmBuffer] lengthAvailableToWriteReturningPointer:&writePointer];
		spaceRequired				= WP_INPUT_BUFFER_LEN /* * [self pcmFormat].mChannelsPerFrame */ * ([self pcmFormat].mBitsPerChannel / 8);	
		
		if(bytesAvailableToWrite < bytesToWrite || spaceRequired > bytesAvailableToWrite) {
			break;
		}
				
		// Wavpack uses "complete" samples (one sample across all channels), i.e. a Core Audio frame
		samplesRead		= WavpackUnpackSamples(_wpc, inputBuffer, WP_INPUT_BUFFER_LEN / [self pcmFormat].mChannelsPerFrame);

		// Handle floating point files
		// Perform hard clipping and convert to integers
		if(MODE_FLOAT & WavpackGetMode(_wpc) && 127 == WavpackGetFloatNormExp(_wpc)) {
			float f;
			alias32 = inputBuffer;
			for(sample = 0; sample < samplesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
				f =  * ((float *) alias32);
				
				if(f > 1.0)		{ f = 1.0; }
				if(f < -1.0)	{ f = -1.0; }
				
//				*alias32++ = (int32_t) (f * 2147483647.0);
				*alias32++ = (int32_t) (f * 32767.0);
			}
		}

		switch([self pcmFormat].mBitsPerChannel) {
			
			case 8:
				
				// No need for byte swapping
				alias8 = writePointer;
				for(sample = 0; sample < samplesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
					*alias8++ = (int8_t)inputBuffer[sample];
				}
					
				[[self pcmBuffer] didWriteLength:samplesRead * [self pcmFormat].mChannelsPerFrame * sizeof(int8_t)];
				
				break;
				
			case 16:
				
				// Convert to big endian byte order 
				alias16 = writePointer;
				for(sample = 0; sample < samplesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
					*alias16++ = (int16_t)OSSwapHostToBigInt16((int16_t)inputBuffer[sample]);
				}
					
				[[self pcmBuffer] didWriteLength:samplesRead * [self pcmFormat].mChannelsPerFrame * sizeof(int16_t)];
				
				break;
				
			case 24:
				
				// Convert to big endian byte order 
				alias8 = writePointer;
				for(sample = 0; sample < samplesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
					audioSample	= OSSwapHostToBigInt32(inputBuffer[sample]);
					*alias8++	= (int8_t)(audioSample >> 16);
					*alias8++	= (int8_t)(audioSample >> 8);
					*alias8++	= (int8_t)audioSample;
				}
					
				[[self pcmBuffer] didWriteLength:samplesRead * [self pcmFormat].mChannelsPerFrame * 3 * sizeof(int8_t)];
				
				break;
				
			case 32:
				
				// Convert to big endian byte order 
				alias32 = writePointer;
				for(sample = 0; sample < samplesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
					*alias32++ = OSSwapHostToBigInt32(inputBuffer[sample]);
				}
					
				[[self pcmBuffer] didWriteLength:samplesRead * [self pcmFormat].mChannelsPerFrame * sizeof(int32_t)];
				
				break;
				
			default:
				NSLog(@"Sample size not supported");
				samplesRead = 0;
				break;	
		}

		// EOS?
		if(0 == samplesRead) {
			[self setAtEndOfStream:YES];
			break;
		}		
	}
}

@end
