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
	NSString						*path				= [_url path];
	FLAC__Metadata_Chain			*chain				= NULL;
	FLAC__Metadata_Iterator			*iterator			= NULL;
	FLAC__StreamMetadata			*block				= NULL;
	NSMutableDictionary				*propertiesDictionary;
				
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
	
	do {
		block = FLAC__metadata_iterator_get_block(iterator);
		
		if(NULL == block) {
			break;
		}
		
		switch(block->type) {					
			case FLAC__METADATA_TYPE_STREAMINFO:
				propertiesDictionary = [NSMutableDictionary dictionary];
				
				[propertiesDictionary setValue:NSLocalizedStringFromTable(@"FLAC", @"Formats", @"") forKey:PropertiesFileTypeKey];
				[propertiesDictionary setValue:NSLocalizedStringFromTable(@"FLAC", @"Formats", @"") forKey:PropertiesFormatTypeKey];
				[propertiesDictionary setValue:[NSNumber numberWithLongLong:block->data.stream_info.total_samples] forKey:PropertiesTotalFramesKey];
				[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:block->data.stream_info.bits_per_sample] forKey:PropertiesBitsPerChannelKey];
				[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:block->data.stream_info.channels] forKey:PropertiesChannelsPerFrameKey];
				[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:block->data.stream_info.sample_rate] forKey:PropertiesSampleRateKey];				
				[propertiesDictionary setValue:[NSNumber numberWithDouble:(double)block->data.stream_info.total_samples / block->data.stream_info.sample_rate] forKey:PropertiesDurationKey];
				
				[self setValue:propertiesDictionary forKey:@"properties"];
				break;
				
			case FLAC__METADATA_TYPE_VORBIS_COMMENT:				break;
			case FLAC__METADATA_TYPE_PICTURE:						break;
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
	
	return YES;
}

@end
