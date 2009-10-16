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

#import "FLACDecoder.h"
#import "AudioStream.h"
#include <FLAC/metadata.h>

@interface FLACDecoder (Private)
- (AudioBufferList *) bufferList;
- (void) setStreamInfo:(FLAC__StreamMetadata_StreamInfo)streamInfo;
@end

static FLAC__StreamDecoderWriteStatus 
writeCallback(const FLAC__StreamDecoder *decoder, const FLAC__Frame *frame, const FLAC__int32 * const buffer[], void *client_data)
{
	FLACDecoder			*source			= (FLACDecoder *)client_data;
	AudioBufferList		*bufferList		= [source bufferList];
	
	// Avoid segfaults
	if(NULL == bufferList || bufferList->mNumberBuffers != frame->header.channels)
		return FLAC__STREAM_DECODER_WRITE_STATUS_ABORT;
	
	// Normalize audio
	float scaleFactor = (1L << ((((frame->header.bits_per_sample + 7) / 8) * 8) - 1));

	unsigned channel, sample;
	for(channel = 0; channel < frame->header.channels; ++channel) {
		float *floatBuffer = bufferList->mBuffers[channel].mData;
		
		for(sample = 0; sample < frame->header.blocksize; ++sample)
			*floatBuffer++ = buffer[channel][sample] / scaleFactor;
		
		bufferList->mBuffers[channel].mNumberChannels	= 1;
		bufferList->mBuffers[channel].mDataByteSize		= frame->header.blocksize * sizeof(float);
	}
	
	return FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE;	
}

static void
metadataCallback(const FLAC__StreamDecoder *decoder, const FLAC__StreamMetadata *metadata, void *client_data)
{
	FLACDecoder		*source		= (FLACDecoder *)client_data;
	
	switch(metadata->type) {
		case FLAC__METADATA_TYPE_STREAMINFO:	[source setStreamInfo:metadata->data.stream_info];			break;
		default:																							break;
	}
}

static void
errorCallback(const FLAC__StreamDecoder *decoder, FLAC__StreamDecoderErrorStatus status, void *client_data)
{
	//	FLACDecoder		*source		= (FLACDecoder *)client_data;	
	//	@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__StreamDecoderErrorStatusString[status] encoding:NSASCIIStringEncoding] userInfo:nil];
}

@implementation FLACDecoder

- (id) initWithURL:(NSURL *)url error:(NSError **)error
{
	NSParameterAssert(nil != url);
	
	if((self = [super initWithURL:url error:error])) {
		// Create FLAC decoder
		_flac = FLAC__stream_decoder_new();
		NSAssert(NULL != _flac, NSLocalizedStringFromTable(@"Unable to create the FLAC decoder.", @"Errors", @""));
		
		// Initialize decoder
		FLAC__StreamDecoderInitStatus status = FLAC__stream_decoder_init_file(_flac, 
																			  [[[self URL] path] fileSystemRepresentation],
																			  writeCallback, 
																			  metadataCallback, 
																			  errorCallback,
																			  self);
		NSAssert1(FLAC__STREAM_DECODER_INIT_STATUS_OK == status, @"FLAC__stream_decoder_init_file failed: %s", FLAC__stream_decoder_get_resolved_state_string(_flac));
		
		// Process metadata
		FLAC__bool result = FLAC__stream_decoder_process_until_end_of_metadata(_flac);
		NSAssert1(YES == result, @"FLAC__stream_decoder_process_until_end_of_metadata failed: %s", FLAC__stream_decoder_get_resolved_state_string(_flac));
		
		_format.mSampleRate			= _streamInfo.sample_rate;
		_format.mChannelsPerFrame	= _streamInfo.channels;
		
		// The source's PCM format
		_sourceFormat.mFormatID				= kAudioFormatLinearPCM;
		_sourceFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian;

		_sourceFormat.mSampleRate			= _streamInfo.sample_rate;
		_sourceFormat.mChannelsPerFrame		= _streamInfo.channels;
		_sourceFormat.mBitsPerChannel		= _streamInfo.bits_per_sample;

		_sourceFormat.mBytesPerPacket		= ((_sourceFormat.mBitsPerChannel + 7) / 8) * _sourceFormat.mChannelsPerFrame;
		_sourceFormat.mFramesPerPacket		= 1;
		_sourceFormat.mBytesPerFrame		= _sourceFormat.mBytesPerPacket * _sourceFormat.mFramesPerPacket;		
		
		switch(_streamInfo.channels) {
			case 1:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;				break;
			case 2:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;			break;
			case 3:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_MPEG_3_0_A;		break;
			case 4:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Quadraphonic;		break;
			case 5:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_MPEG_5_0_A;		break;
			case 6:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_MPEG_5_1_A;		break;
		}
		
		// Allocate the buffer list
		_bufferList = calloc(sizeof(AudioBufferList) + (sizeof(AudioBuffer) * (_format.mChannelsPerFrame - 1)), 1);
		NSAssert(NULL != _bufferList, @"Unable to allocate memory");
		
		_bufferList->mNumberBuffers = _format.mChannelsPerFrame;
		
		unsigned i;
		for(i = 0; i < _bufferList->mNumberBuffers; ++i) {
			_bufferList->mBuffers[i].mData = calloc(_streamInfo.max_blocksize, sizeof(float));
			NSAssert(NULL != _bufferList->mBuffers[i].mData, @"Unable to allocate memory");

			_bufferList->mBuffers[i].mNumberChannels = 1;
		}
	}
	return self;
}

- (void) dealloc
{	
	FLAC__bool result = FLAC__stream_decoder_finish(_flac);
	NSAssert1(YES == result, @"FLAC__stream_decoder_finish failed: %s", FLAC__stream_decoder_get_resolved_state_string(_flac));
	
	FLAC__stream_decoder_delete(_flac), _flac = NULL;
	
	if(_bufferList) {
		unsigned i;
		for(i = 0; i < _bufferList->mNumberBuffers; ++i)
			free(_bufferList->mBuffers[i].mData), _bufferList->mBuffers[i].mData = NULL;	
		free(_bufferList), _bufferList = NULL;
	}
	
	[super dealloc];	
}

- (SInt64)			totalFrames						{ return _streamInfo.total_samples; }
- (SInt64)			currentFrame					{ return _currentFrame; }

- (BOOL)			supportsSeeking					{ return YES; }

- (SInt64) seekToFrame:(SInt64)frame
{
	NSParameterAssert(0 <= frame && frame < [self totalFrames]);
	
	FLAC__bool result = FLAC__stream_decoder_seek_absolute(_flac, frame);	
	
	// Attempt to re-sync the stream if necessary
	if(FLAC__STREAM_DECODER_SEEK_ERROR == FLAC__stream_decoder_get_state(_flac))
		result = FLAC__stream_decoder_flush(_flac);
	
	if(result) {
		_currentFrame = frame;
		unsigned i;
		for(i = 0; i < _bufferList->mNumberBuffers; ++i)
			_bufferList->mBuffers[i].mDataByteSize = 0;	
	}
	
	return (result ? frame : -1);
}

- (UInt32) readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount
{
	NSParameterAssert(NULL != bufferList);
	NSParameterAssert(bufferList->mNumberBuffers == _format.mChannelsPerFrame);
	NSParameterAssert(0 < frameCount);
	
	UInt32 framesRead = 0;
	
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
		
		// EOS?
		if(FLAC__STREAM_DECODER_END_OF_STREAM == FLAC__stream_decoder_get_state(_flac))
			break;
		
		// Grab the next frame
		FLAC__bool result = FLAC__stream_decoder_process_single(_flac);
		NSAssert1(YES == result, @"FLAC__stream_decoder_process_single failed: %s", FLAC__stream_decoder_get_resolved_state_string(_flac));		
	}
	
	_currentFrame += framesRead;
	return framesRead;
}

- (NSString *) sourceFormatDescription
{
	return [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@, %u channels, %u Hz", @"Formats", @""), NSLocalizedStringFromTable(@"FLAC", @"Formats", @""), [self format].mChannelsPerFrame, (unsigned)[self format].mSampleRate];
}

@end

@implementation FLACDecoder (Private)

- (AudioBufferList *) bufferList
{
	return _bufferList;
}

- (void) setStreamInfo:(FLAC__StreamMetadata_StreamInfo)streamInfo
{
	memcpy(&_streamInfo, &streamInfo, sizeof(streamInfo));
}

@end
