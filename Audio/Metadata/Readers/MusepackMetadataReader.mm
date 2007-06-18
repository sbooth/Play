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

#import "MusepackMetadataReader.h"
#import "AudioStream.h"
#include <taglib/mpcfile.h>
#include <taglib/tstring.h>
#include <taglib/tag.h>

@implementation MusepackMetadataReader

- (BOOL) readMetadata:(NSError **)error
{
	NSMutableDictionary				*metadataDictionary;
	NSString						*path					= [_url path];
	TagLib::MPC::File				f						([path fileSystemRepresentation], false);
	TagLib::String					s;
	TagLib::ID3v1::Tag				*id3v1Tag;
	TagLib::APE::Tag				*apeTag;
		
	if(NO == f.isValid()) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Musepack file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a Musepack file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataReaderErrorDomain 
										 code:AudioMetadataReaderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	metadataDictionary			= [NSMutableDictionary dictionary];
	
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
			
	id3v1Tag = f.ID3v1Tag();
	if(NULL != id3v1Tag) {
		
	}
	
	apeTag = f.APETag();
	if(NULL != apeTag) {
		
	}

	[self setValue:metadataDictionary forKey:@"metadata"];
		
	return YES;
}

@end
