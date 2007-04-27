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

#import "OggVorbisMetadataWriter.h"
#import "AudioStream.h"

#include <taglib/vorbisfile.h>
#include <taglib/tag.h>

@implementation OggVorbisMetadataWriter

- (BOOL) writeMetadata:(id)metadata error:(NSError **)error
{
	NSString						*path				= [_url path];
	TagLib::Ogg::Vorbis::File		f					([path fileSystemRepresentation], false);
	bool							result;
	
	if(NO == f.isValid()) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Ogg Vorbis file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not an Ogg Vorbis file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
										 code:AudioMetadataWriterFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
		
	// Album title
	NSString *album = [metadata valueForKey:MetadataAlbumTitleKey];
	if(nil != album) {
		f.tag()->addField("ALBUM", TagLib::String([album UTF8String], TagLib::String::UTF8));
	}
	
	// Artist
	NSString *artist = [metadata valueForKey:MetadataArtistKey];
	if(nil != artist) {
		f.tag()->addField("ARTIST", TagLib::String([artist UTF8String], TagLib::String::UTF8));
	}
	
	// Composer
	NSString *composer = [metadata valueForKey:MetadataComposerKey];
	if(nil != composer) {
		f.tag()->addField("COMPOSER", TagLib::String([composer UTF8String], TagLib::String::UTF8));
	}
	
	// Genre
	NSString *genre = [metadata valueForKey:MetadataGenreKey];
	if(nil != genre) {
		f.tag()->addField("GENRE", TagLib::String([genre UTF8String], TagLib::String::UTF8));
	}
	
	// Date
	NSString *date = [metadata valueForKey:MetadataDateKey];
	if(nil != date) {
		f.tag()->addField("DATE", TagLib::String([date UTF8String], TagLib::String::UTF8));
	}
	
	// Comment
	NSString *comment			= [metadata valueForKey:MetadataCommentKey];
	if(nil != comment) {
		f.tag()->addField("DESCRIPTION", TagLib::String([comment UTF8String], TagLib::String::UTF8));
	}
	
	// Track title
	NSString *title = [metadata valueForKey:MetadataTitleKey];
	if(nil != title) {
		f.tag()->addField("TITLE", TagLib::String([title UTF8String], TagLib::String::UTF8));
	}
	
	// Track number
	NSNumber *trackNumber = [metadata valueForKey:MetadataTrackNumberKey];
	if(nil != trackNumber) {
		f.tag()->addField("TRACKNUMBER", TagLib::String([[trackNumber stringValue] UTF8String], TagLib::String::UTF8));
	}
	
	// Total tracks
	NSNumber *trackTotal = [metadata valueForKey:MetadataTrackTotalKey];
	if(nil != trackTotal) {
		f.tag()->addField("TRACKTOTAL", TagLib::String([[trackTotal stringValue] UTF8String], TagLib::String::UTF8));
	}
	
	// Compilation
	NSNumber *compilation = [metadata valueForKey:MetadataCompilationKey];
	if(nil != compilation) {
		f.tag()->addField("COMPILATION", TagLib::String([[compilation stringValue] UTF8String], TagLib::String::UTF8));
	}
	
	// Disc number
	NSNumber *discNumber = [metadata valueForKey:MetadataDiscNumberKey];
	if(nil != discNumber) {
		f.tag()->addField("DISCNUMBER", TagLib::String([[discNumber stringValue] UTF8String], TagLib::String::UTF8));
	}
	
	// Discs in set
	NSNumber *discTotal = [metadata valueForKey:MetadataDiscTotalKey];
	if(nil != discTotal) {
		f.tag()->addField("DISCTOTAL", TagLib::String([[discTotal stringValue] UTF8String], TagLib::String::UTF8));
	}
	
	// ISRC
	NSString *isrc = [metadata valueForKey:MetadataISRCKey];
	if(nil != isrc) {
		f.tag()->addField("ISRC", TagLib::String([isrc UTF8String], TagLib::String::UTF8));
	}
	
	// MCN
	NSString *mcn = [metadata valueForKey:MetadataMCNKey];
	if(nil != mcn) {
		f.tag()->addField("MCN", TagLib::String([mcn UTF8String], TagLib::String::UTF8));
	}
	
	result = f.save();
	if(NO == result) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Ogg Vorbis file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
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
