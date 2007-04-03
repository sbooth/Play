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

#include <sys/types.h>
#include <sys/stat.h>

#define INPUT_BUFFER_SIZE	(5*8192)

// From vbrheadersdk:
// ========================================
// A Xing header may be present in the ancillary
// data field of the first frame of an mp3 bitstream
// The Xing header (optionally) contains
//      frames      total number of audio frames in the bitstream
//      bytes       total number of bytes in the bitstream
//      toc         table of contents

// toc (table of contents) gives seek points
// for random access
// the ith entry determines the seek point for
// i-percent duration
// seek point in bytes = (toc[i]/256.0) * total_bitstream_bytes
// e.g. half duration seek point = (toc[50]/256.0) * total_bitstream_bytes

#define FRAMES_FLAG     0x0001
#define BYTES_FLAG      0x0002
#define TOC_FLAG        0x0004
#define VBR_SCALE_FLAG  0x0008

static int32_t 
audio_linear_round(unsigned int bits, 
				   mad_fixed_t sample)
{
	/* round */
	sample += (1L << (MAD_F_FRACBITS - bits));
	
	/* clip */
	if(MAD_F_MAX < sample) {
		sample = MAD_F_MAX;
	}
	else if(MAD_F_MIN > sample) {
		sample = MAD_F_MIN;
	}
	
	/* quantize and scale */
	return sample >> (MAD_F_FRACBITS + 1 - bits);
}

@interface MADStreamDecoder (Private)
- (void) scanFile;
@end

@implementation MADStreamDecoder

- (NSString *) sourceFormatDescription
{
	return [NSString stringWithFormat:@"%@, %u channels, %u Hz", NSLocalizedStringFromTable(@"MPEG Layer", @"General", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate];
}

- (BOOL) supportsSeeking
{
	return NO;
}

- (SInt64) performSeekToFrame:(SInt64)frame
{
	SInt64		targetFrame		= frame - 1;
	
	if(frame > _framesDecoded) {
	}
	else {
	}
//	int		result		= ov_pcm_seek(&_vf, frame); 
//	return (0 == result ? frame : -1);
	return -1;
}

- (BOOL) setupDecoder:(NSError **)error
{
	_framesDecoded = 0;
	
	_inputBuffer = (unsigned char *)calloc(INPUT_BUFFER_SIZE + MAD_BUFFER_GUARD, sizeof(unsigned char));
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

	// Scan file to determine total frames, etc
	[self scanFile];

	// Setup input format descriptor
	_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
	_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
	
//	_pcmFormat.mSampleRate			= ;
//	_pcmFormat.mChannelsPerFrame	= ;
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
	unsigned char	*readStartPointer;
	unsigned		frameByteSize, i;
	int32_t			audioSample;
	int8_t			*alias8;
	int				result;
	
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
			
			// Read raw bytes from the MP3 file
			bytesRead = read(_fd, readStartPointer, bytesToRead);
			
			if(-1 == bytesRead) {
				NSLog(@"Read error: %s.", strerror(errno));
				break;
			}

			mad_stream_buffer(&_mad_stream, _inputBuffer, bytesRead + bytesRemaining);
			_mad_stream.error = 0;
		}

		result = mad_frame_decode(&_mad_frame, &_mad_stream);

		if(-1 == result) {

			if(MAD_RECOVERABLE(_mad_stream.error)) {
				NSLog(@"Recoverable frame level error (%s)", mad_stream_errorstr(&_mad_stream));
				continue;
			}
			// EOS
			else if(MAD_ERROR_BUFLEN == _mad_stream.error && 0 == bytesRead) {
				[self setAtEndOfStream:YES];
				break;
			}
			else if(MAD_ERROR_BUFLEN == _mad_stream.error) {
				continue;
			}
			else {
				NSLog(@"Unrecoverable frame level error (%s)", mad_stream_errorstr(&_mad_stream));
				break;
			}
		}
		
		++_framesDecoded;
		mad_timer_add(&_mad_timer, _mad_frame.header.duration);
		
		mad_synth_frame(&_mad_synth, &_mad_frame);
		
		// Output samples in 24-bit signed integer big endian PCM
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
	}
}

@end

@implementation MADStreamDecoder (Private)

- (void) scanFile
{
	SInt64				framesDecoded = 0;
	UInt32				bytesToRead, bytesRemaining;
	ssize_t				bytesRead;
	unsigned char		*readStartPointer;
	
	struct mad_stream	stream;
	struct mad_frame	frame;
	mad_timer_t			timer;
	
	int					result;
	
//	struct stat			stat;
	
	// Set up	
	unsigned char *inputBuffer = (unsigned char *)calloc(INPUT_BUFFER_SIZE + MAD_BUFFER_GUARD, sizeof(unsigned char));
	NSAssert(NULL != inputBuffer, @"Unable to allocate memory");
	
	int fd = open([[[[self stream] valueForKey:StreamURLKey] path] fileSystemRepresentation], O_RDONLY);
	NSAssert1(-1 != fd, @"Unable to open the input file (%s).", strerror(errno));
	
//	result = fstat(fd, &stat);
//	NSAssert1(-1 != fd, @"Unable to stat the input file (%s).", strerror(errno));
	
	mad_stream_init(&stream);
	mad_frame_init(&frame);
	mad_timer_reset(&timer);
	
	for(;;) {
		if(NULL == stream.buffer || MAD_ERROR_BUFLEN == stream.error) {
			
			if(NULL != stream.next_frame) {
				bytesRemaining		= stream.bufend - stream.next_frame;
				
				memmove(inputBuffer, stream.next_frame, bytesRemaining);
				
				readStartPointer	= inputBuffer + bytesRemaining;
				bytesToRead			= INPUT_BUFFER_SIZE - bytesRemaining;
			}
			else {
				bytesToRead			= INPUT_BUFFER_SIZE,
				readStartPointer	= inputBuffer,
				bytesRemaining		= 0;
			}
			
			// Read raw bytes from the MP3 file
			bytesRead = read(fd, readStartPointer, bytesToRead);
			
			if(-1 == bytesRead) {
				NSLog(@"Read error: %s.", strerror(errno));
				break;
			}
			
			mad_stream_buffer(&stream, inputBuffer, bytesRead + bytesRemaining);
			stream.error = 0;
		}
		
		result = mad_frame_decode(&frame, &stream);
		
		if(-1 == result) {
			
			if(MAD_RECOVERABLE(stream.error)) {
				NSLog(@"Recoverable frame level error (%s)", mad_stream_errorstr(&stream));
				continue;
			}
			else if(MAD_ERROR_BUFLEN == stream.error && 0 == bytesRead) {
				// EOS
				break;
			}
			else if(MAD_ERROR_BUFLEN == stream.error) {
				continue;
			}
			else {
				NSLog(@"Unrecoverable frame level error (%s)", mad_stream_errorstr(&stream));
				break;
			}
		}
		
		// Look for a Xing header in the first frame that was successfully decoded
		// Reference http://www.codeproject.com/audio/MPEGAudioInfo.asp
		if(0 == framesDecoded) {
						
			_pcmFormat.mSampleRate			= frame.header.samplerate;
			_pcmFormat.mChannelsPerFrame	= MAD_NCHANNELS(&frame.header);

			uint32_t magic = mad_bit_read(&stream.anc_ptr, 32);
			
			if('Xing' == magic) {
//			if((('X' << 24) | ('i' << 16) | ('n' << 8) | ('g')) == magic) {
				
				unsigned	i;
				uint32_t	flags = 0, frames = 0, bytes = 0, vbr_scale = 0;
				float		bitrate = 0;
				uint8_t		toc [100];
				
				memset(toc, 0, 100);
				
				flags = mad_bit_read(&stream.anc_ptr, 32);
				
				// 4 byte value containing total frames
				if(FRAMES_FLAG & flags) {
					frames = mad_bit_read(&stream.anc_ptr, 32);
					// An MP3 frame contains 1152 samples
					[self setTotalFrames:frames * 1152];
				}
				
				// 4 byte value containing total bytes
				if(BYTES_FLAG & flags) {
					bytes = mad_bit_read(&stream.anc_ptr, 32);
				}
				
				// 100 bytes containing TOC information
				if(TOC_FLAG & flags) {
					for(i = 0; i < 100; ++i) {
						toc[i] = mad_bit_read(&stream.anc_ptr, 8);
					}
				}
				
				// 4 byte value indicating encoded vbr scale
				if(VBR_SCALE_FLAG & flags) {
					vbr_scale = mad_bit_read(&stream.anc_ptr, 32);
				}
								
				mad_timer_add(&timer, frame.header.duration);
				mad_timer_multiply(&timer, frames);
				
				framesDecoded	= frames;
				bitrate			= 8.0 * (bytes / mad_timer_count(timer, MAD_UNITS_SECONDS));
				
				break;
				}			
			}
		
		++framesDecoded;
		mad_timer_add(&timer, frame.header.duration);
		}

	// Clean up
	mad_frame_finish(&frame);
	mad_stream_finish(&stream);
	
	free(inputBuffer);
	close(fd);
}

@end