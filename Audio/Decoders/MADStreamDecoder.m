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

#import "MADStreamDecoder.h"
#import "AudioStream.h"

#define INPUT_BUFFER_SIZE	(5*8192)

static inline int32_t 
audio_linear_round(unsigned int bits, 
				   mad_fixed_t sample)
{
	enum {
		MIN = -MAD_F_ONE,
		MAX =  MAD_F_ONE - 1
	};

	/* round */
	sample += (1L << (MAD_F_FRACBITS - bits));
	
	/* clip */
	if(MAX < sample) {
		sample = MAX;
	}
	else if(MIN > sample) {
		sample = MIN;
	}
	
	/* quantize and scale */
	return sample >> (MAD_F_FRACBITS + 1 - bits);
}

@implementation MADStreamDecoder

- (NSString *) sourceFormatDescription
{
	return [NSString stringWithFormat:@"%@, %u channels, %u Hz", NSLocalizedStringFromTable(@"Ogg (Vorbis)", @"General", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate];
}

- (BOOL) supportsSeeking
{
	return YES;
}

- (SInt64) performSeekToFrame:(SInt64)frame
{
//	int		result		= ov_pcm_seek(&_vf, frame); 
//	return (0 == result ? frame : -1);
	return -1;
}

- (BOOL) setupDecoder:(NSError **)error
{
	_inputBuffer = (unsigned char *)calloc(INPUT_BUFFER_SIZE, sizeof(unsigned char));
	NSAssert(NULL != _inputBuffer, @"Unable to allocate memory");
	
	_fd = open([[[[self stream] valueForKey:StreamURLKey] path] fileSystemRepresentation], O_RDONLY);
	NSAssert1(-1 != _fd, @"Unable to open the input file (%s).", strerror(errno));
/*	if(-1 == _fd) {
	
		if(nil != error) {
			
		}
		
		return NO;
	}*/
	
	mad_stream_init(&_mad_stream);
	mad_frame_init(&_mad_frame);
	mad_synth_init(&_mad_synth);
	mad_timer_reset(&_mad_timer);
	
	SInt64 totalFrames = [[[self stream] valueForKey:PropertiesTotalFramesKey] longLongValue];
	NSLog(@"totalFrames = %i",totalFrames);
	if(0 != totalFrames) {
		[self setTotalFrames:totalFrames];
	}
	else {
		
	}

	// Setup input format descriptor
	_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
	_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
	
	_pcmFormat.mSampleRate			= [[[self stream] valueForKey:PropertiesSampleRateKey] floatValue];
	_pcmFormat.mChannelsPerFrame	= [[[self stream] valueForKey:PropertiesChannelsPerFrameKey] unsignedIntValue];
	_pcmFormat.mBitsPerChannel		= 24;
	
	_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
	_pcmFormat.mFramesPerPacket		= 1;
	_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
		
	return YES;
}

- (BOOL) cleanupDecoder:(NSError **)error
{
	mad_synth_finish(&_mad_synth);
	mad_frame_finish(&_mad_frame);
	mad_stream_finish(&_mad_stream);
	
	close(_fd), _fd = -1;
	
	free(_inputBuffer);
	
	[super cleanupDecoder:error];
	
	return YES;
}

- (void) fillPCMBuffer
{
	UInt32			bytesToWrite, bytesAvailableToWrite;
	UInt32			bytesToRead, bytesWritten, bytesRemaining;
	ssize_t			bytesRead;
	void			*writePointer;
	unsigned char	*guardPointer, *readStartPointer;
	unsigned		frameByteSize, i;
	int32_t			audioSample;
	int8_t			*alias8;
	
	for(;;) {
		bytesToWrite			= RING_BUFFER_WRITE_CHUNK_SIZE;
		bytesAvailableToWrite	= [[self pcmBuffer] lengthAvailableToWriteReturningPointer:&writePointer];
		bytesWritten			= 0;
		
		// Estimation for worst-case (MAD only supports 2 channel MP3s)
		// 1152 samples per channel, 2 channels, 24 bits per sample
		frameByteSize			= 1152 * 2 * 3;
		
		// Ensure sufficient space remains in the buffer
		if(bytesToWrite > bytesAvailableToWrite || bytesAvailableToWrite < frameByteSize) {
			break;
		}
		
		if(NULL == _mad_stream.buffer || MAD_ERROR_BUFLEN == _mad_stream.error) {

			if(NULL != _mad_stream.next_frame) {
				bytesRemaining		= _mad_stream.bufend - _mad_stream.next_frame;

				memmove(_inputBuffer, _mad_stream.next_frame, bytesRemaining);
				
				readStartPointer	= _inputBuffer + bytesRemaining;
				bytesToRead			= INPUT_BUFFER_SIZE - bytesRemaining;
			}
			else {
				bytesToRead			= INPUT_BUFFER_SIZE,
				readStartPointer	= _inputBuffer,
				bytesRemaining		= 0;
			}
			
			bytesRead = read(_fd, readStartPointer, bytesToRead);
			
			if(-1 == bytesRead) {
				NSLog(@"Read error: %s.", strerror(errno));
				break;
			}
			else if(0 == bytesRead) {
				guardPointer	= readStartPointer + bytesRead;
				
				memset(guardPointer, 0, MAD_BUFFER_GUARD);
				
				bytesRead		+= MAD_BUFFER_GUARD;
			}

			mad_stream_buffer(&_mad_stream, _inputBuffer, bytesRead + bytesRemaining);
			_mad_stream.error = 0;
		}
		
		if(mad_frame_decode(&_mad_frame, &_mad_stream)) {
			if(MAD_RECOVERABLE(_mad_stream.error)) {
				if(MAD_ERROR_LOSTSYNC != _mad_stream.error || _mad_stream.this_frame != guardPointer) {
					NSLog(@"Recoverable frame level error (%s)", mad_stream_errorstr(&_mad_stream));
				}
				continue;
			}
			else if(MAD_ERROR_BUFLEN == _mad_stream.error) {
				continue;
			}
			else {
				NSLog(@"Unrecoverable frame level error (%s)", mad_stream_errorstr(&_mad_stream));
				break;
			}
		}
		
		[self setCurrentFrame:[self currentFrame] + 1];
		mad_timer_add(&_mad_timer, _mad_frame.header.duration);
		
		mad_synth_frame(&_mad_synth, &_mad_frame);
		
		alias8 = writePointer;
		for(i = 0; i < _mad_synth.pcm.length; ++i) {						
			audioSample = audio_linear_round(24, _mad_synth.pcm.samples[0][i]);
			
			*alias8++	= (int8_t)(audioSample >> 16);
			*alias8++	= (int8_t)(audioSample >> 8);
			*alias8++	= (int8_t)audioSample;
			
			bytesWritten += 3;

			if(2 == MAD_NCHANNELS(&_mad_frame.header)) {
				audioSample = audio_linear_round(24, _mad_synth.pcm.samples[1][i]);

				*alias8++	= (int8_t)(audioSample >> 16);
				*alias8++	= (int8_t)(audioSample >> 8);
				*alias8++	= (int8_t)audioSample;

				bytesWritten += 3;
			}
		}
		
		if(0 == bytesRead || bytesWritten >= bytesAvailableToWrite) {
			break;
		}
		
		if(0 < bytesWritten) {
			[[self pcmBuffer] didWriteLength:bytesWritten];				
		}
		
		if(0 == bytesRead) {
			[self setAtEndOfStream:YES];
			break;
		}
	}
}

@end
