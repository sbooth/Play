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

#import "MPEGPropertiesReader.h"
#import "AudioStream.h"
#include <mad/mad.h>

#include <unistd.h>
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

@implementation MPEGPropertiesReader

- (BOOL) readProperties:(NSError **)error
{
	uint32_t			framesDecoded = 0;
	UInt32				bytesToRead, bytesRemaining;
	size_t				bytesRead;
	unsigned char		*readStartPointer;
	BOOL				readEOF			= NO;
	
	struct mad_stream	stream;
	struct mad_frame	frame;
	
	uint32_t			id3_length		= 0;
	
	unsigned			xingTotalFrames	= 0;
	unsigned			lameTotalFrames	= 0;
	
	unsigned char		inputBuffer		[INPUT_BUFFER_SIZE + MAD_BUFFER_GUARD];
	
	FILE *file = fopen([[_url path] fileSystemRepresentation], "r");
	if(NULL == file) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			//				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The format of the file \"%@\" was not recognized.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			//				[errorDictionary setObject:NSLocalizedStringFromTable(@"File Format Not Recognized", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			//				[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain 
										 code:errno 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	// Set up	
	mad_stream_init(&stream);
	mad_frame_init(&frame);

	NSMutableDictionary *propertiesDictionary = [NSMutableDictionary dictionary];
	
	for(;;) {
		if(NULL == stream.buffer || MAD_ERROR_BUFLEN == stream.error) {
			if(stream.next_frame) {
				bytesRemaining = stream.bufend - stream.next_frame;
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
			bytesRead = fread(readStartPointer, 1, bytesToRead, file);
			if(ferror(file)) {
#if DEBUG
				NSLog(@"Read error: %s.", strerror(errno));
#endif
				break;
			}
			
			// MAD_BUFFER_GUARD zeroes are required to decode the last frame of the file
			if(feof(file)) {
				memset(readStartPointer + bytesRead, 0, MAD_BUFFER_GUARD);
				bytesRead	+= MAD_BUFFER_GUARD;
				readEOF		= YES;
			}
			
			mad_stream_buffer(&stream, inputBuffer, bytesRead + bytesRemaining);
			stream.error = MAD_ERROR_NONE;
		}
		
		int result = mad_frame_decode(&frame, &stream);
		if(-1 == result) {
			if(MAD_RECOVERABLE(stream.error)) {
				// Prevent ID3 tags from reporting recoverable frame errors
				const uint8_t	*buffer			= stream.this_frame;
				unsigned		buflen			= stream.bufend - stream.this_frame;
				
				if(10 <= buflen && 0x49 == buffer[0] && 0x44 == buffer[1] && 0x33 == buffer[2]) {
					id3_length = (((buffer[6] & 0x7F) << (3 * 7)) | ((buffer[7] & 0x7F) << (2 * 7)) |
								  ((buffer[8] & 0x7F) << (1 * 7)) | ((buffer[9] & 0x7F) << (0 * 7)));
					
					// Add 10 bytes for ID3 header
					id3_length += 10;
					
					mad_stream_skip(&stream, id3_length);
				}
#if DEBUG
				else
					NSLog(@"Recoverable frame level error (%s)", mad_stream_errorstr(&stream));
#endif
				
				continue;
			}
			// EOS for non-Xing streams occurs when EOF is reached and no further frames can be decoded
			else if(MAD_ERROR_BUFLEN == stream.error && readEOF)
				break;
			else if(MAD_ERROR_BUFLEN == stream.error)
				continue;
			else {
#if DEBUG
				NSLog(@"Unrecoverable frame level error (%s)", mad_stream_errorstr(&stream));
#endif
				break;
			}
		}
		
		++framesDecoded;
		
		// Look for a Xing header in the first frame that was successfully decoded
		// Reference http://www.codeproject.com/audio/MPEGAudioInfo.asp
		if(1 == framesDecoded) {
			[propertiesDictionary setValue:NSLocalizedStringFromTable(@"MPEG-1 Audio", @"Formats", @"") forKey:PropertiesFileTypeKey];		
			switch(frame.header.layer) {
				case 1:
					[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Layer I", @"Formats", @"") forKey:PropertiesDataFormatKey];
					[propertiesDictionary setValue:NSLocalizedStringFromTable(@"MP1", @"Formats", @"") forKey:PropertiesFormatDescriptionKey];
					break;
				case 2:
					[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Layer II", @"Formats", @"") forKey:PropertiesDataFormatKey];
					[propertiesDictionary setValue:NSLocalizedStringFromTable(@"MP2", @"Formats", @"") forKey:PropertiesFormatDescriptionKey];
					break;
				case 3:
					[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Layer III", @"Formats", @"") forKey:PropertiesDataFormatKey];
					[propertiesDictionary setValue:NSLocalizedStringFromTable(@"MP3", @"Formats", @"") forKey:PropertiesFormatDescriptionKey];
					break;
			}
			
			[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:frame.header.samplerate] forKey:PropertiesSampleRateKey];
			[propertiesDictionary setValue:[NSNumber numberWithInt:MAD_NCHANNELS(&frame.header)] forKey:PropertiesChannelsPerFrameKey];
			
			[propertiesDictionary setValue:[NSNumber numberWithUnsignedLong:frame.header.bitrate] forKey:PropertiesBitrateKey];
			
			unsigned samplesPerMPEGFrame = 32 * MAD_NSBSAMPLES(&frame.header);
			
			unsigned ancillaryBitsRemaining = stream.anc_bitlen;
			if(32 > ancillaryBitsRemaining)
				continue;
			
			uint32_t magic = mad_bit_read(&stream.anc_ptr, 32);
			ancillaryBitsRemaining -= 32;
			
			if('Xing' == magic || 'Info' == magic) {				
				if(32 > ancillaryBitsRemaining)
					continue;
				
				uint32_t flags = mad_bit_read(&stream.anc_ptr, 32);
				ancillaryBitsRemaining -= 32;
				
				// 4 byte value containing total frames
				// For LAME-encoded MP3s, the number of MPEG frames in the file is one greater than this frame
				if(FRAMES_FLAG & flags) {
					if(32 > ancillaryBitsRemaining)
						continue;
					
					uint32_t frames = mad_bit_read(&stream.anc_ptr, 32);
					ancillaryBitsRemaining -= 32;
										
					// Determine number of samples, discounting encoder delay and padding
					// Our concept of a frame is the same as CoreAudio's- one sample across all channels
					xingTotalFrames = frames * samplesPerMPEGFrame;

					[propertiesDictionary setValue:[NSNumber numberWithUnsignedLong:xingTotalFrames] forKey:PropertiesTotalFramesKey];
				}
				
				// 4 byte value containing total bytes
				if(BYTES_FLAG & flags) {
					if(32 > ancillaryBitsRemaining)
						continue;
					
					/*uint32_t bytes =*/ mad_bit_read(&stream.anc_ptr, 32);
					ancillaryBitsRemaining -= 32;
				}
				
				// 100 bytes containing TOC information
				if(TOC_FLAG & flags) {
					if(8 * 100 > ancillaryBitsRemaining)
						continue;
					
					unsigned i;
					for(i = 0; i < 100; ++i)
					/*xingTOC[i] =*/ mad_bit_read(&stream.anc_ptr, 8);
					
					ancillaryBitsRemaining -= (8* 100);
				}
				
				// 4 byte value indicating encoded vbr scale
				if(VBR_SCALE_FLAG & flags) {
					if(32 > ancillaryBitsRemaining)
						continue;
					
					/*uint32_t vbrScale =*/ mad_bit_read(&stream.anc_ptr, 32);
					ancillaryBitsRemaining -= 32;
				}
								
				// Loook for the LAME header next
				// http://gabriel.mp3-tech.org/mp3infotag.html				
				if(32 > ancillaryBitsRemaining)
					continue;
				magic = mad_bit_read(&stream.anc_ptr, 32);
				
				ancillaryBitsRemaining -= 32;
				
				if('LAME' == magic) {
					
					if(LAME_HEADER_SIZE > ancillaryBitsRemaining)
						continue;

					/*unsigned char versionString [5 + 1];
					 memset(versionString, 0, 6);*/
					
					unsigned i;
					for(i = 0; i < 5; ++i)
					/*versionString[i] =*/ mad_bit_read(&stream.anc_ptr, 8);
					
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
					
					// Adjust encoderDelay and encoderPadding for MDCT/filterbank delays
					unsigned QQencoderDelay = encoderDelay + 528 + 1;
					unsigned QQencoderPadding = encoderPadding - (528 + 1);

					lameTotalFrames = xingTotalFrames - (QQencoderDelay + QQencoderPadding);
					
					/*uint8_t misc =*/ mad_bit_read(&stream.anc_ptr, 8);
					
					/*uint8_t mp3Gain =*/ mad_bit_read(&stream.anc_ptr, 8);
					
					/*uint8_t unused =*/mad_bit_read(&stream.anc_ptr, 2);
					/*uint8_t surroundInfo =*/ mad_bit_read(&stream.anc_ptr, 3);
					/*uint16_t presetInfo =*/ mad_bit_read(&stream.anc_ptr, 11);
					
					/*uint32_t musicGain =*/ mad_bit_read(&stream.anc_ptr, 32);
					
					/*uint32_t musicCRC =*/ mad_bit_read(&stream.anc_ptr, 32);
					
					/*uint32_t tagCRC =*/ mad_bit_read(&stream.anc_ptr, 32);
					
					ancillaryBitsRemaining -= LAME_HEADER_SIZE;
					
					break;
				}
			}
		}
		else {
			struct stat stat;
			int result = fstat(fileno(file), &stat);
			if(-1 == result) {
				fclose(file);
				
				if(nil != error) {
					NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
					
					//				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The format of the file \"%@\" was not recognized.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
					//				[errorDictionary setObject:NSLocalizedStringFromTable(@"File Format Not Recognized", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
					//				[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
					
					*error = [NSError errorWithDomain:NSPOSIXErrorDomain 
												 code:errno 
											 userInfo:errorDictionary];
				}
				
				return NO;
			}
			
			// Just estimate the number of frames based on the file's size
			unsigned totalFrames = frame.header.samplerate * ((stat.st_size - id3_length) / (frame.header.bitrate / 8.0));

			[propertiesDictionary setValue:[NSNumber numberWithUnsignedLong:totalFrames] forKey:PropertiesTotalFramesKey];

			// For now, quit after second frame
			break;
		}		
	}
	
	// Clean up
	mad_frame_finish(&frame);
	mad_stream_finish(&stream);
	
	fclose(file);
	
	[self setValue:propertiesDictionary forKey:@"properties"];

	return YES;
}

@end
