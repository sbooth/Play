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

@implementation MonkeysAudioStreamDecoder

- (NSString *) sourceFormatDescription
{
	return [NSString stringWithFormat:@"%@, %u channels, %u Hz", NSLocalizedStringFromTable(@"Monkey's Audio", @"General", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate];
}

- (BOOL) supportsSeeking
{
	return YES;
}

- (SInt64) performSeekToFrame:(SInt64)frame
{
	int		result		= SELF_DECOMPRESSOR->Seek(frame);
	return (ERROR_SUCCESS == result ? frame : -1);
}

- (BOOL) setupDecoder:(NSError **)error
{
	str_utf16			*chars;
	int					result;

	[super setupDecoder:error];
	
	// Setup converter
	chars			= GetUTF16FromANSI([[[[self stream] valueForKey:StreamURLKey] path] fileSystemRepresentation]);
	NSAssert(NULL != chars, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	
	_decompressor	= (void *)CreateIAPEDecompress(chars, &result);
	NSAssert(NULL != _decompressor && ERROR_SUCCESS == result, @"Unable to open the input file.");
	
	// Setup input format descriptor
	_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
	_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	
	_pcmFormat.mSampleRate			= SELF_DECOMPRESSOR->GetInfo(APE_INFO_SAMPLE_RATE);
	_pcmFormat.mChannelsPerFrame	= SELF_DECOMPRESSOR->GetInfo(APE_INFO_CHANNELS);
	_pcmFormat.mBitsPerChannel		= SELF_DECOMPRESSOR->GetInfo(APE_INFO_BITS_PER_SAMPLE);
	
	_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
	_pcmFormat.mFramesPerPacket		= 1;
	_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
	
	[self setTotalFrames:SELF_DECOMPRESSOR->GetInfo(APE_DECOMPRESS_TOTAL_BLOCKS)];

	delete [] chars;
	
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
	UInt32				bytesToWrite, bytesAvailableToWrite;
	UInt32				spaceRequired;
	void				*writePointer;
	int					result;
	int					blockSize;
	int					samplesRead;
		
	blockSize	= SELF_DECOMPRESSOR->GetInfo(APE_INFO_BLOCK_ALIGN);
	NSAssert(0 != blockSize, @"Unable to determine the Monkey's Audio block size.");
	
	for(;;) {
		bytesToWrite				= RING_BUFFER_WRITE_CHUNK_SIZE;
		bytesAvailableToWrite		= [[self pcmBuffer] lengthAvailableToWriteReturningPointer:&writePointer];
		spaceRequired				= blockSize;	
		
		if(bytesAvailableToWrite < bytesToWrite || spaceRequired > bytesAvailableToWrite) {
			break;
		}
				
		result		= SELF_DECOMPRESSOR->GetData((char *)writePointer, bytesAvailableToWrite / blockSize, &samplesRead);
		//		NSAssert(ERROR_SUCCESS == result, @"Monkey's Audio invalid checksum.");
		if(ERROR_SUCCESS != result) {
			NSLog(@"Monkey's Audio invalid checksum.");
		}
		
		[[self pcmBuffer] didWriteLength:samplesRead * blockSize];
		
		// EOS?
		if(0 == samplesRead) {
			[self setAtEndOfStream:YES];
			break;
		}		
	}
}

@end
