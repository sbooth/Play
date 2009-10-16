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

#import "MonkeysAudioDecoder.h"
#import "AudioStream.h"
#include <mac/All.h>
#include <mac/MACLib.h>
#include <mac/APEDecompress.h>
#include <mac/CharacterHelper.h>

#define SELF_DECOMPRESSOR			(reinterpret_cast<IAPEDecompress *>(_decompressor))
#define APE_DECODER_BUFFER_BLOCKS	512

@implementation MonkeysAudioDecoder

- (id) initWithURL:(NSURL *)url error:(NSError **)error
{
	NSParameterAssert(nil != url);
	
	if((self = [super initWithURL:url error:error])) {
		
		// Setup converter
		str_utf16 *chars = GetUTF16FromANSI([[[self URL] path] fileSystemRepresentation]);
		NSAssert(NULL != chars, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
		
		int result;
		_decompressor = (void *)CreateIAPEDecompress(chars, &result);
		NSAssert(NULL != _decompressor && ERROR_SUCCESS == result, @"Unable to open the input file.");
		
		delete [] chars;
		
		_format.mSampleRate			= SELF_DECOMPRESSOR->GetInfo(APE_INFO_SAMPLE_RATE);
		_format.mChannelsPerFrame	= SELF_DECOMPRESSOR->GetInfo(APE_INFO_CHANNELS);

		_sourceFormat.mSampleRate			= SELF_DECOMPRESSOR->GetInfo(APE_INFO_SAMPLE_RATE);
		_sourceFormat.mChannelsPerFrame		= SELF_DECOMPRESSOR->GetInfo(APE_INFO_CHANNELS);
		_sourceFormat.mBitsPerChannel		= SELF_DECOMPRESSOR->GetInfo(APE_INFO_BITS_PER_SAMPLE);

		_totalFrames = SELF_DECOMPRESSOR->GetInfo(APE_DECOMPRESS_TOTAL_BLOCKS);
		
		// Setup the channel layout
		// FIXME: Grab the WAVEFORMATEX and figure out the channel mapping
		switch(_format.mChannelsPerFrame) {
			case 1:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;				break;
			case 2:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;			break;
		}
		
		// Determine the bits per sample and bytes per sample to work with
		_bitsPerSample = SELF_DECOMPRESSOR->GetInfo(APE_INFO_BITS_PER_SAMPLE);
		NSAssert(0 != _bitsPerSample, @"Unable to determine the Monkey's Audio bits per sample.");
		
		_bytesPerSample = SELF_DECOMPRESSOR->GetInfo(APE_INFO_BYTES_PER_SAMPLE);
		NSAssert(0 != _bytesPerSample, @"Unable to determine the Monkey's Audio bytes per sample.");
		
		// blockAlign is the size (in bytes) of an audio frame (a single sample across all channels)
		_blockAlign = SELF_DECOMPRESSOR->GetInfo(APE_INFO_BLOCK_ALIGN);
		NSAssert(0 != _blockAlign, @"Unable to determine the Monkey's Audio block alignment.");
		
		// Allocate the buffer list
		_bufferList = (AudioBufferList *)calloc(sizeof(AudioBufferList) + (sizeof(AudioBuffer) * (_format.mChannelsPerFrame - 1)), 1);
		NSAssert(NULL != _bufferList, @"Unable to allocate memory");
		
		_bufferList->mNumberBuffers = _format.mChannelsPerFrame;
		
		unsigned i;
		for(i = 0; i < _bufferList->mNumberBuffers; ++i) {
			_bufferList->mBuffers[i].mData = calloc(APE_DECODER_BUFFER_BLOCKS, sizeof(float));
			NSAssert(NULL != _bufferList->mBuffers[i].mData, @"Unable to allocate memory");
			
			_bufferList->mBuffers[i].mNumberChannels = 1;
		}		
	}
	return self;
}

- (void) dealloc
{
	delete SELF_DECOMPRESSOR;
	_decompressor = NULL;
	
	[super dealloc];
}

- (SInt64)			totalFrames							{ return _totalFrames; }
- (SInt64)			currentFrame						{ return _currentFrame; }

- (BOOL)			supportsSeeking						{ return YES; }

- (SInt64) seekToFrame:(SInt64)frame
{
	NSParameterAssert(0 <= frame && frame < [self totalFrames]);
	
	int result = SELF_DECOMPRESSOR->Seek(frame);
	if(ERROR_SUCCESS == result)
		_currentFrame = frame;
	
	return (ERROR_SUCCESS == result ? _currentFrame : -1);
}

- (UInt32) readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount
{
	NSParameterAssert(NULL != bufferList);
	NSParameterAssert(bufferList->mNumberBuffers == _format.mChannelsPerFrame);
	NSParameterAssert(0 < frameCount);
	
	uint8_t		*buffer			= new uint8_t [APE_DECODER_BUFFER_BLOCKS * _blockAlign];
	UInt32		framesRead		= 0;
	
	// Zero output buffers
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
			float *floatBuffer = (float *)bufferList->mBuffers[i].mData;
			memcpy(floatBuffer + framesToSkip, _bufferList->mBuffers[i].mData, framesToCopy * sizeof(float));
			bufferList->mBuffers[i].mDataByteSize += (framesToCopy * sizeof(float));
			
			// Move remaining data in buffer to beginning
			if(framesToCopy != framesInBuffer) {
				floatBuffer = (float *)_bufferList->mBuffers[i].mData;
				memmove(floatBuffer, floatBuffer + framesToCopy, (framesInBuffer - framesToCopy) * sizeof(float));
			}
			
			_bufferList->mBuffers[i].mDataByteSize -= (framesToCopy * sizeof(float));
		}
		
		framesRead += framesToCopy;
		
		// All requested frames were read
		if(framesRead == frameCount)
			break;
		
		// Decompress some APE data
		int blocksRetrieved = 0;
		int result = SELF_DECOMPRESSOR->GetData((char *)buffer, APE_DECODER_BUFFER_BLOCKS, &blocksRetrieved);
		if(ERROR_SUCCESS != result) {
			NSLog(@"Monkey's Audio invalid checksum.");
			break;
		}

		// End of input
		if(0 == blocksRetrieved)
			break;
		
		float		scaleFactor		= (1L << ((((_bitsPerSample + 7) / 8) * 8) - 1));
		int32_t		actualSample	= 0;
		int8_t		sample8			= 0;
		int16_t		sample16		= 0;
		int32_t		sample32		= 0;
		unsigned	channel, sample;
		
		// Deinterleave the samples and convert to normalized float
		for(channel = 0; channel < _format.mChannelsPerFrame; ++channel) {
			float *floatBuffer = (float *)_bufferList->mBuffers[channel].mData;
			
			for(sample = channel; sample < blocksRetrieved * _format.mChannelsPerFrame; sample += _format.mChannelsPerFrame) {
				switch(_bytesPerSample) {
					case (8 / 8):
						sample8 = *((int8_t *)(buffer + (sample * _bytesPerSample)));
						actualSample = sample8;
						break;
						
					case (16 / 8):
						sample16 = *((int16_t *)(buffer + (sample * _bytesPerSample)));
						actualSample = sample16;
						break;
						
					case (24 / 8):
						memcpy((&sample32) + sizeof(int8_t), buffer + (sample * _bytesPerSample), _bytesPerSample);
						actualSample = sample32;
						break;
						
					case (32 / 8):
						sample32 = *((int32_t *)(buffer + (sample * _bytesPerSample)));
						actualSample = sample32;
						break;
				}
				
				*floatBuffer++ = (float)(actualSample / scaleFactor);
			}
			
			_bufferList->mBuffers[channel].mNumberChannels	= 1;
			_bufferList->mBuffers[channel].mDataByteSize	= blocksRetrieved * sizeof(float);
		}
	}
	
	delete [] buffer;
	
	_currentFrame += framesRead;
	return framesRead;
}

- (NSString *) sourceFormatDescription
{
	return [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@, %u channels, %u Hz", @"Formats", @""), NSLocalizedStringFromTable(@"Monkey's Audio", @"Formats", @""), [self format].mChannelsPerFrame, (unsigned)[self format].mSampleRate];
}

@end
