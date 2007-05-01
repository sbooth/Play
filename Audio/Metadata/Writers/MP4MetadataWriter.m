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
#import "AudioStream.h"
#import "UtilityFunctions.h"
#include <mp4v2/mp4.h>

@implementation MP4MetadataWriter

- (BOOL) writeMetadata:(id)metadata error:(NSError **)error
{
	NSString		*path			= [_url path];
	MP4FileHandle	mp4FileHandle	= MP4Modify([path fileSystemRepresentation], 0, 0);
	BOOL			result			= NO;

	if(MP4_INVALID_FILE_HANDLE == mp4FileHandle) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid MPEG file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not an MPEG file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
										 code:AudioMetadataWriterFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	// Album title
	NSString *album = [metadata valueForKey:MetadataAlbumTitleKey];
	result = MP4SetMetadataAlbum(mp4FileHandle, (nil == album ? "" : [album UTF8String]));
	
	// Artist
	NSString *artist = [metadata valueForKey:MetadataArtistKey];
	result = MP4SetMetadataArtist(mp4FileHandle, (nil == artist ? "" : [artist UTF8String]));

	// Album Artist
	NSString *albumArtist = [metadata valueForKey:MetadataAlbumArtistKey];
	result = MP4SetMetadataAlbumArtist(mp4FileHandle, (nil == albumArtist ? "" : [albumArtist UTF8String]));
	
	// BPM
	NSNumber *bpm = [metadata valueForKey:MetadataBPMKey];
	result = MP4SetMetadataTempo(mp4FileHandle, (nil == bpm ? 0 : [bpm unsignedShortValue]));
	
	// Composer
	NSString *composer = [metadata valueForKey:MetadataComposerKey];
	result = MP4SetMetadataWriter(mp4FileHandle, (nil == composer ? "" : [composer UTF8String]));
	
	// Genre
	NSString *genre = [metadata valueForKey:MetadataGenreKey];
	result = MP4SetMetadataGenre(mp4FileHandle, (nil == genre ? "" : [genre UTF8String]));
	
	// Year
	NSString *date = [metadata valueForKey:MetadataDateKey];
	result = MP4SetMetadataYear(mp4FileHandle, (nil == date ? "" : [date UTF8String]));
	
	// Comment
	NSString *comment = [metadata valueForKey:MetadataCommentKey];
	result = MP4SetMetadataComment(mp4FileHandle, (nil == comment ? "" : [comment UTF8String]));
	
	// Track title
	NSString *title = [metadata valueForKey:MetadataTitleKey];
	result = MP4SetMetadataName(mp4FileHandle, (nil == title ? "" : [title UTF8String]));
	
	// Track number
	NSNumber *trackNumber	= [metadata valueForKey:MetadataTrackNumberKey];
	NSNumber *trackTotal	= [metadata valueForKey:MetadataTrackTotalKey];
	result = MP4SetMetadataTrack(mp4FileHandle,
								 (nil == trackNumber ? 0 : [trackNumber unsignedIntValue]),
								 (nil == trackTotal ? 0 : [trackTotal unsignedIntValue]));
	
	// Disc number
	NSNumber *discNumber	= [metadata valueForKey:MetadataDiscNumberKey];
	NSNumber *discTotal		= [metadata valueForKey:MetadataDiscTotalKey];
	result = MP4SetMetadataDisk(mp4FileHandle,
								(nil == discNumber ? 0 : [discNumber unsignedIntValue]),
								(nil == discTotal ? 0 : [discTotal unsignedIntValue]));
	
	// Compilation
	NSNumber *compilation = [metadata valueForKey:MetadataCompilationKey];
	result = MP4SetMetadataCompilation(mp4FileHandle, (nil == compilation ? NO : [compilation boolValue]));
	
	// Album art
/*	NSImage *albumArt = [metadata valueForKey:@"albumArt"];
	if(nil != albumArt) {
		NSData *data = getPNGDataForImage(albumArt); 
		MP4SetMetadataCoverArt(mp4FileHandle, (u_int8_t *)[data bytes], [data length]);
	}*/
		
	result = MP4Close(mp4FileHandle);
	if(NO == result) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid MPEG file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
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
