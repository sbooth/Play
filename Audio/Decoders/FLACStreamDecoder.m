/*
 *  $Id$
 *
 *  Copyright (C) 2006 Stephen F. Booth <me@sbooth.org>
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

#import "FLACStreamDecoder.h"
#include <FLAC/metadata.h>

@interface FLACStreamDecoder (Private)

- (void)	setSampleRate:(Float64)sampleRate;
- (void)	setBitsPerChannel:(UInt32)bitsPerChannel;
- (void)	setChannelsPerFrame:(UInt32)channelsPerFrame;

@end

static FLAC__StreamDecoderWriteStatus 
writeCallback(const FLAC__StreamDecoder *decoder, const FLAC__Frame *frame, const FLAC__int32 * const buffer[], void *client_data)
{
	FLACStreamDecoder	*streamDecoder			= (FLACStreamDecoder *)client_data;
	
	unsigned			spaceRequired			= 0;
	
	int8_t				*alias8					= NULL;
	int16_t				*alias16				= NULL;
	int32_t				*alias32				= NULL;
	
	unsigned			sample, channel;
	int32_t				audioSample;
	
	UInt32				bytesAvailableToWrite;
	void				*writePointer;

	// Calculate the number of audio data points contained in the frame (should be one for each channel)
	spaceRequired		= frame->header.blocksize * frame->header.channels * (frame->header.bits_per_sample / 8);
	bytesAvailableToWrite = [[streamDecoder pcmBuffer] lengthAvailableToWriteReturningPointer:&writePointer];

	// Increase buffer size as required
	if(bytesAvailableToWrite < spaceRequired) {
		return FLAC__STREAM_DECODER_WRITE_STATUS_ABORT;
	}
	
	switch(frame->header.bits_per_sample) {
		
		case 8:
			
			// Interleave the audio (no need for byte swapping)
			alias8 = writePointer;
			for(sample = 0; sample < frame->header.blocksize; ++sample) {
				for(channel = 0; channel < frame->header.channels; ++channel) {
					*alias8++ = (int8_t)buffer[channel][sample];
				}
			}
				
			[[streamDecoder pcmBuffer] didWriteLength:spaceRequired];
			
			break;
			
		case 16:
			
			// Interleave the audio, converting to big endian byte order 
			alias16 = writePointer;
			for(sample = 0; sample < frame->header.blocksize; ++sample) {
				for(channel = 0; channel < frame->header.channels; ++channel) {
					*alias16++ = (int16_t)OSSwapHostToBigInt16((int16_t)buffer[channel][sample]);
				}
			}
				
			[[streamDecoder pcmBuffer] didWriteLength:spaceRequired];
			
			break;
			
		case 24:				
			
			// Interleave the audio (no need for byte swapping)
			alias8 = writePointer;
			for(sample = 0; sample < frame->header.blocksize; ++sample) {
				for(channel = 0; channel < frame->header.channels; ++channel) {
					audioSample	= buffer[channel][sample];
					*alias8++	= (int8_t)(audioSample >> 16);
					*alias8++	= (int8_t)(audioSample >> 8);
					*alias8++	= (int8_t)audioSample;
				}
			}
				
			[[streamDecoder pcmBuffer] didWriteLength:spaceRequired];
			
			break;
			
		case 32:
			
			// Interleave the audio, converting to big endian byte order 
			alias32 = writePointer;
			for(sample = 0; sample < frame->header.blocksize; ++sample) {
				for(channel = 0; channel < frame->header.channels; ++channel) {
					*alias32++ = OSSwapHostToBigInt32(buffer[channel][sample]);
				}
			}
				
			[[streamDecoder pcmBuffer] didWriteLength:spaceRequired];
			
			break;
			
		default:
			@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
			break;				
	}
	
	// Always return continue; an exception will be thrown if this isn't the case
	return FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE;
}

static void
metadataCallback(const FLAC__StreamDecoder *decoder, const FLAC__StreamMetadata *metadata, void *client_data)
{
	FLACStreamDecoder	*source					= (FLACStreamDecoder *)client_data;
	//	const FLAC__StreamMetadata_CueSheet		*cueSheet			= NULL;
	//	FLAC__StreamMetadata_CueSheet_Track		*currentTrack		= NULL;
	//	FLAC__StreamMetadata_CueSheet_Index		*currentIndex		= NULL;
	//	unsigned								i, j;
	
	switch(metadata->type) {
		case FLAC__METADATA_TYPE_STREAMINFO:
			[source setSampleRate:metadata->data.stream_info.sample_rate];			
			[source setBitsPerChannel:metadata->data.stream_info.bits_per_sample];
			[source setChannelsPerFrame:metadata->data.stream_info.channels];

			[source setTotalFrames:metadata->data.stream_info.total_samples];
			break;
			
			/*
			 case FLAC__METADATA_TYPE_CUESHEET:
				 cueSheet = &(metadata->data.cue_sheet);
				 
				 for(i = 0; i < cueSheet->num_tracks; ++i) {
					 currentTrack = &(cueSheet->tracks[i]);
					 
					 FLAC__uint64 offset = currentTrack->offset;
					 
					 for(j = 0; j < currentTrack->num_indices; ++j) {
						 currentIndex = &(currentTrack->indices[j]);					
					 }
				 }
					 break;
				 */
	}
}

static void
errorCallback(const FLAC__StreamDecoder *decoder, FLAC__StreamDecoderErrorStatus status, void *client_data)
{
	//	FLACDecoder		*source		= (FLACDecoder *)client_data;
	
	//	@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__StreamDecoderErrorStatusString[status] encoding:NSASCIIStringEncoding] userInfo:nil];
}

@implementation FLACStreamDecoder

- (NSString *) sourceFormatDescription
{
	return [NSString stringWithFormat:@"%@, %u channels, %u Hz", NSLocalizedStringFromTable(@"FLAC", @"General", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate];
}

- (BOOL) supportsSeeking
{
	return YES;
}

- (SInt64) performSeekToFrame:(SInt64)frame
{
	FLAC__bool		result		= FLAC__stream_decoder_seek_absolute(_flac, frame);	
	
	// Attempt to re-sync the stream if necessary
	if(result && FLAC__STREAM_DECODER_SEEK_ERROR == FLAC__stream_decoder_get_state(_flac)) {
		result = FLAC__stream_decoder_flush(_flac);
	}
	
	return (result ? frame : -1);
}

- (BOOL) setupDecoder:(NSError **)error
{
	FLAC__bool						result;
	FLAC__StreamDecoderInitStatus	status;	
	
	[super setupDecoder:error];

	// Create FLAC decoder
	_flac		= FLAC__stream_decoder_new();
	NSAssert(NULL != _flac, @"Unable to create the FLAC decoder.");
	
	// Initialize decoder
	status		= FLAC__stream_decoder_init_file(_flac, 
												 [[[self valueForKey:@"url"] path] fileSystemRepresentation],
												 writeCallback, 
												 metadataCallback, 
												 errorCallback,
												 self);
	NSAssert1(FLAC__STREAM_DECODER_INIT_STATUS_OK == status, @"FLAC__stream_decoder_init_file failed: %s", FLAC__stream_decoder_get_resolved_state_string(_flac));

	/*
	 // Process cue sheets
	 result = FLAC__stream_decoder_set_metadata_respond(flac, FLAC__METADATA_TYPE_CUESHEET);
	 NSAssert(YES == result, @"%s", FLAC__stream_decoder_get_resolved_state_string(_flac));
	 */
				
	// Process metadata
	result = FLAC__stream_decoder_process_until_end_of_metadata(_flac);
	NSAssert1(YES == result, @"FLAC__stream_decoder_process_until_end_of_metadata failed: %s", FLAC__stream_decoder_get_resolved_state_string(_flac));
	
	// Setup input format descriptor
	_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
	_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
		
	_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
	_pcmFormat.mFramesPerPacket		= 1;
	_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
	
	// We only handle a subset of the legal bitsPerChannel for FLAC
	NSAssert(8 == _pcmFormat.mBitsPerChannel || 16 == _pcmFormat.mBitsPerChannel || 24 == _pcmFormat.mBitsPerChannel || 32 == _pcmFormat.mBitsPerChannel, @"Sample size not supported");
	
	return YES;
}

- (BOOL) cleanupDecoder:(NSError **)error
{
	FLAC__bool					result;
	
	result = FLAC__stream_decoder_finish(_flac);
	NSAssert1(YES == result, @"FLAC__stream_decoder_finish failed: %s", FLAC__stream_decoder_get_resolved_state_string(_flac));
	
	FLAC__stream_decoder_delete(_flac),		_flac = NULL;

	[super cleanupDecoder:error];
	
	return YES;
}

- (void) fillPCMBuffer
{
	FLAC__bool					result;
	
	unsigned					blockSize;
	unsigned					channels;
	unsigned					bitsPerSample;
	unsigned					blockByteSize;
	
	UInt32						bytesToWrite, bytesAvailableToWrite;
	void						*dummy;

	for(;;) {
		bytesToWrite				= RING_BUFFER_WRITE_CHUNK_SIZE;
		bytesAvailableToWrite		= [[self pcmBuffer] lengthAvailableToWriteReturningPointer:&dummy];
		
		// A problem I've run into is calculating how many times to call process_single, since
		// there is no good way to know in advance the bytes which will be required to hold a FLAC frame.
		// This is because FLAC uses a "push" model, while most everything else uses a "pull" model
		// I'll handle it here by checking to see if there is enough space for the block
		// that was just read.  For files with varying block sizes, channels or sample depths
		// this could blow up!
		// It's not feasible to use the maximum possible values, because
		// maxBlocksize(65535) * maxBitsPerSample(32) * maxChannels(8) = 16,776,960 (No 16 MB buffers here!)
		blockSize					= FLAC__stream_decoder_get_blocksize(_flac);
		channels					= FLAC__stream_decoder_get_channels(_flac);
		bitsPerSample				= FLAC__stream_decoder_get_bits_per_sample(_flac); 
		
		blockByteSize				= blockSize * channels * (bitsPerSample / 8);

		// Ensure sufficient space remains in the buffer
		if(bytesAvailableToWrite < bytesToWrite || bytesAvailableToWrite < blockByteSize) {
			break;
		}

		result	= FLAC__stream_decoder_process_single(_flac);		
		NSAssert1(YES == result, @"FLAC__stream_decoder_process_single failed: %s", FLAC__stream_decoder_get_resolved_state_string(_flac));

		// EOS?
		if(FLAC__STREAM_DECODER_END_OF_STREAM == FLAC__stream_decoder_get_state(_flac)) {
			[self setAtEndOfStream:YES];
			break;
		}
	}
}

@end

@implementation FLACStreamDecoder (Private)

- (void)	setSampleRate:(Float64)sampleRate				{ _pcmFormat.mSampleRate = sampleRate; }
- (void)	setBitsPerChannel:(UInt32)bitsPerChannel		{ _pcmFormat.mBitsPerChannel = bitsPerChannel; }
- (void)	setChannelsPerFrame:(UInt32)channelsPerFrame	{ _pcmFormat.mChannelsPerFrame = channelsPerFrame; }

@end
