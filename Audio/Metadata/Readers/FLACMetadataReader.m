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

#import "FLACMetadataReader.h"
#import "AudioStream.h"
#include <FLAC/metadata.h>

@implementation FLACMetadataReader

- (BOOL) readMetadata:(NSError **)error
{
	NSString						*path				= [_url path];
	FLAC__Metadata_Chain			*chain				= NULL;
	FLAC__Metadata_Iterator			*iterator			= NULL;
	FLAC__StreamMetadata			*block				= NULL;
	unsigned						i;
	char							*fieldName			= NULL;
	char							*fieldValue			= NULL;
	NSMutableDictionary				*metadataDictionary;
	NSString						*key, *value;
	NSImage							*picture;
				
	chain							= FLAC__metadata_chain_new();
	
	NSAssert(NULL != chain, @"Unable to allocate memory.");
	
	if(NO == FLAC__metadata_chain_read(chain, [path fileSystemRepresentation])) {
		
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			switch(FLAC__metadata_chain_status(chain)) {
				case FLAC__METADATA_CHAIN_STATUS_NOT_A_FLAC_FILE:
					[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid FLAC file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
					[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a FLAC file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
					[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
					break;
									
				case FLAC__METADATA_CHAIN_STATUS_BAD_METADATA:
					[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid FLAC file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
					[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a FLAC file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
					[errorDictionary setObject:NSLocalizedStringFromTable(@"The file contains bad metadata.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
					break;
										
				default:
					[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid FLAC file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
					[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a FLAC file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
					[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
					break;
			}
			
			*error = [NSError errorWithDomain:AudioMetadataReaderErrorDomain 
										 code:AudioMetadataReaderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		FLAC__metadata_chain_delete(chain);
		
		return NO;
	}
	
	metadataDictionary	= [NSMutableDictionary dictionary];				
	iterator			= FLAC__metadata_iterator_new();
	
	NSAssert(NULL != iterator, @"Unable to allocate memory.");
	
	FLAC__metadata_iterator_init(iterator, chain);
	
	do {
		block = FLAC__metadata_iterator_get_block(iterator);
		
		if(NULL == block) {
			break;
		}
		
		switch(block->type) {					
			case FLAC__METADATA_TYPE_VORBIS_COMMENT:				
				for(i = 0; i < block->data.vorbis_comment.num_comments; ++i) {
					
					// Let FLAC parse the comment for us
					if(NO == FLAC__metadata_object_vorbiscomment_entry_to_name_value_pair(block->data.vorbis_comment.comments[i], &fieldName, &fieldValue)) {
						// Ignore malformed comments
						continue;
					}
					
					key		= [[NSString alloc] initWithBytesNoCopy:fieldName length:strlen(fieldName) encoding:NSASCIIStringEncoding freeWhenDone:YES];
					value	= [[NSString alloc] initWithBytesNoCopy:fieldValue length:strlen(fieldValue) encoding:NSUTF8StringEncoding freeWhenDone:YES];
				
					if(NSOrderedSame == [key caseInsensitiveCompare:@"ALBUM"])
						[metadataDictionary setValue:value forKey:MetadataAlbumTitleKey];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"ARTIST"])
						[metadataDictionary setValue:value forKey:MetadataArtistKey];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"ALBUMARTIST"])
						[metadataDictionary setValue:value forKey:MetadataAlbumArtistKey];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"COMPOSER"])
						[metadataDictionary setValue:value forKey:MetadataComposerKey];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"GENRE"])
						[metadataDictionary setValue:value forKey:MetadataGenreKey];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"DATE"])
						[metadataDictionary setValue:value forKey:MetadataDateKey];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"DESCRIPTION"])
						[metadataDictionary setValue:value forKey:MetadataCommentKey];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"TITLE"])
						[metadataDictionary setValue:value forKey:MetadataTitleKey];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"TRACKNUMBER"])
						[metadataDictionary setValue:[NSNumber numberWithUnsignedInt:(UInt32)[value intValue]] forKey:MetadataTrackNumberKey];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"TRACKTOTAL"])
						[metadataDictionary setValue:[NSNumber numberWithUnsignedInt:(UInt32)[value intValue]] forKey:MetadataTrackTotalKey];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"COMPILATION"])
						[metadataDictionary setValue:[NSNumber numberWithBool:(BOOL)[value intValue]] forKey:MetadataCompilationKey];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"DISCNUMBER"])
						[metadataDictionary setValue:[NSNumber numberWithUnsignedInt:(UInt32)[value intValue]] forKey:MetadataDiscNumberKey];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"DISCTOTAL"])
						[metadataDictionary setValue:[NSNumber numberWithUnsignedInt:(UInt32)[value intValue]] forKey:MetadataDiscTotalKey];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"ISRC"])
						[metadataDictionary setValue:value forKey:MetadataISRCKey];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"MCN"])
						[metadataDictionary setValue:value forKey:MetadataMCNKey];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"BPM"])
						[metadataDictionary setValue:[NSNumber numberWithUnsignedInt:(UInt32)[value intValue]] forKey:MetadataBPMKey];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"REPLAYGAIN_REFERENCE_LOUDNESS"]) {
						NSScanner	*scanner		= [NSScanner scannerWithString:value];						
						double		doubleValue		= 0.0;
						
						if([scanner scanDouble:&doubleValue]) {
							[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainReferenceLoudnessKey];
						}						
					}
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"REPLAYGAIN_TRACK_GAIN"]) {
						NSScanner	*scanner		= [NSScanner scannerWithString:value];						
						double		doubleValue		= 0.0;
						
						if([scanner scanDouble:&doubleValue])
							[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainTrackGainKey];
					}
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"REPLAYGAIN_TRACK_PEAK"]) {
						[metadataDictionary setValue:[NSNumber numberWithDouble:[value doubleValue]] forKey:ReplayGainTrackPeakKey];
					}
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"REPLAYGAIN_ALBUM_GAIN"]) {
						NSScanner	*scanner		= [NSScanner scannerWithString:value];						
						double		doubleValue		= 0.0;
						
						if([scanner scanDouble:&doubleValue])
							[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainAlbumGainKey];
					}
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"REPLAYGAIN_ALBUM_PEAK"])
						[metadataDictionary setValue:[NSNumber numberWithDouble:[value doubleValue]] forKey:ReplayGainAlbumPeakKey];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"MUSICDNS_PUID"])
						[metadataDictionary setValue:value forKey:MetadataMusicDNSPUIDKey];
					else if(NSOrderedSame == [key caseInsensitiveCompare:@"MUSICBRAINZ_ID"])
						[metadataDictionary setValue:value forKey:MetadataMusicBrainzIDKey];

					[key release];
					[value release];
					
					fieldName	= NULL;
					fieldValue	= NULL;
				}
				break;
				
			case FLAC__METADATA_TYPE_PICTURE:
				picture = [[NSImage alloc] initWithData:[NSData dataWithBytes:block->data.picture.data length:block->data.picture.data_length]];
				if(nil != picture) {
					[metadataDictionary setValue:[picture TIFFRepresentation] forKey:@"albumArt"];
					[picture release];
				}
				break;
				
			case FLAC__METADATA_TYPE_STREAMINFO:					break;
			case FLAC__METADATA_TYPE_PADDING:						break;
			case FLAC__METADATA_TYPE_APPLICATION:					break;
			case FLAC__METADATA_TYPE_SEEKTABLE:						break;
			case FLAC__METADATA_TYPE_CUESHEET:						break;
			case FLAC__METADATA_TYPE_UNDEFINED:						break;
			default:												break;
		}
	} while(FLAC__metadata_iterator_next(iterator));
	
	FLAC__metadata_iterator_delete(iterator);
	FLAC__metadata_chain_delete(chain);
	
	[self setValue:metadataDictionary forKey:@"metadata"];

	return YES;
}

@end
