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

#import "MP3PropertiesReader.h"
#import "AudioStream.h"
#include <mad/mad.h>

#define INPUT_BUFFER_SIZE		(5 * 8192)
#define MPEG_FRAMES_TO_SCAN		32

@implementation MP3PropertiesReader

- (BOOL) readProperties:(NSError **)error
{
	NSMutableDictionary *propertiesDictionary = [NSMutableDictionary dictionary];
	
/*	if(NULL != audioProperties) {
		[propertiesDictionary setValue:[NSString stringWithFormat:NSLocalizedStringFromTable(@"MPEG Layer %i", @"Formats", @""), audioProperties->layer()] forKey:@"fileType"];
		[propertiesDictionary setValue:[NSString stringWithFormat:NSLocalizedStringFromTable(@"MPEG Layer %i", @"Formats", @""), audioProperties->layer()] forKey:@"formatType"];
		
		[propertiesDictionary setValue:[NSNumber numberWithInt:audioProperties->channels()] forKey:@"channelsPerFrame"];
		[propertiesDictionary setValue:[NSNumber numberWithInt:audioProperties->sampleRate()] forKey:@"sampleRate"];

		[propertiesDictionary setValue:[NSNumber numberWithInt:(audioProperties->bitrate() * 1000)] forKey:@"bitrate"];
		[propertiesDictionary setValue:[NSNumber numberWithInt:audioProperties->length()] forKey:@"duration"];
	}
	else {
		[propertiesDictionary setValue:@"MPEG Layer 3" forKey:@"formatName"];		
	}	
*/

	NSString			*path					= [_url path];

	SInt64				framesDecoded			= 0;
	UInt32				bytesToRead				= 0;
	UInt32				bytesRemaining			= 0;
	ssize_t				bytesRead				= 0;
	unsigned char		*inputBuffer			= NULL;
	unsigned char		*readStartPointer		= NULL;
	BOOL				readEOF					= NO;
	
	UInt32				channelsPerFrame		= 0;
	Float64				sampleRate				= 0;
	Float64				averageBitrate			= 0;
	BOOL				isVBR					= NO;
	
	struct mad_stream	stream;
	struct mad_header	header;
	mad_timer_t			timer;
	
	int					result;
	
	//	struct stat			stat;

	// Allocate the input buffer
	inputBuffer = (unsigned char *)calloc(INPUT_BUFFER_SIZE + MAD_BUFFER_GUARD, sizeof(unsigned char));
	if(NULL == inputBuffer) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid MP3 file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not an MP3 file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
										 code:AudioPropertiesReaderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	// Open the input file for scanning
	int fd = open([path fileSystemRepresentation], O_RDONLY);
	if(-1 == fd) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid MP3 file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not an MP3 file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
										 code:AudioPropertiesReaderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		free(inputBuffer);
		return NO;
	}
	
	//	result = fstat(fd, &stat);
	//	NSAssert1(-1 != fd, @"Unable to stat the input file (%s).", strerror(errno));
	
	mad_stream_init(&stream);
	mad_header_init(&header);
//	mad_frame_init(&frame);
	mad_timer_reset(&timer);
	
	BOOL readEOF = NO;
	
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
				if(nil != error) {
					NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
					
					[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid MP3 file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
					[errorDictionary setObject:@"Not an MP3 file" forKey:NSLocalizedFailureReasonErrorKey];
					[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
					
					*error = [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
												 code:AudioPropertiesReaderFileFormatNotRecognizedError 
											 userInfo:errorDictionary];
				}
				
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
		
		result = mad_header_decode(&header, &stream);
		
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
				if(nil != error) {
					NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
					
					[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid MP3 file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
					[errorDictionary setObject:@"Not an MP3 file" forKey:NSLocalizedFailureReasonErrorKey];
					[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
					
					*error = [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
												 code:AudioPropertiesReaderFileFormatNotRecognizedError 
											 userInfo:errorDictionary];
				}
				break;
			}
		}
		
		++framesDecoded;
		mad_timer_add(&timer, header.duration);
		
		// Look for a Xing header in the first frame that was successfully decoded
		// Reference http://www.codeproject.com/audio/MPEGAudioInfo.asp
		if(1 == framesDecoded) {
			
			sampleRate			= header.samplerate;
			channelsPerFrame	= MAD_NCHANNELS(&header);
			averageBitrate		= header.bitrate;
			
			uint32_t magic = mad_bit_read(&stream.anc_ptr, 32);
			
			switch(header.layer) {
				case MAD_LAYER_I:
					[propertiesDictionary setValue:NSLocalizedStringFromTable(@"MPEG Audio", @"Formats", @"") forKey:@"fileType"];
					[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Layer I", @"Formats", @"") forKey:@"formatType"];
					break;
					
				case MAD_LAYER_II:
					[propertiesDictionary setValue:NSLocalizedStringFromTable(@"MPEG Audio", @"Formats", @"") forKey:@"fileType"];
					[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Layer II", @"Formats", @"") forKey:@"formatType"];
					break;
				case MAD_LAYER_III:
					[propertiesDictionary setValue:NSLocalizedStringFromTable(@"MPEG Audio", @"Formats", @"") forKey:@"fileType"];
					[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Layer III", @"Formats", @"") forKey:@"formatType"];
					break;
			}
			
			if('Xing' == magic) {
				//			if((('X' << 24) | ('i' << 16) | ('n' << 8) | ('g')) == magic) {
				
				unsigned	i;
				uint32_t	frames;
				uint32_t	samplesPerMPEGFrame;
				
				uint32_t	flags = mad_bit_read(&stream.anc_ptr, 32);
				
				// 4 byte value containing total frames
				if(FRAMES_FLAG & flags) {					
					// Determine number of samples, discounting encoder delay and padding
					if(MAD_FLAG_LSF_EXT & header.flags || MAD_FLAG_MPEG_2_5_EXT & header.flags) {
						switch(header.layer) {
							case MAD_LAYER_I:		samplesPerMPEGFrame = 384;			break;
							case MAD_LAYER_II:		samplesPerMPEGFrame = 1152;			break;
							case MAD_LAYER_III:		samplesPerMPEGFrame = 576;			break;
						}
					}
					else {
						switch(header.layer) {
							case MAD_LAYER_I:		samplesPerMPEGFrame = 384;			break;
							case MAD_LAYER_II:		samplesPerMPEGFrame = 1152;			break;
							case MAD_LAYER_III:		samplesPerMPEGFrame = 1152;			break;
						}
					}

					frames = mad_bit_read(&stream.anc_ptr, 32);

					[propertiesDictionary setValue:[NSNumber numberWithLongLong:frames * samplesPerMPEGFrame] forKey:@"totalFrames"];
				}
				
				// 4 byte value containing total bytes
				if(BYTES_FLAG & flags) {
					uint32_t bytes = mad_bit_read(&stream.anc_ptr, 32);
				}
				
				// 100 bytes containing TOC information
				if(TOC_FLAG & flags) {
					uint8_t		toc [100];					
					memset(toc, 0, 100);
					
					for(i = 0; i < 100; ++i) {
						toc[i] = mad_bit_read(&stream.anc_ptr, 8);
					}
				}
				
				// 4 byte value indicating encoded vbr scale
				if(VBR_SCALE_FLAG & flags) {
					uint32_t vbr_scale = mad_bit_read(&stream.anc_ptr, 32);
				}
				
				mad_timer_add(&timer, header.duration);
				mad_timer_multiply(&timer, frames);
				
				framesDecoded	= frames;
				float bitrate = 8.0 * (bytes / mad_timer_count(timer, MAD_UNITS_SECONDS));
				[propertiesDictionary setValue:[NSNumber numberWithFloat:bitrate] forKey:@"bitrate"];
				
				// Loook for the LAME header next
				// http://gabriel.mp3-tech.org/mp3infotag.html
				magic = mad_bit_read(&stream.anc_ptr, 32);
				
				if('LAME' == magic) {
					unsigned char versionString [5 + 1];
					memset(versionString, 0, 6);
					
					for(i = 0; i < 5; ++i) {
						versionString[i] = mad_bit_read(&stream.anc_ptr, 8);
					}
					
					uint8_t infoTagRevision = mad_bit_read(&stream.anc_ptr, 4);
					uint8_t vbrMethod = mad_bit_read(&stream.anc_ptr, 4);
					
					uint8_t lowpassFilterValue = mad_bit_read(&stream.anc_ptr, 8);
					
					float peakSignalAmplitude = mad_bit_read(&stream.anc_ptr, 32);
					uint16_t radioReplayGain = mad_bit_read(&stream.anc_ptr, 16);
					uint16_t audiophileReplayGain = mad_bit_read(&stream.anc_ptr, 16);
					
					uint8_t encodingFlags = mad_bit_read(&stream.anc_ptr, 4);
					uint8_t athType = mad_bit_read(&stream.anc_ptr, 4);
					
					uint8_t lameBitrate = mad_bit_read(&stream.anc_ptr, 8);
					
					uint16_t encoderDelay = mad_bit_read(&stream.anc_ptr, 12);
					uint16_t encoderPadding = mad_bit_read(&stream.anc_ptr, 12);
					
					[propertiesDictionary setValue:[NSNumber numberWithLongLong:(frames * samplesPerMPEGFrame) - (encoderDelay + encoderPadding)] forKey:@"totalFrames"];
										
					uint8_t misc = mad_bit_read(&stream.anc_ptr, 8);
					
					uint8_t mp3Gain = mad_bit_read(&stream.anc_ptr, 8);
					
					/*uint8_t garbage =*/mad_bit_read(&stream.anc_ptr, 2);
					uint8_t surroundInfo = mad_bit_read(&stream.anc_ptr, 3);
					uint16_t presetInfo = mad_bit_read(&stream.anc_ptr, 11);
					
					uint32_t musicGain = mad_bit_read(&stream.anc_ptr, 32);
					
					uint32_t musicCRC = mad_bit_read(&stream.anc_ptr, 32);
					
					uint32_t tagCRC = mad_bit_read(&stream.anc_ptr, 32);
				}
				
				break;
				}			
			}		
		}
	}

	// Clean up
	mad_header_finish(&header);
	mad_frame_finish(&frame);
	mad_stream_finish(&stream);
	
	free(inputBuffer);
	close(fd);

	[self setValue:propertiesDictionary forKey:@"properties"];

	return YES;

}

@end