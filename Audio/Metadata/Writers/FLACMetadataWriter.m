/*
 *  $Id$
 *
 *  Copyright (C) 2006 Stephen F. Booth <me@sbooth.org>
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
#include <FLAC/metadata.h>

static void
setVorbisComment(FLAC__StreamMetadata		*block,
				 NSString					*key,
				 NSString					*value)
{
	NSString									*string;
	FLAC__StreamMetadata_VorbisComment_Entry	entry;
	
	string			= [NSString stringWithFormat:@"%@=%@", key, value];
	entry.entry		= (unsigned char *)strdup([string UTF8String]);
	NSCAssert(NULL != entry.entry, @"Unable to allocate memory.");
	
	entry.length	= strlen((const char *)entry.entry);
	
	if(NO == FLAC__metadata_object_vorbiscomment_replace_comment(block, entry, NO, NO)) {
		free(entry.entry);
		@throw [NSException exceptionWithName:@"FLACException"
									   reason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"FLAC__metadata_object_vorbiscomment_replace_comment"]
									 userInfo:nil];
	}	
}

@implementation FLACMetadataWriter

- (BOOL) writeMetadata:(id)metadata error:(NSError **)error
{
	NSString						*path				= [_url path];
	FLAC__Metadata_Chain			*chain				= NULL;
	FLAC__Metadata_Iterator			*iterator			= NULL;
	FLAC__StreamMetadata			*block				= NULL;
	FLAC__bool						result;
				
	chain							= FLAC__metadata_chain_new();
	NSAssert(NULL != chain, @"Unable to allocate memory.");
	
	if(NO == FLAC__metadata_chain_read(chain, [path fileSystemRepresentation])) {
		
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			
			switch(FLAC__metadata_chain_status(chain)) {
				case FLAC__METADATA_CHAIN_STATUS_NOT_A_FLAC_FILE:
					[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid FLAC file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
					[errorDictionary setObject:@"Not a FLAC file" forKey:NSLocalizedFailureReasonErrorKey];
					[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
					break;
									
				case FLAC__METADATA_CHAIN_STATUS_BAD_METADATA:
					[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid FLAC file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
					[errorDictionary setObject:@"Not a FLAC file" forKey:NSLocalizedFailureReasonErrorKey];
					[errorDictionary setObject:@"The file contains bad metadata." forKey:NSLocalizedRecoverySuggestionErrorKey];						
					break;
										
				default:
					[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid FLAC file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
					[errorDictionary setObject:@"Not a FLAC file" forKey:NSLocalizedFailureReasonErrorKey];
					[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
					break;
			}
			
			*error					= [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
														  code:AudioMetadataWriterFileFormatNotRecognizedError 
													  userInfo:errorDictionary];
		}
		
		FLAC__metadata_chain_delete(chain);
		
		return NO;
	}
	
	FLAC__metadata_chain_sort_padding(chain);

	iterator					= FLAC__metadata_iterator_new();
	NSAssert(NULL != iterator, @"Unable to allocate memory.");
	
	FLAC__metadata_iterator_init(iterator, chain);
	
	// Seek to the vorbis comment block if it exists
	while(FLAC__METADATA_TYPE_VORBIS_COMMENT != FLAC__metadata_iterator_get_block_type(iterator)) {
		if(NO == FLAC__metadata_iterator_next(iterator)) {
			break; // Already at end
		}
	}
	
	// If there isn't a vorbis comment block add one
	if(FLAC__METADATA_TYPE_VORBIS_COMMENT != FLAC__metadata_iterator_get_block_type(iterator)) {
		
		// The padding block will be the last block if it exists; add the comment block before it
		if(FLAC__METADATA_TYPE_PADDING == FLAC__metadata_iterator_get_block_type(iterator)) {
			FLAC__metadata_iterator_prev(iterator);
		}
		
		block					= FLAC__metadata_object_new(FLAC__METADATA_TYPE_VORBIS_COMMENT);
		NSAssert(NULL != block, @"Unable to allocate memory.");
		
		// Add our metadata
		result					= FLAC__metadata_iterator_insert_block_after(iterator, block);
		if(NO == result) {
			if(nil != error) {
				NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
				NSString				*path				= [_url path];
				
				[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid FLAC file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
				[errorDictionary setObject:@"Unable to write metadata" forKey:NSLocalizedFailureReasonErrorKey];
				[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
				
				*error					= [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
															  code:AudioMetadataWriterInputOutputError 
														  userInfo:errorDictionary];
			}
			
			FLAC__metadata_chain_delete(chain);
			FLAC__metadata_iterator_delete(iterator);

			return NO;
		}
	}
	else {
		block = FLAC__metadata_iterator_get_block(iterator);
	}
	
	// Album title
	NSString *album = [metadata valueForKey:@"albumTitle"];
	if(nil != album) {
		setVorbisComment(block, @"ALBUM", album);
	}
	
	// Artist
	NSString *artist = [metadata valueForKey:@"artist"];
	if(nil != artist) {
		setVorbisComment(block, @"ARTIST", artist);
	}
	
	// Composer
	NSString *composer = [metadata valueForKey:@"composer"];
	if(nil != composer) {
		setVorbisComment(block, @"COMPOSER", composer);
	}
	
	// Genre
	NSString *genre = [metadata valueForKey:@"genre"];
	if(nil != genre) {
		setVorbisComment(block, @"GENRE", genre);
	}
	
	// Date
	NSString *date = [metadata valueForKey:@"date"];
	if(nil != date) {
		setVorbisComment(block, @"DATE", date);
	}
	
	// Comment
	NSString *comment			= [metadata valueForKey:@"comment"];
	if(nil != comment) {
		setVorbisComment(block, @"DESCRIPTION", comment);
	}
	
	// Track title
	NSString *title = [metadata valueForKey:@"title"];
	if(nil != title) {
		setVorbisComment(block, @"TITLE", title);
	}
	
	// Track number
	NSNumber *trackNumber = [metadata valueForKey:@"trackNumber"];
	if(nil != trackNumber) {
		setVorbisComment(block, @"TRACKNUMBER", [trackNumber stringValue]);
	}
	
	// Total tracks
	NSNumber *trackTotal = [metadata valueForKey:@"trackTotal"];
	if(nil != trackTotal) {
		setVorbisComment(block, @"TRACKTOTAL", [trackTotal stringValue]);
	}
	
	// Compilation
	NSNumber *compilation = [metadata valueForKey:@"partOfCompilation"];
	if(nil != compilation) {
		setVorbisComment(block, @"COMPILATION", [compilation stringValue]);
	}
	
	// Disc number
	NSNumber *discNumber = [metadata valueForKey:@"discNumber"];
	if(nil != discNumber) {
		setVorbisComment(block, @"DISCNUMBER", [discNumber stringValue]);
	}
	
	// Discs in set
	NSNumber *discTotal = [metadata valueForKey:@"discTotal"];
	if(nil != discTotal) {
		setVorbisComment(block, @"DISCTOTAL", [discTotal stringValue]);
	}
	
	// ISRC
	NSString *isrc = [metadata valueForKey:@"isrc"];
	if(nil != isrc) {
		setVorbisComment(block, @"ISRC", isrc);
	}
	
	// MCN
	NSString *mcn = [metadata valueForKey:@"mcn"];
	if(nil != mcn) {
		setVorbisComment(block, @"MCN", mcn);
	}
		
	// Write the new metadata to the file
	result = FLAC__metadata_chain_write(chain, YES, NO);
	if(NO == result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [_url path];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid FLAC file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Unable to write metadata" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
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
