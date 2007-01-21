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

#import "MP4MetadataWriter.h"
#import "UtilityFunctions.h"
#include <mp4v2/mp4.h>

@implementation MP4MetadataWriter

- (BOOL) writeMetadata:(id)metadata error:(NSError **)error
{
	NSString						*path					= [_url path];
	MP4FileHandle					mp4FileHandle			= MP4Modify([path fileSystemRepresentation], 0, 0);
	BOOL							result;

	if(MP4_INVALID_FILE_HANDLE == mp4FileHandle) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid MP4 file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not an MP4 file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
														  code:AudioMetadataWriterInputOutputError 
													  userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	// Album title
	NSString *album = [metadata valueForKey:@"albumTitle"];
	if(nil != album) {
		MP4SetMetadataAlbum(mp4FileHandle, [album UTF8String]);
	}
	
	// Artist
	NSString *artist = [metadata valueForKey:@"artist"];
	if(nil != artist) {
		MP4SetMetadataArtist(mp4FileHandle, [artist UTF8String]);
	}
	
	// Composer
	NSString *composer = [metadata valueForKey:@"composer"];
	if(nil != composer) {
		MP4SetMetadataWriter(mp4FileHandle, [composer UTF8String]);
	}
	
	// Genre
	NSString *genre = [metadata valueForKey:@"genre"];
	if(nil != genre) {
		MP4SetMetadataGenre(mp4FileHandle, [genre UTF8String]);
	}
	
	// Year
	NSString *date = [metadata valueForKey:@"date"];
	if(nil != date) {
		MP4SetMetadataYear(mp4FileHandle, [date UTF8String]);
	}
	
	// Comment
	NSString *comment = [metadata valueForKey:@"comment"];
	if(nil != comment) {
		MP4SetMetadataComment(mp4FileHandle, [comment UTF8String]);
	}
	
	// Track title
	NSString *title = [metadata valueForKey:@"title"];
	if(nil != title) {
		MP4SetMetadataName(mp4FileHandle, [title UTF8String]);
	}
	
	// Track number
	NSNumber *trackNumber	= [metadata valueForKey:@"trackNumber"];
	NSNumber *trackTotal	= [metadata valueForKey:@"trackTotal"];
	if(nil != trackNumber && nil != trackTotal) {
		MP4SetMetadataTrack(mp4FileHandle, [trackNumber unsignedIntValue], [trackTotal unsignedIntValue]);
	}
	else if(nil != trackNumber) {
		MP4SetMetadataTrack(mp4FileHandle, [trackNumber unsignedIntValue], 0);
	}
	else if(nil != trackTotal) {
		MP4SetMetadataTrack(mp4FileHandle, 0, [trackTotal unsignedIntValue]);
	}
	
	// Disc number
	NSNumber *discNumber	= [metadata valueForKey:@"discNumber"];
	NSNumber *discTotal		= [metadata valueForKey:@"discTotal"];
	if(nil != discNumber && nil != discTotal) {
		MP4SetMetadataDisk(mp4FileHandle, [discNumber unsignedIntValue], [discTotal unsignedIntValue]);
	}
	else if(nil != discNumber) {
		MP4SetMetadataDisk(mp4FileHandle, [discNumber unsignedIntValue], 0);
	}
	else if(nil != discTotal) {
		MP4SetMetadataDisk(mp4FileHandle, 0, [discTotal unsignedIntValue]);
	}
	
	// Compilation
	NSNumber *compilation = [metadata valueForKey:@"partOfCompilation"];
	if(nil != compilation) {
		MP4SetMetadataCompilation(mp4FileHandle, [compilation boolValue]);
	}
	
	// Album art
	NSImage *albumArt = [metadata valueForKey:@"albumArt"];
	if(nil != albumArt) {
		NSData *data = getPNGDataForImage(albumArt); 
		MP4SetMetadataCoverArt(mp4FileHandle, (u_int8_t *)[data bytes], [data length]);
	}
		
	result = MP4Close(mp4FileHandle);
	if(NO == result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid MP4 file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not an MP4 file" forKey:NSLocalizedFailureReasonErrorKey];
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
