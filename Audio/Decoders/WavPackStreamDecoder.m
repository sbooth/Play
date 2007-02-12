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
	return [NSString stringWithFormat:@"%@, %u channels, %u Hz", NSLocalizedStringFromTable(@"WavPack", @"General", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate];
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
	char					errorBuf [80];
	
	[super setupDecoder:error];
	
	// Setup converter
	_wpc = WavpackOpenFileInput([[[[self stream] valueForKey:StreamURLKey] path] fileSystemRepresentation], errorBuf, 0, 0);
	NSAssert1(NULL != _wpc, @"Unable to open the input file (%s).", errorBuf);
	
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
	
	return YES;
}

- (BOOL) cleanupDecoder:(NSError **)error
{
	WavpackCloseFile(_wpc);
	_wpc = NULL;

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
				@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
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
