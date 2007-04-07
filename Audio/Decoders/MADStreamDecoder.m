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

#define INPUT_BUFFER_SIZE	(5 * 8192)
#define LAME_HEADER_SIZE	((8 * 5) + 4 + 4 + 8 + 32 + 16 + 16 + 4 + 4 + 8 + 12 + 12 + 8 + 8 + 2 + 3 + 11 + 32 + 32 + 32)


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

// Clipping and rounding code from madplay(audio.c):
/*
 * madplay - MPEG audio decoder and player
 * Copyright (C) 2000-2004 Robert Leslie
 */
static int32_t 
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
// End madplay code

@interface MADStreamDecoder (Private)
- (BOOL) scanFile;
@end

@implementation MADStreamDecoder

- (NSString *) sourceFormatDescription
{
	return [NSString stringWithFormat:@"%@, %u channels, %u Hz", NSLocalizedStringFromTable(@"MPEG Audio", @"Formats", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate];
}

- (BOOL) supportsSeeking
{
	return NO;
}

- (SInt64) performSeekToFrame:(SInt64)frame
{
	SInt64		targetFrame		= frame - 1;
	
	if(frame > _mpegFramesDecoded) {
	}
	else {
	}
//	int		result		= ov_pcm_seek(&_vf, frame); 
//	return (0 == result ? frame : -1);
	return -1;
}

- (BOOL) setupDecoder:(NSError **)error
{
	_mpegFramesDecoded		= 0;
	_totalMPEGFrames		= 0;

	_encoderDelay			= 0;
	_encoderPadding			= 0;
	
	_samplesDecoded			= 0;
	_samplesPerMPEGFrame	= 0;
	
	_foundXingHeader		= NO;
	_foundLAMEHeader		= NO;
	
	_inputBuffer = (unsigned char *)calloc(INPUT_BUFFER_SIZE + MAD_BUFFER_GUARD, sizeof(unsigned char));
	if(NULL == _inputBuffer) {
		if(nil != error) {
			
		}
		
		return NO;
	}
	
	_fd = open([[[[self stream] valueForKey:StreamURLKey] path] fileSystemRepresentation], O_RDONLY);
	if(-1 == _fd) {
		if(nil != error) {
			
		}
	
		free(_inputBuffer), _inputBuffer = NULL;
		return NO;
	}
	
	mad_stream_init(&_mad_stream);
	mad_frame_init(&_mad_frame);
	mad_synth_init(&_mad_synth);
	mad_timer_reset(&_mad_timer);

	// Scan file to determine total frames, etc
	BOOL result = [self scanFile];
	if(NO == result) {
		free(_inputBuffer), _inputBuffer = NULL;
		close(_fd), _fd = -1;
		return NO;
	}

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
	
	free(_inputBuffer), _inputBuffer = NULL;
	close(_fd), _fd = -1;
	
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
	unsigned		frameByteSize, i, sampleCount;
	int32_t			audioSample;
	int8_t			*alias8;
	int				result;
	BOOL			readEOF;
	

	bytesToWrite			= RING_BUFFER_WRITE_CHUNK_SIZE;
	bytesAvailableToWrite	= [[self pcmBuffer] lengthAvailableToWriteReturningPointer:&writePointer];
	bytesWritten			= 0;
	alias8					= writePointer;
	readEOF					= NO;

	// Calculate bytes requiredfor decompressing one MPEG frame to 24-bit PCM 
	frameByteSize			= _samplesPerMPEGFrame * 2 * 3;
	
	// Ensure sufficient space remains in the buffer
	if(bytesToWrite > bytesAvailableToWrite) {
		return;
	}
	
	for(;;) {

		// Feed the input buffer if necessary
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
			
			// MAD_BUFFER_GUARD zeroes are required to decode the last frame of the file
			if(0 == bytesRead) {
				memset(readStartPointer + bytesRead, 0, MAD_BUFFER_GUARD);
				bytesRead	+= MAD_BUFFER_GUARD;
				readEOF		= YES;
			}

			mad_stream_buffer(&_mad_stream, _inputBuffer, bytesRead + bytesRemaining);
			_mad_stream.error = MAD_ERROR_NONE;
		}

		// Ensure space exists for this frame before decoding
		if(bytesAvailableToWrite < frameByteSize) {
			break;
		}
		
		// Decode the MPEG frame
		result = mad_frame_decode(&_mad_frame, &_mad_stream);
		if(-1 == result) {

			if(MAD_RECOVERABLE(_mad_stream.error)) {
				NSLog(@"Recoverable frame level error (%s)", mad_stream_errorstr(&_mad_stream));
				continue;
			}
			// EOS for non-Xing streams occurs when EOF is reached and no further frames can be decoded
			else if(MAD_ERROR_BUFLEN == _mad_stream.error && readEOF) {
				[self setAtEndOfStream:YES];
				break;
			}
			else if(MAD_ERROR_BUFLEN == _mad_stream.error) {
				continue;
			}
			else {
				NSLog(@"Unrecoverable frame level error (%s)", mad_stream_errorstr(&_mad_stream));
				return;
			}
		}
		
		// Housekeeping
		++_mpegFramesDecoded;
		mad_timer_add(&_mad_timer, _mad_frame.header.duration);
		
		// Synthesize the frame into PCM
		mad_synth_frame(&_mad_synth, &_mad_frame);

		i = 0;
		// Skip the Xing header (it contains empty audio)
		if(_foundXingHeader && 1 == _mpegFramesDecoded) {
			continue;
		}
		// Adjust the first real audio frame for gapless playback
		else if(_foundLAMEHeader && 2 == _mpegFramesDecoded) {
			i = _encoderDelay;
		}

		// If a LAME header was found, the total number of audio frames (AKA samples) 
		// is known.  Ensure only that many are output
		sampleCount = _mad_synth.pcm.length;
		if(_foundLAMEHeader && [self totalFrames] < _samplesDecoded + sampleCount) {
			sampleCount = [self totalFrames] - _samplesDecoded;
		}
				
		// Output samples in 24-bit signed integer big endian PCM
		for(/*i = 0*/; i < sampleCount; ++i) {						
			audioSample = audio_linear_round(24, _mad_synth.pcm.samples[0][i]);
			
			*alias8++	= (int8_t)(audioSample >> 16);
			*alias8++	= (int8_t)(audioSample >> 8);
			*alias8++	= (int8_t)audioSample;
			
			bytesWritten			+= 3;
			bytesAvailableToWrite	-= 3;
			
			if(2 == MAD_NCHANNELS(&_mad_frame.header)) {
				audioSample = audio_linear_round(24, _mad_synth.pcm.samples[1][i]);

				*alias8++	= (int8_t)(audioSample >> 16);
				*alias8++	= (int8_t)(audioSample >> 8);
				*alias8++	= (int8_t)audioSample;

				bytesWritten			+= 3;
				bytesAvailableToWrite	-= 3;
			}
			
			++_samplesDecoded;
		}
		
		// If the file contains a Xing header but not LAME gapless information,
		// decode the number of MPEG frames specified by the Xing header
		if(_foundXingHeader && NO == _foundLAMEHeader && _mpegFramesDecoded == _totalMPEGFrames) {
			[self setAtEndOfStream:YES];
			break;
		}

		// The LAME header indicates how many samples are in the file
		if(_foundLAMEHeader && [self totalFrames] == _samplesDecoded) {
			[self setAtEndOfStream:YES];
			break;
		}
	}

	if(0 < bytesWritten) {
		[[self pcmBuffer] didWriteLength:bytesWritten];				
	}		
}

@end

@implementation MADStreamDecoder (Private)

- (BOOL) scanFile
{
	uint32_t			framesDecoded = 0;
	UInt32				bytesToRead, bytesRemaining;
	ssize_t				bytesRead;
	unsigned char		*readStartPointer;
	BOOL				readEOF;
	
	struct mad_stream	stream;
	struct mad_frame	frame;
	mad_timer_t			timer;
	
	int					result;
	struct stat			stat;
	
	// Set up	
	unsigned char *inputBuffer = (unsigned char *)calloc(INPUT_BUFFER_SIZE + MAD_BUFFER_GUARD, sizeof(unsigned char));
	if(NULL == inputBuffer) {
		return NO;
	}
	
	int fd = open([[[[self stream] valueForKey:StreamURLKey] path] fileSystemRepresentation], O_RDONLY);
	if(-1 == fd) {
		free(inputBuffer);
		return NO;
	}
	
	mad_stream_init(&stream);
	mad_frame_init(&frame);
	mad_timer_reset(&timer);
	
	readEOF = NO;
	
	result = fstat(fd, &stat);
	if(-1 == result) {
		free(inputBuffer);
		close(fd);
		return NO;
	}
		
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
			
			// MAD_BUFFER_GUARD zeroes are required to decode the last frame of the file
			if(0 == bytesRead) {
				memset(readStartPointer + bytesRead, 0, MAD_BUFFER_GUARD);
				bytesRead	+= MAD_BUFFER_GUARD;
				readEOF		= YES;
			}

			mad_stream_buffer(&stream, inputBuffer, bytesRead + bytesRemaining);
			stream.error = MAD_ERROR_NONE;
		}
		
		result = mad_frame_decode(&frame, &stream);
		
		if(-1 == result) {
			
			if(MAD_RECOVERABLE(stream.error)) {
				NSLog(@"Recoverable frame level error (%s)", mad_stream_errorstr(&stream));
				continue;
			}
			// EOS for non-Xing streams occurs when EOF is reached and no further frames can be decoded
			else if(MAD_ERROR_BUFLEN == stream.error && readEOF) {
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
		
		++framesDecoded;
		mad_timer_add(&timer, frame.header.duration);

		// Look for a Xing header in the first frame that was successfully decoded
		// Reference http://www.codeproject.com/audio/MPEGAudioInfo.asp
		if(1 == framesDecoded) {
			
			_pcmFormat.mSampleRate			= frame.header.samplerate;
			_pcmFormat.mChannelsPerFrame	= MAD_NCHANNELS(&frame.header);

			if(MAD_FLAG_LSF_EXT & frame.header.flags || MAD_FLAG_MPEG_2_5_EXT & frame.header.flags) {
				switch(frame.header.layer) {
					case MAD_LAYER_I:		_samplesPerMPEGFrame = 384;			break;
					case MAD_LAYER_II:		_samplesPerMPEGFrame = 1152;		break;
					case MAD_LAYER_III:		_samplesPerMPEGFrame = 576;			break;
				}
			}
			else {
				switch(frame.header.layer) {
					case MAD_LAYER_I:		_samplesPerMPEGFrame = 384;			break;
					case MAD_LAYER_II:		_samplesPerMPEGFrame = 1152;		break;
					case MAD_LAYER_III:		_samplesPerMPEGFrame = 1152;		break;
				}
			}
			
			unsigned ancillaryBitsRemaining = stream.anc_bitlen;
			
			if(32 > ancillaryBitsRemaining) { continue; }

			uint32_t magic = mad_bit_read(&stream.anc_ptr, 32);
			ancillaryBitsRemaining -= 32;
			
			if('Xing' == magic) {
//			if((('X' << 24) | ('i' << 16) | ('n' << 8) | ('g')) == magic) {
				
				unsigned	i;
				uint32_t	flags = 0, frames = 0, bytes = 0, vbrScale = 0;
				uint8_t		toc [100];
				
				memset(toc, 0, 100);
				
				if(32 > ancillaryBitsRemaining) { continue; }
				
				flags = mad_bit_read(&stream.anc_ptr, 32);
				ancillaryBitsRemaining -= 32;

				// 4 byte value containing total frames
				if(FRAMES_FLAG & flags) {
					if(32 > ancillaryBitsRemaining) { continue; }

					frames = mad_bit_read(&stream.anc_ptr, 32);
					ancillaryBitsRemaining -= 32;

					_totalMPEGFrames = frames;

					// Determine number of samples, discounting encoder delay and padding
					// Our concept of a frame is the same as CoreAudio's- one sample across all channels
					[self setTotalFrames:frames * _samplesPerMPEGFrame];
				}
				
				// 4 byte value containing total bytes
				if(BYTES_FLAG & flags) {
					if(32 > ancillaryBitsRemaining) { continue; }
					
					bytes = mad_bit_read(&stream.anc_ptr, 32);
					ancillaryBitsRemaining -= 32;
				}
				
				// 100 bytes containing TOC information
				if(TOC_FLAG & flags) {
					if(8 * 100 > ancillaryBitsRemaining) { continue; }
					
					for(i = 0; i < 100; ++i) {
						toc[i] = mad_bit_read(&stream.anc_ptr, 8);
					}
					
					ancillaryBitsRemaining -= (8* 100);
				}
				
				// 4 byte value indicating encoded vbr scale
				if(VBR_SCALE_FLAG & flags) {
					if(32 > ancillaryBitsRemaining) { continue; }
					
					vbrScale = mad_bit_read(&stream.anc_ptr, 32);
					ancillaryBitsRemaining -= 32;
				}
								
				mad_timer_add(&timer, frame.header.duration);
				mad_timer_multiply(&timer, frames);
				
				framesDecoded	= frames;
				
				_foundXingHeader = YES;

				// Loook for the LAME header next
				// http://gabriel.mp3-tech.org/mp3infotag.html				
				if(32 > ancillaryBitsRemaining) { continue; }
				magic = mad_bit_read(&stream.anc_ptr, 32);
				
				ancillaryBitsRemaining -= 32;

				if('LAME' == magic) {
					
					if(LAME_HEADER_SIZE > ancillaryBitsRemaining) { continue; }
					
					/*unsigned char versionString [5 + 1];
					memset(versionString, 0, 6);*/
					
					for(i = 0; i < 5; ++i) {
						/*versionString[i] =*/ mad_bit_read(&stream.anc_ptr, 8);
					}
					
					/*uint8_t infoTagRevision =*/ mad_bit_read(&stream.anc_ptr, 4);
					/*uint8_t vbrMethod =*/ mad_bit_read(&stream.anc_ptr, 4);
					
					/*uint8_t lowpassFilterValue =*/ mad_bit_read(&stream.anc_ptr, 8);
					
					/*float peakSignalAmplitude =*/ mad_bit_read(&stream.anc_ptr, 32);
					/*uint16_t radioReplayGain =*/ mad_bit_read(&stream.anc_ptr, 16);
					/*uint16_t audiophileReplayGain =*/ mad_bit_read(&stream.anc_ptr, 16);
					
					/*uint8_t encodingFlags =*/ mad_bit_read(&stream.anc_ptr, 4);
					/*uint8_t athType =*/ mad_bit_read(&stream.anc_ptr, 4);
					
					/*uint8_t lameBitrate =*/ mad_bit_read(&stream.anc_ptr, 8);
					
					uint16_t encoderDelay = mad_bit_read(&stream.anc_ptr, 12);
					uint16_t encoderPadding = mad_bit_read(&stream.anc_ptr, 12);

					[self setTotalFrames:[self totalFrames] - (encoderDelay + encoderPadding)];

					// Adjust encoderDelay for MDCT/filterbank delay
					_encoderDelay = encoderDelay + 528 + 1;
					_encoderPadding = encoderPadding;
					
					/*uint8_t misc =*/ mad_bit_read(&stream.anc_ptr, 8);
					
					/*uint8_t mp3Gain =*/ mad_bit_read(&stream.anc_ptr, 8);
					
					/*uint8_t unused =*/mad_bit_read(&stream.anc_ptr, 2);
					/*uint8_t surroundInfo =*/ mad_bit_read(&stream.anc_ptr, 3);
					/*uint16_t presetInfo =*/ mad_bit_read(&stream.anc_ptr, 11);
					
					/*uint32_t musicGain =*/ mad_bit_read(&stream.anc_ptr, 32);
					
					/*uint32_t musicCRC =*/ mad_bit_read(&stream.anc_ptr, 32);
					
					/*uint32_t tagCRC =*/ mad_bit_read(&stream.anc_ptr, 32);
					
					ancillaryBitsRemaining -= LAME_HEADER_SIZE;

					_foundLAMEHeader = YES;
					break;

				}
			}
			else if('Info' == magic) {
				NSLog(@"Found Info CBR header");
				break;
			}
		}
		else {
			// Just estimate the number of frames based on the previous duration estimate
			[self setTotalFrames:[[[self stream] valueForKey:PropertiesDurationKey] longLongValue] * frame.header.samplerate];
			
			// For now, quit after second frame
			break;
		}		
	}

	// Clean up
	mad_frame_finish(&frame);
	mad_stream_finish(&stream);
	
	free(inputBuffer);
	close(fd);
	
	return YES;
}

@end