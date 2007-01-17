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

#import "FLACMetadataReader.h"
#include <FLAC/metadata.h>

@implementation FLACMetadataReader

- (BOOL) readMetadata:(NSError **)error
{
	NSString						*path				= [_url path];
	FLAC__Metadata_Chain			*chain				= NULL;
	FLAC__Metadata_Iterator			*iterator			= NULL;
	FLAC__StreamMetadata			*block				= NULL;
	unsigned						i;
	NSMutableDictionary				*metadataDictionary;
	NSString						*commentString, *key, *value;
	NSRange							range;
	NSImage							*picture;
				
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
			
			*error					= [NSError errorWithDomain:AudioMetadataReaderErrorDomain 
														  code:AudioMetadataReaderFileFormatNotRecognizedError 
													  userInfo:errorDictionary];
		}
		
		FLAC__metadata_chain_delete(chain);
		
		return NO;
	}
	
	iterator					= FLAC__metadata_iterator_new();
	
	NSAssert(NULL != iterator, @"Unable to allocate memory.");
	
	FLAC__metadata_iterator_init(iterator, chain);
	
	do {
		block					= FLAC__metadata_iterator_get_block(iterator);
		
		if(NULL == block) {
			break;
		}
		
		switch(block->type) {					
			case FLAC__METADATA_TYPE_VORBIS_COMMENT:				
				metadataDictionary			= [NSMutableDictionary dictionary];
				
				for(i = 0; i < block->data.vorbis_comment.num_comments; ++i) {
					
					/// Skip over empty comments
					if(NULL == block->data.vorbis_comment.comments[i].entry || 0 == block->data.vorbis_comment.comments[i].length) {
						continue;
					}

					// Split the comment at '='
					commentString	= [NSString stringWithUTF8String:(const char *)block->data.vorbis_comment.comments[i].entry];
					range			= [commentString rangeOfString:@"=" options:NSLiteralSearch];
					
					// Sanity check (comments should be well-formed)
					if(NSNotFound != range.location && 0 != range.length) {
						key				= [[commentString substringToIndex:range.location] uppercaseString];
						value			= [commentString substringFromIndex:range.location + 1];
						
						if(NSOrderedSame == [key caseInsensitiveCompare:@"ALBUM"]) {
							[metadataDictionary setValue:value forKey:@"albumTitle"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"ARTIST"]) {
							[metadataDictionary setValue:value forKey:@"artist"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"COMPOSER"]) {
							[metadataDictionary setValue:value forKey:@"composer"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"GENRE"]) {
							[metadataDictionary setValue:value forKey:@"genre"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"DATE"]) {
							[metadataDictionary setValue:value forKey:@"date"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"DESCRIPTION"]) {
							[metadataDictionary setValue:value forKey:@"comment"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"TITLE"]) {
							[metadataDictionary setValue:value forKey:@"title"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"TRACKNUMBER"]) {
							[metadataDictionary setValue:[NSNumber numberWithUnsignedInt:(UInt32)[value intValue]] forKey:@"trackNumber"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"TRACKTOTAL"]) {
							[metadataDictionary setValue:[NSNumber numberWithUnsignedInt:(UInt32)[value intValue]] forKey:@"trackTotal"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"COMPILATION"]) {
							[metadataDictionary setValue:[NSNumber numberWithBool:(BOOL)[value intValue]] forKey:@"partOfCompilation"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"DISCNUMBER"]) {
							[metadataDictionary setValue:[NSNumber numberWithUnsignedInt:(UInt32)[value intValue]] forKey:@"discNumber"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"DISCTOTAL"]) {
							[metadataDictionary setValue:[NSNumber numberWithUnsignedInt:(UInt32)[value intValue]] forKey:@"discTotal"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"ISRC"]) {
							[metadataDictionary setValue:value forKey:@"isrc"];;
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"MCN"]) {
							[metadataDictionary setValue:value forKey:@"mcn"];
						}
					}					
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
