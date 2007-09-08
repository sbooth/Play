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

#import "FLACMetadataWriter.h"
#import "AudioStream.h"
#include <FLAC/metadata.h>

static void
setVorbisComment(FLAC__StreamMetadata		*block,
				 NSString					*key,
				 NSString					*value)
{
	NSCParameterAssert(NULL != block);
	NSCParameterAssert(nil != key);

	int success = FLAC__metadata_object_vorbiscomment_remove_entry_matching(block, [key cStringUsingEncoding:NSASCIIStringEncoding]);
	NSCAssert(-1 != success, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	
	if(nil != value) {
		FLAC__StreamMetadata_VorbisComment_Entry entry;

		FLAC__bool result = FLAC__metadata_object_vorbiscomment_entry_from_name_value_pair(&entry, [key cStringUsingEncoding:NSASCIIStringEncoding], [value UTF8String]);
		NSCAssert(YES == result, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
		
		result = FLAC__metadata_object_vorbiscomment_replace_comment(block, entry, NO, NO);
		NSCAssert(YES == result, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	}
}

@implementation FLACMetadataWriter

- (BOOL) writeMetadata:(id)metadata error:(NSError **)error
{
	NSString						*path				= [_url path];
	FLAC__Metadata_Iterator			*iterator			= NULL;
	FLAC__StreamMetadata			*block				= NULL;
	NSNumber						*numericValue		= nil;
	FLAC__bool						result;
				
	FLAC__Metadata_Chain *chain = FLAC__metadata_chain_new();
	NSAssert(NULL != chain, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));

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
			
			*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
										 code:AudioMetadataWriterFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		FLAC__metadata_chain_delete(chain);
		
		return NO;
	}
	
	FLAC__metadata_chain_sort_padding(chain);

	iterator = FLAC__metadata_iterator_new();
	NSAssert(NULL != iterator, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	
	FLAC__metadata_iterator_init(iterator, chain);
	
	// Seek to the vorbis comment block if it exists
	while(FLAC__METADATA_TYPE_VORBIS_COMMENT != FLAC__metadata_iterator_get_block_type(iterator)) {
		if(NO == FLAC__metadata_iterator_next(iterator))
			break; // Already at end
	}
	
	// If there isn't a vorbis comment block add one
	if(FLAC__METADATA_TYPE_VORBIS_COMMENT != FLAC__metadata_iterator_get_block_type(iterator)) {
		
		// The padding block will be the last block if it exists; add the comment block before it
		if(FLAC__METADATA_TYPE_PADDING == FLAC__metadata_iterator_get_block_type(iterator))
			FLAC__metadata_iterator_prev(iterator);
		
		block = FLAC__metadata_object_new(FLAC__METADATA_TYPE_VORBIS_COMMENT);
		NSAssert(NULL != block, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
		
		// Add our metadata
		result = FLAC__metadata_iterator_insert_block_after(iterator, block);
		if(NO == result) {
			if(nil != error) {
				NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
				NSString				*path				= [_url path];
				
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid FLAC file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"Unable to write metadata", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
				
				*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
											 code:AudioMetadataWriterInputOutputError 
										 userInfo:errorDictionary];
			}
			
			FLAC__metadata_chain_delete(chain);
			FLAC__metadata_iterator_delete(iterator);

			return NO;
		}
	}
	else
		block = FLAC__metadata_iterator_get_block(iterator);
	
	// Album title
	setVorbisComment(block, @"ALBUM", [metadata valueForKey:MetadataAlbumTitleKey]);
	
	// Artist
	setVorbisComment(block, @"ARTIST", [metadata valueForKey:MetadataArtistKey]);

	// Album Artist
	setVorbisComment(block, @"ALBUMARTIST", [metadata valueForKey:MetadataAlbumArtistKey]);

	// Composer
	setVorbisComment(block, @"COMPOSER", [metadata valueForKey:MetadataComposerKey]);
	
	// Genre
	setVorbisComment(block, @"GENRE", [metadata valueForKey:MetadataGenreKey]);
	
	// Date
	setVorbisComment(block, @"DATE", [metadata valueForKey:MetadataDateKey]);
	
	// Comment
	setVorbisComment(block, @"DESCRIPTION", [metadata valueForKey:MetadataCommentKey]);
	
	// Track title
	setVorbisComment(block, @"TITLE", [metadata valueForKey:MetadataTitleKey]);
	
	// Track number
	numericValue = [metadata valueForKey:MetadataTrackNumberKey];
	setVorbisComment(block, @"TRACKNUMBER", (nil == numericValue? nil : [numericValue stringValue]));
	
	// Total tracks
	numericValue = [metadata valueForKey:MetadataTrackTotalKey];
	setVorbisComment(block, @"TRACKTOTAL", (nil == numericValue? nil : [numericValue stringValue]));
	
	// Compilation
	numericValue = [metadata valueForKey:MetadataCompilationKey];
	setVorbisComment(block, @"COMPILATION", (nil == numericValue? nil : [numericValue stringValue]));
	
	// Disc number
	numericValue = [metadata valueForKey:MetadataDiscNumberKey];
	setVorbisComment(block, @"DISCNUMBER", (nil == numericValue? nil : [numericValue stringValue]));
	
	// Discs in set
	numericValue = [metadata valueForKey:MetadataDiscTotalKey];
	setVorbisComment(block, @"DISCTOTAL", (nil == numericValue? nil : [numericValue stringValue]));
	
	// ISRC
	setVorbisComment(block, @"ISRC", [metadata valueForKey:MetadataISRCKey]);
	
	// MCN
	setVorbisComment(block, @"MCN", [metadata valueForKey:MetadataMCNKey]);

	// BPM
	numericValue = [metadata valueForKey:MetadataBPMKey];
	setVorbisComment(block, @"BPM", (nil == numericValue? nil : [numericValue stringValue]));

	// ReplayGain
	numericValue = [metadata valueForKey:ReplayGainReferenceLoudnessKey];
	setVorbisComment(block, @"REPLAYGAIN_REFERENCE_LOUDNESS", (nil == numericValue ? nil : [NSString stringWithFormat:@"%2.1f dB", [numericValue doubleValue]]));

	numericValue = [metadata valueForKey:ReplayGainTrackGainKey];
	setVorbisComment(block, @"REPLAYGAIN_TRACK_GAIN", (nil == numericValue ? nil : [NSString stringWithFormat:@"%+2.2f dB", [numericValue doubleValue]]));

	numericValue = [metadata valueForKey:ReplayGainTrackPeakKey];
	setVorbisComment(block, @"REPLAYGAIN_TRACK_PEAK", (nil == numericValue ? nil : [NSString stringWithFormat:@"%1.8f", [numericValue doubleValue]]));

	numericValue = [metadata valueForKey:ReplayGainAlbumGainKey];
	setVorbisComment(block, @"REPLAYGAIN_ALBUM_GAIN", (nil == numericValue ? nil : [NSString stringWithFormat:@"%+2.2f dB", [numericValue doubleValue]]));
	
	numericValue = [metadata valueForKey:ReplayGainAlbumPeakKey];
	setVorbisComment(block, @"REPLAYGAIN_ALBUM_PEAK", (nil == numericValue ? nil : [NSString stringWithFormat:@"%1.8f", [numericValue doubleValue]]));
	
	setVorbisComment(block, @"MUSICDNS_PUID", [metadata valueForKey:MetadataMusicDNSPUIDKey]);
	setVorbisComment(block, @"MUSICBRAINZ_ID", [metadata valueForKey:MetadataMusicBrainzIDKey]);

	// Write the new metadata to the file
	result = FLAC__metadata_chain_write(chain, YES, NO);
	if(NO == result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [_url path];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid FLAC file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Unable to write metadata", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
										 code:AudioMetadataWriterInputOutputError 										
									 userInfo:errorDictionary];
		}

		FLAC__metadata_chain_delete(chain);
		FLAC__metadata_iterator_delete(iterator);

		return NO;
	}

	FLAC__metadata_chain_delete(chain);
	FLAC__metadata_iterator_delete(iterator);

	return YES;
}

@end
