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

#import "OggFLACMetadataWriter.h"

#include <taglib/oggflacfile.h>
#include <taglib/tag.h>

@implementation OggFLACMetadataWriter

- (BOOL) writeMetadata:(id)metadata error:(NSError **)error
{
	NSString						*path				= [_url path];
	TagLib::Ogg::FLAC::File			f					([path fileSystemRepresentation], false);
	bool							result;
	
	if(NO == f.isValid()) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid Ogg (FLAC) file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not an Ogg (FLAC) file" forKey:NSLocalizedFailureReasonErrorKey];
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
		f.tag()->addField("ALBUM", TagLib::String([album UTF8String], TagLib::String::UTF8));
	}
	
	// Artist
	NSString *artist = [metadata valueForKey:@"artist"];
	if(nil != artist) {
		f.tag()->addField("ARTIST", TagLib::String([artist UTF8String], TagLib::String::UTF8));
	}
	
	// Composer
	NSString *composer = [metadata valueForKey:@"composer"];
	if(nil != composer) {
		f.tag()->addField("COMPOSER", TagLib::String([composer UTF8String], TagLib::String::UTF8));
	}
	
	// Genre
	NSString *genre = [metadata valueForKey:@"genre"];
	if(nil != genre) {
		f.tag()->addField("GENRE", TagLib::String([genre UTF8String], TagLib::String::UTF8));
	}
	
	// Date
	NSString *date = [metadata valueForKey:@"date"];
	if(nil != date) {
		f.tag()->addField("DATE", TagLib::String([date UTF8String], TagLib::String::UTF8));
	}
	
	// Comment
	NSString *comment			= [metadata valueForKey:@"comment"];
	if(nil != comment) {
		f.tag()->addField("DESCRIPTION", TagLib::String([comment UTF8String], TagLib::String::UTF8));
	}
	
	// Track title
	NSString *title = [metadata valueForKey:@"title"];
	if(nil != title) {
		f.tag()->addField("TITLE", TagLib::String([title UTF8String], TagLib::String::UTF8));
	}
	
	// Track number
	NSNumber *trackNumber = [metadata valueForKey:@"trackNumber"];
	if(nil != trackNumber) {
		f.tag()->addField("TRACKNUMBER", TagLib::String([[trackNumber stringValue] UTF8String], TagLib::String::UTF8));
	}
	
	// Total tracks
	NSNumber *trackTotal = [metadata valueForKey:@"trackTotal"];
	if(nil != trackTotal) {
		f.tag()->addField("TRACKTOTAL", TagLib::String([[trackTotal stringValue] UTF8String], TagLib::String::UTF8));
	}
	
	// Compilation
	NSNumber *compilation = [metadata valueForKey:@"partOfCompilation"];
	if(nil != compilation) {
		f.tag()->addField("COMPILATION", TagLib::String([[compilation stringValue] UTF8String], TagLib::String::UTF8));
	}
	
	// Disc number
	NSNumber *discNumber = [metadata valueForKey:@"discNumber"];
	if(nil != discNumber) {
		f.tag()->addField("DISCNUMBER", TagLib::String([[discNumber stringValue] UTF8String], TagLib::String::UTF8));
	}
	
	// Discs in set
	NSNumber *discTotal = [metadata valueForKey:@"discTotal"];
	if(nil != discTotal) {
		f.tag()->addField("DISCTOTAL", TagLib::String([[discTotal stringValue] UTF8String], TagLib::String::UTF8));
	}
	
	// ISRC
	NSString *isrc = [metadata valueForKey:@"isrc"];
	if(nil != isrc) {
		f.tag()->addField("ISRC", TagLib::String([isrc UTF8String], TagLib::String::UTF8));
	}
	
	// MCN
	NSString *mcn = [metadata valueForKey:@"mcn"];
	if(nil != mcn) {
		f.tag()->addField("MCN", TagLib::String([mcn UTF8String], TagLib::String::UTF8));
	}
	
	result = f.save();
	if(NO == result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [_url path];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid Ogg (FLAC) file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not an Ogg (FLAC) file" forKey:NSLocalizedFailureReasonErrorKey];
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
