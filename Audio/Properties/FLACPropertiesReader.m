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

#import "FLACPropertiesReader.h"
#import "AudioStream.h"
#include <FLAC/metadata.h>

@implementation FLACPropertiesReader

- (BOOL) readProperties:(NSError **)error
{
	NSString					*path		= [_url path];
	FLAC__Metadata_Chain		*chain		= NULL;
	FLAC__Metadata_Iterator		*iterator	= NULL;
	FLAC__StreamMetadata		*block		= NULL;
				
	chain = FLAC__metadata_chain_new();
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
			
			*error = [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
										 code:AudioPropertiesReaderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		FLAC__metadata_chain_delete(chain);
		
		return NO;
	}
	
	iterator = FLAC__metadata_iterator_new();
	NSAssert(NULL != iterator, @"Unable to allocate memory.");
	
	FLAC__metadata_iterator_init(iterator, chain);
	
	unsigned i;
	NSMutableDictionary		*propertiesDictionary	= [NSMutableDictionary dictionary];
	NSMutableDictionary		*cueSheetDictionary		= nil;
	NSMutableArray			*cueSheetTracks			= nil;

	do {
		block = FLAC__metadata_iterator_get_block(iterator);
		
		if(NULL == block)
			break;
		
		switch(block->type) {					
			case FLAC__METADATA_TYPE_STREAMINFO:
				[propertiesDictionary setValue:NSLocalizedStringFromTable(@"FLAC", @"Formats", @"") forKey:PropertiesFileTypeKey];
				[propertiesDictionary setValue:NSLocalizedStringFromTable(@"FLAC", @"Formats", @"") forKey:PropertiesDataFormatKey];
				[propertiesDictionary setValue:NSLocalizedStringFromTable(@"FLAC", @"Formats", @"") forKey:PropertiesFormatDescriptionKey];
				[propertiesDictionary setValue:[NSNumber numberWithLongLong:block->data.stream_info.total_samples] forKey:PropertiesTotalFramesKey];
				[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:block->data.stream_info.bits_per_sample] forKey:PropertiesBitsPerChannelKey];
				[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:block->data.stream_info.channels] forKey:PropertiesChannelsPerFrameKey];
				[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:block->data.stream_info.sample_rate] forKey:PropertiesSampleRateKey];				
				break;
				
			case FLAC__METADATA_TYPE_CUESHEET:
#if CUE_SHEET_DEBUG
				NSLog(@"FLAC cue sheet");
				NSLog(@"  media_catalog_number : %s", block->data.cue_sheet.media_catalog_number);
				NSLog(@"  lead_in              : %i", block->data.cue_sheet.lead_in);
				NSLog(@"  is_cd                : %i", block->data.cue_sheet.is_cd);
				NSLog(@"  num_tracks           : %i", block->data.cue_sheet.num_tracks);
#endif

				cueSheetDictionary	= [NSMutableDictionary dictionary];
				cueSheetTracks		= [NSMutableArray array];
				
				[cueSheetDictionary setValue:[NSString stringWithUTF8String:block->data.cue_sheet.media_catalog_number] forKey:MetadataMCNKey];
				
				// Iterate through each track in the cue sheet and process each one
				for(i = 0; i < block->data.cue_sheet.num_tracks; ++i) {
#if CUE_SHEET_DEBUG
					NSLog(@"  Track %i", i);
					NSLog(@"    offset             : %qi", block->data.cue_sheet.tracks[i].offset);
					NSLog(@"    number             : %i", block->data.cue_sheet.tracks[i].number);
					NSLog(@"    isrc               : %s", block->data.cue_sheet.tracks[i].isrc);
					NSLog(@"    type               : %i", block->data.cue_sheet.tracks[i].type);
					NSLog(@"    pre_emphasis       : %i", block->data.cue_sheet.tracks[i].pre_emphasis);
					NSLog(@"    num_indices        : %i", block->data.cue_sheet.tracks[i].num_indices);
					
					// Index points are unused for now
					unsigned j;
					for(j = 0; j < block->data.cue_sheet.tracks[i].num_indices; ++j) {
						NSLog(@"    Index %i", j);
						NSLog(@"      offset           : %qi", block->data.cue_sheet.tracks[i].indices[j].offset);
						NSLog(@"      number           : %i", block->data.cue_sheet.tracks[i].indices[j].number);
					}
#endif
					
					// Only process audio tracks
					// 0 is audio, 1 is non-audio
					if(0 == block->data.cue_sheet.tracks[i].type) {
						NSMutableDictionary *trackDictionary = [NSMutableDictionary dictionary];
						
						[trackDictionary setValue:[NSString stringWithUTF8String:block->data.cue_sheet.tracks[i].isrc] forKey:MetadataISRCKey];
						[trackDictionary setValue:[NSNumber numberWithInt:block->data.cue_sheet.tracks[i].number] forKey:MetadataTrackNumberKey];
						[trackDictionary setValue:[NSNumber numberWithUnsignedLongLong:block->data.cue_sheet.tracks[i].offset] forKey:StreamStartingFrameKey];
						
						// Fill in frame counts
						if(0 < i) {
							unsigned frameCount = (block->data.cue_sheet.tracks[i].offset - 1) - block->data.cue_sheet.tracks[i - 1].offset;
							
							[[cueSheetTracks objectAtIndex:(i - 1)] setValue:[NSNumber numberWithUnsignedInt:frameCount] forKey:StreamFrameCountKey];
						}
						
						// Special handling for the last audio track
						// FIXME: Is it safe the assume the lead out will always be the final track in the cue sheet?
						if(i == block->data.cue_sheet.num_tracks - 1 - 1) {
							unsigned frameCount = [[propertiesDictionary valueForKey:PropertiesTotalFramesKey] unsignedLongLongValue] - block->data.cue_sheet.tracks[i].offset + 1;

							[trackDictionary setValue:[NSNumber numberWithUnsignedInt:frameCount] forKey:StreamFrameCountKey];
						}

						// Don't add the lead-out as a track
						if(1 <= block->data.cue_sheet.tracks[i].number && 99 >= block->data.cue_sheet.tracks[i].number)
							[cueSheetTracks addObject:trackDictionary];
					}
				}

				[cueSheetDictionary setValue:cueSheetTracks forKey:AudioPropertiesCueSheetTracksKey];
				[propertiesDictionary setValue:cueSheetDictionary forKey:AudioPropertiesCueSheetKey];
				break;

			case FLAC__METADATA_TYPE_VORBIS_COMMENT:				break;
			case FLAC__METADATA_TYPE_PICTURE:						break;
			case FLAC__METADATA_TYPE_PADDING:						break;
			case FLAC__METADATA_TYPE_APPLICATION:					break;
			case FLAC__METADATA_TYPE_SEEKTABLE:						break;
			case FLAC__METADATA_TYPE_UNDEFINED:						break;
			default:												break;
		}
	} while(FLAC__metadata_iterator_next(iterator));
	
	FLAC__metadata_iterator_delete(iterator);
	FLAC__metadata_chain_delete(chain);
	
	[self setValue:propertiesDictionary forKey:@"properties"];

	return YES;
}

@end
