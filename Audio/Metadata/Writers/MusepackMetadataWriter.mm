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

#import "MusepackMetadataWriter.h"
#import "AudioStream.h"
#include <taglib/mpcfile.h>
#include <taglib/tag.h>
#include <taglib/tstring.h>

@implementation MusepackMetadataWriter

- (BOOL) writeMetadata:(id)metadata error:(NSError **)error
{
	NSString						*path				= [_url path];
	TagLib::MPC::File				f					([path fileSystemRepresentation], false);
	bool							result;
	
	if(NO == f.isValid()) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Musepack file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a Musepack file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
										 code:AudioMetadataWriterFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	// Album title
	NSString *album = [metadata valueForKey:MetadataAlbumTitleKey];
	f.tag()->setAlbum(nil == album ? TagLib::String::null : TagLib::String([album UTF8String], TagLib::String::UTF8));
	
	// Artist
	NSString *artist = [metadata valueForKey:MetadataArtistKey];
	f.tag()->setArtist(nil == artist ? TagLib::String::null : TagLib::String([artist UTF8String], TagLib::String::UTF8));
		
	// Genre
	NSString *genre = [metadata valueForKey:MetadataGenreKey];
	f.tag()->setGenre(nil == genre ? TagLib::String::null : TagLib::String([genre UTF8String], TagLib::String::UTF8));
	
	// Date
	NSString *date = [metadata valueForKey:MetadataDateKey];
	f.tag()->setYear(nil == date ? 0 : [date intValue]);
	
	// Comment
	NSString *comment = [metadata valueForKey:MetadataCommentKey];
	f.tag()->setComment(nil == comment ? TagLib::String::null : TagLib::String([comment UTF8String], TagLib::String::UTF8));
	
	// Track title
	NSString *title = [metadata valueForKey:MetadataTitleKey];
	f.tag()->setTitle(nil == title ? TagLib::String::null : TagLib::String([title UTF8String], TagLib::String::UTF8));
	
	// Track number and total tracks
	NSNumber *trackNumber = [metadata valueForKey:MetadataTrackNumberKey];
//	NSNumber *trackTotal = [metadata valueForKey:MetadataTrackTotalKey];
	f.tag()->setTrack(nil == trackNumber ? 0 : [trackNumber intValue]);
		
	result = f.save();
	if(NO == result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [_url path];
						
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Musepack file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Unable to write metadata", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
										 code:AudioMetadataWriterFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	return YES;
}

@end
