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
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid Musepack file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not a Musepack file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
														  code:AudioMetadataWriterFileFormatNotRecognizedError 
													  userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	// Album title
	NSString *album = [metadata valueForKey:@"albumTitle"];
	if(nil != album) {
		f.tag()->setAlbum(TagLib::String([album UTF8String], TagLib::String::UTF8));
	}
	
	// Artist
	NSString *artist = [metadata valueForKey:@"artist"];
	if(nil != artist) {
		f.tag()->setArtist(TagLib::String([artist UTF8String], TagLib::String::UTF8));
	}
		
	// Genre
	NSString *genre = [metadata valueForKey:@"genre"];
	if(nil != genre) {
		f.tag()->setGenre(TagLib::String([genre UTF8String], TagLib::String::UTF8));
	}
	
	// Date
	NSString *date = [metadata valueForKey:@"date"];
	if(nil != date) {
		f.tag()->setYear([date intValue]);
	}
	
	// Comment
	NSString *comment			= [metadata valueForKey:@"comment"];
	if(nil != comment) {
		f.tag()->setComment(TagLib::String([comment UTF8String], TagLib::String::UTF8));
	}
	
	// Track title
	NSString *title = [metadata valueForKey:@"title"];
	if(nil != title) {
		f.tag()->setTitle(TagLib::String([title UTF8String], TagLib::String::UTF8));
	}
	
	// Track number and total tracks
	NSNumber *trackNumber	= [metadata valueForKey:@"trackNumber"];
//	NSNumber *trackTotal		= [metadata valueForKey:@"trackTotal"];
	if(nil != trackNumber) {
		f.tag()->setTrack([trackNumber unsignedIntValue]);
	}
		
	result = f.save();
	if(NO == result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [_url path];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid Musepack file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not a Musepack file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
														  code:AudioMetadataWriterInputOutputError 
													  userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	return YES;
}

@end
