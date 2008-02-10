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

#import "MP3MetadataReader.h"
#import "AudioStream.h"
#include <taglib/mpegfile.h>
#include <taglib/id3v2tag.h>
#include <taglib/id3v2frame.h>
#include <taglib/attachedpictureframe.h>
#include <taglib/relativevolumeframe.h>
#include <taglib/textidentificationframe.h>

#include <mad/mad.h>

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

@interface MP3MetadataReader (Private)
- (BOOL) scanForXingAndLAMEHeaders:(NSMutableDictionary *)metadataDictionary;
@end

@implementation MP3MetadataReader

- (BOOL) readMetadata:(NSError **)error
{
	NSMutableDictionary						*metadataDictionary;
	NSString								*path				= [_url path];
	TagLib::MPEG::File						f					([path fileSystemRepresentation], false);
	TagLib::String							s;
	NSString								*trackString, *trackNum, *totalTracks;
	NSString								*discString, *discNum, *totalDiscs;
	NSRange									range;
	BOOL									foundReplayGain		= NO;
	
	if(NO == f.isValid()) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid MPEG file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not an MPEG file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataReaderErrorDomain 
										 code:AudioMetadataReaderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
	
		return NO;
	}
	
	metadataDictionary = [NSMutableDictionary dictionary];

	// Album title
	s = f.tag()->album();
	if(false == s.isNull())
		[metadataDictionary setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:MetadataAlbumTitleKey];
	
	// Artist
	s = f.tag()->artist();
	if(false == s.isNull())
		[metadataDictionary setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:MetadataArtistKey];
	
	// Genre
	s = f.tag()->genre();
	if(false == s.isNull())
		[metadataDictionary setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:MetadataGenreKey];
	
	// Year
	if(0 != f.tag()->year())
		[metadataDictionary setValue:[[NSNumber numberWithInt:f.tag()->year()] stringValue] forKey:MetadataDateKey];
	
	// Comment
	s = f.tag()->comment();
	if(false == s.isNull())
		[metadataDictionary setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:MetadataCommentKey];
	
	// Track title
	s = f.tag()->title();
	if(false == s.isNull())
		[metadataDictionary setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:MetadataTitleKey];
	
	// Track number
	if(0 != f.tag()->track())
		[metadataDictionary setValue:[NSNumber numberWithInt:f.tag()->track()] forKey:MetadataTrackNumberKey];
			
	TagLib::ID3v2::Tag *id3v2tag = f.ID3v2Tag();
	
	if(NULL != id3v2tag) {
		
		// Extract composer if present
		TagLib::ID3v2::FrameList frameList = id3v2tag->frameListMap()["TCOM"];
		if(NO == frameList.isEmpty())
			[metadataDictionary setValue:[NSString stringWithUTF8String:frameList.front()->toString().toCString(true)] forKey:MetadataComposerKey];
		
		// Extract album artist
		frameList = id3v2tag->frameListMap()["TPE2"];
		if(NO == frameList.isEmpty())
			[metadataDictionary setValue:[NSString stringWithUTF8String:frameList.front()->toString().toCString(true)] forKey:MetadataAlbumArtistKey];

		// BPM
		frameList = id3v2tag->frameListMap()["TBPM"];
		if(NO == frameList.isEmpty()) {
			NSString *bpmString = [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
			[metadataDictionary setValue:[NSNumber numberWithInt:[bpmString intValue]] forKey:MetadataBPMKey];
		}
		
		// Extract total tracks if present
		frameList = id3v2tag->frameListMap()["TRCK"];
		if(NO == frameList.isEmpty()) {
			// Split the tracks at '/'
			trackString		= [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
			range			= [trackString rangeOfString:@"/" options:NSLiteralSearch];

			if(NSNotFound != range.location && 0 != range.length) {
				trackNum		= [trackString substringToIndex:range.location];
				totalTracks		= [trackString substringFromIndex:range.location + 1];
				
				[metadataDictionary setValue:[NSNumber numberWithInt:[trackNum intValue]] forKey:MetadataTrackNumberKey];
				[metadataDictionary setValue:[NSNumber numberWithInt:[totalTracks intValue]] forKey:MetadataTrackTotalKey];
			}
			else if(0 != [trackString length])
				[metadataDictionary setValue:[NSNumber numberWithInt:[trackString intValue]] forKey:MetadataTrackNumberKey];
		}
		
		// Extract disc number and total discs
		frameList = id3v2tag->frameListMap()["TPOS"];
		if(NO == frameList.isEmpty()) {
			// Split the tracks at '/'
			discString		= [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
			range			= [discString rangeOfString:@"/" options:NSLiteralSearch];
			
			if(NSNotFound != range.location && 0 != range.length) {
				discNum			= [discString substringToIndex:range.location];
				totalDiscs		= [discString substringFromIndex:range.location + 1];
				
				[metadataDictionary setValue:[NSNumber numberWithInt:[discNum intValue]] forKey:MetadataDiscNumberKey];
				[metadataDictionary setValue:[NSNumber numberWithInt:[totalDiscs intValue]] forKey:MetadataDiscTotalKey];
			}
			else if(0 != [discString length])
				[metadataDictionary setValue:[NSNumber numberWithInt:[discString intValue]] forKey:MetadataDiscNumberKey];
		}
		
		// Extract album art if present
/*		TagLib::ID3v2::AttachedPictureFrame *picture = NULL;
		frameList = id3v2tag->frameListMap()["APIC"];
		if(NO == frameList.isEmpty() && NULL != (picture = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(frameList.front()))) {
			TagLib::ByteVector	bv		= picture->picture();
			NSImage				*image	= [[NSImage alloc] initWithData:[NSData dataWithBytes:bv.data() length:bv.size()]];
			if(nil != image) {
				[metadataDictionary setValue:[image TIFFRepresentation] forKey:@"albumArt"];
				[image release];
			}
		}*/
		
		// Extract compilation if present (iTunes TCMP tag)
		frameList = id3v2tag->frameListMap()["TCMP"];
		if(NO == frameList.isEmpty())
			// It seems that the presence of this frame indicates a compilation
			[metadataDictionary setValue:[NSNumber numberWithBool:YES] forKey:MetadataCompilationKey];

		// ReplayGain
		// Preference is TXXX frames, RVA2 frame, then LAME header
		TagLib::ID3v2::UserTextIdentificationFrame *trackGainFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.ID3v2Tag(), "REPLAYGAIN_TRACK_GAIN");
		TagLib::ID3v2::UserTextIdentificationFrame *trackPeakFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.ID3v2Tag(), "REPLAYGAIN_TRACK_PEAK");
		TagLib::ID3v2::UserTextIdentificationFrame *albumGainFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.ID3v2Tag(), "REPLAYGAIN_ALBUM_GAIN");
		TagLib::ID3v2::UserTextIdentificationFrame *albumPeakFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.ID3v2Tag(), "REPLAYGAIN_ALBUM_PEAK");
		
		if(NULL == trackGainFrame)
			trackGainFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.ID3v2Tag(), "replaygain_track_gain");
		if(NULL != trackGainFrame) {
			NSString	*value			= [NSString stringWithUTF8String:trackGainFrame->fieldList().back().toCString(true)];
			NSScanner	*scanner		= [NSScanner scannerWithString:value];
			double		doubleValue		= 0.0;
			
			if([scanner scanDouble:&doubleValue]) {
				[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainTrackGainKey];
				[metadataDictionary setValue:[NSNumber numberWithDouble:89.0] forKey:ReplayGainReferenceLoudnessKey];
				foundReplayGain = YES;
			}
		}
		
		if(NULL == trackPeakFrame)
			trackPeakFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.ID3v2Tag(), "replaygain_track_peak");
		if(NULL != trackPeakFrame) {
			NSString *value = [NSString stringWithUTF8String:trackPeakFrame->fieldList().back().toCString(true)];
			[metadataDictionary setValue:[NSNumber numberWithDouble:[value doubleValue]] forKey:ReplayGainTrackPeakKey];
		}
		
		if(NULL == albumGainFrame)
			albumGainFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.ID3v2Tag(), "replaygain_album_gain");
		if(NULL != albumGainFrame) {
			NSString	*value			= [NSString stringWithUTF8String:albumGainFrame->fieldList().back().toCString(true)];
			NSScanner	*scanner		= [NSScanner scannerWithString:value];
			double		doubleValue		= 0.0;
			
			if([scanner scanDouble:&doubleValue]) {
				[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainAlbumGainKey];
				[metadataDictionary setValue:[NSNumber numberWithDouble:89.0] forKey:ReplayGainReferenceLoudnessKey];
				foundReplayGain = YES;
			}
		}
		
		if(NULL == albumPeakFrame)
			albumPeakFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.ID3v2Tag(), "replaygain_album_peak");
		if(NULL != albumPeakFrame) {
			NSString *value = [NSString stringWithUTF8String:albumPeakFrame->fieldList().back().toCString(true)];
			[metadataDictionary setValue:[NSNumber numberWithDouble:[value doubleValue]] forKey:ReplayGainAlbumPeakKey];
		}

		// If nothing found check for RVA2 frame
		if(NO == foundReplayGain) {
			frameList = id3v2tag->frameListMap()["RVA2"];
			
			TagLib::ID3v2::FrameList::Iterator frameIterator;
			for(frameIterator = frameList.begin(); frameIterator != frameList.end(); ++frameIterator) {
				TagLib::ID3v2::RelativeVolumeFrame *relativeVolume = dynamic_cast<TagLib::ID3v2::RelativeVolumeFrame *>(*frameIterator);
				if(NULL == relativeVolume)
					continue;
				
				if(TagLib::String("track", TagLib::String::Latin1) == relativeVolume->identification()) {
					// Attempt to use the master volume if present
					TagLib::List<TagLib::ID3v2::RelativeVolumeFrame::ChannelType>	channels		= relativeVolume->channels();
					TagLib::ID3v2::RelativeVolumeFrame::ChannelType					channelType		= TagLib::ID3v2::RelativeVolumeFrame::MasterVolume;
					
					// Fall back on whatever else exists in the frame
					if(NO == channels.contains(TagLib::ID3v2::RelativeVolumeFrame::MasterVolume))
						channelType = channels.front();
					
					float volumeAdjustment = relativeVolume->volumeAdjustment(channelType);
					
					if(0 != volumeAdjustment) {
						[metadataDictionary setValue:[NSNumber numberWithFloat:volumeAdjustment] forKey:ReplayGainTrackGainKey];
						foundReplayGain = YES;
					}
				}
				else if(TagLib::String("album", TagLib::String::Latin1) == relativeVolume->identification()) {
					// Attempt to use the master volume if present
					TagLib::List<TagLib::ID3v2::RelativeVolumeFrame::ChannelType>	channels		= relativeVolume->channels();
					TagLib::ID3v2::RelativeVolumeFrame::ChannelType					channelType		= TagLib::ID3v2::RelativeVolumeFrame::MasterVolume;
					
					// Fall back on whatever else exists in the frame
					if(NO == channels.contains(TagLib::ID3v2::RelativeVolumeFrame::MasterVolume))
						channelType = channels.front();
					
					float volumeAdjustment = relativeVolume->volumeAdjustment(channelType);
					
					if(0 != volumeAdjustment) {
						[metadataDictionary setValue:[NSNumber numberWithFloat:volumeAdjustment] forKey:ReplayGainAlbumGainKey];
						foundReplayGain = YES;
					}
				}
				// Fall back to track gain if identification is not specified
				else {
					// Attempt to use the master volume if present
					TagLib::List<TagLib::ID3v2::RelativeVolumeFrame::ChannelType>	channels		= relativeVolume->channels();
					TagLib::ID3v2::RelativeVolumeFrame::ChannelType					channelType		= TagLib::ID3v2::RelativeVolumeFrame::MasterVolume;
					
					// Fall back on whatever else exists in the frame
					if(NO == channels.contains(TagLib::ID3v2::RelativeVolumeFrame::MasterVolume))
						channelType = channels.front();
					
					float volumeAdjustment = relativeVolume->volumeAdjustment(channelType);
					
					if(0 != volumeAdjustment) {
						[metadataDictionary setValue:[NSNumber numberWithFloat:volumeAdjustment] forKey:ReplayGainTrackGainKey];
						foundReplayGain = YES;
					}
				}
			}			
		}	
	}
	
	// If still nothing, scan for LAME header
	if(NO == foundReplayGain)
		[self scanForXingAndLAMEHeaders:metadataDictionary];

	[self setValue:metadataDictionary forKey:@"metadata"];

	return YES;
}

@end

@implementation MP3MetadataReader (Private)

- (BOOL) scanForXingAndLAMEHeaders:(NSMutableDictionary *)metadataDictionary
{
	uint32_t			framesDecoded = 0;
	UInt32				bytesToRead, bytesRemaining;
	ssize_t				bytesRead;
	unsigned char		*readStartPointer;
	BOOL				readEOF;
	
	struct mad_stream	stream;
	struct mad_frame	frame;
	
	int					result;
//	struct stat			stat;
	
	// Set up	
	unsigned char *inputBuffer = (unsigned char *)calloc(INPUT_BUFFER_SIZE + MAD_BUFFER_GUARD, sizeof(unsigned char));
	if(NULL == inputBuffer)
		return NO;
	
	int fd = open([[_url path] fileSystemRepresentation], O_RDONLY);
	if(-1 == fd) {
		free(inputBuffer);
		return NO;
	}
	
	mad_stream_init(&stream);
	mad_frame_init(&frame);
	
	readEOF = NO;
	
/*	result = fstat(fd, &stat);
	if(-1 == result) {
		free(inputBuffer);
		close(fd);
		return NO;
	}*/
		
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
#if DEBUG
				NSLog(@"Read error: %s.", strerror(errno));
#endif
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
				
				// Prevent ID3 tags from reporting recoverable frame errors
				const uint8_t	*buffer			= stream.this_frame;
				unsigned		buflen			= stream.bufend - stream.this_frame;
				uint32_t		id3_length		= 0;
				
				if(10 <= buflen && 0x49 == buffer[0] && 0x44 == buffer[1] && 0x33 == buffer[2]) {
					id3_length = (((buffer[6] & 0x7F) << (3 * 7)) | ((buffer[7] & 0x7F) << (2 * 7)) |
								  ((buffer[8] & 0x7F) << (1 * 7)) | ((buffer[9] & 0x7F) << (0 * 7)));
					
					// Add 10 bytes for ID3 header
					id3_length += 10;
					
					mad_stream_skip(&stream, id3_length);
				}
				else {
#if DEBUG
					NSLog(@"Recoverable frame level error (%s)", mad_stream_errorstr(&stream));
#endif
				}
				
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
						
			unsigned ancillaryBitsRemaining = stream.anc_bitlen;
			
			if(32 > ancillaryBitsRemaining) { continue; }
			
			uint32_t magic = mad_bit_read(&stream.anc_ptr, 32);
			ancillaryBitsRemaining -= 32;
			
			if('Xing' == magic || 'Info' == magic) {
				//			if((('X' << 24) | ('i' << 16) | ('n' << 8) | ('g')) == magic) {
				
				unsigned	i;
				uint32_t	flags = 0, frames = 0, bytes = 0, vbrScale = 0;
				
				if(32 > ancillaryBitsRemaining) { continue; }
				
				flags = mad_bit_read(&stream.anc_ptr, 32);
				ancillaryBitsRemaining -= 32;
				
				// 4 byte value containing total frames
				if(FRAMES_FLAG & flags) {
					if(32 > ancillaryBitsRemaining) { continue; }
					
					frames = mad_bit_read(&stream.anc_ptr, 32);
					ancillaryBitsRemaining -= 32;					
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
					
					for(i = 0; i < 100; ++i)
						/*xingTOC[i] =*/ mad_bit_read(&stream.anc_ptr, 8);
					
					ancillaryBitsRemaining -= (8 * 100);
				}
				
				// 4 byte value indicating encoded vbr scale
				if(VBR_SCALE_FLAG & flags) {
					if(32 > ancillaryBitsRemaining) { continue; }
					
					vbrScale = mad_bit_read(&stream.anc_ptr, 32);
					ancillaryBitsRemaining -= 32;
				}
				
				framesDecoded = frames;
				
				// Loook for the LAME header next
				// http://gabriel.mp3-tech.org/mp3infotag.html				
				if(32 > ancillaryBitsRemaining) { continue; }
				magic = mad_bit_read(&stream.anc_ptr, 32);
				
				ancillaryBitsRemaining -= 32;
				
				if('LAME' == magic) {
					
					if(LAME_HEADER_SIZE > ancillaryBitsRemaining) { continue; }
					
					/*unsigned char versionString [5 + 1];
					memset(versionString, 0, 6);*/
					
					for(i = 0; i < 5; ++i)
						/*versionString[i] =*/ mad_bit_read(&stream.anc_ptr, 8);
					
					/*uint8_t infoTagRevision =*/ mad_bit_read(&stream.anc_ptr, 4);
					/*uint8_t vbrMethod =*/ mad_bit_read(&stream.anc_ptr, 4);
					
					/*uint8_t lowpassFilterValue =*/ mad_bit_read(&stream.anc_ptr, 8);
					
					float peakSignalAmplitude = mad_bit_read(&stream.anc_ptr, 32);
					if(0 != peakSignalAmplitude)
						[metadataDictionary setValue:[NSNumber numberWithFloat:peakSignalAmplitude] forKey:ReplayGainTrackPeakKey];

					uint16_t radioReplayGain = mad_bit_read(&stream.anc_ptr, 16);
					if(0 != radioReplayGain) {
						BOOL		negative		= 0 != (radioReplayGain & 0x0200);
						uint16_t	adjustment		= radioReplayGain & 0x01FF;		
						double		replayGainDB	= (negative ? -1 : 1) * (adjustment / 10.0);
						
						[metadataDictionary setValue:[NSNumber numberWithDouble:replayGainDB] forKey:ReplayGainTrackGainKey];
						[metadataDictionary setValue:[NSNumber numberWithDouble:89.0] forKey:ReplayGainReferenceLoudnessKey];
					}
					
					uint16_t audiophileReplayGain = mad_bit_read(&stream.anc_ptr, 16);
					if(0 != audiophileReplayGain) {
						BOOL		negative		= 0 != (audiophileReplayGain & 0x0200);
						uint16_t	adjustment		= audiophileReplayGain & 0x01FF;		
						double		replayGainDB	= (negative ? -1 : 1) * (adjustment / 10.0);

						[metadataDictionary setValue:[NSNumber numberWithDouble:replayGainDB] forKey:ReplayGainAlbumGainKey];
						[metadataDictionary setValue:[NSNumber numberWithDouble:89.0] forKey:ReplayGainReferenceLoudnessKey];
					}
					
					/*uint8_t encodingFlags =*/ mad_bit_read(&stream.anc_ptr, 4);
					/*uint8_t athType =*/ mad_bit_read(&stream.anc_ptr, 4);
					
					/*uint8_t lameBitrate =*/ mad_bit_read(&stream.anc_ptr, 8);
					
					/*uint16_t encoderDelay =*/ mad_bit_read(&stream.anc_ptr, 12);
					/*uint16_t encoderPadding =*/ mad_bit_read(&stream.anc_ptr, 12);
										
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
		else
			// For now, quit after second frame
			break;
	}
	
	// Clean up
	mad_frame_finish(&frame);
	mad_stream_finish(&stream);
	
	free(inputBuffer);
	close(fd);
	
	return YES;
}

@end
