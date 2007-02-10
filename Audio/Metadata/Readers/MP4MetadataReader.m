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

#import "MP4MetadataReader.h"
#import "AudioStream.h"
#include <mp4v2/mp4.h>

@implementation MP4MetadataReader

- (BOOL) readMetadata:(NSError **)error
{
	NSMutableDictionary				*metadataDictionary;
	NSString						*path					= [_url path];
	MP4FileHandle					mp4FileHandle			= MP4Read([path fileSystemRepresentation], 0);
	
	if(MP4_INVALID_FILE_HANDLE == mp4FileHandle) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid MP4 file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not an MP4 file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioMetadataReaderErrorDomain 
														  code:AudioMetadataReaderFileFormatNotRecognizedError 
													  userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	char			*s									= NULL;
	u_int16_t		trackNumber, totalTracks;
	u_int16_t		discNumber, discTotal;
	u_int8_t		compilation;
	u_int32_t		artCount;
	u_int8_t		*bytes								= NULL;
	u_int32_t		length								= 0;
	
	metadataDictionary			= [NSMutableDictionary dictionary];

	// Album title
	MP4GetMetadataAlbum(mp4FileHandle, &s);
	if(NULL != s) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:s] forKey:@"albumTitle"];
	}
	
	// Artist
	MP4GetMetadataArtist(mp4FileHandle, &s);
	if(NULL != s) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:s] forKey:@"artist"];
	}
	
	// Genre
	MP4GetMetadataGenre(mp4FileHandle, &s);
	if(NULL != s) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:s] forKey:@"genre"];
	}
	
	// Year
	MP4GetMetadataYear(mp4FileHandle, &s);
	if(NULL != s) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:s] forKey:@"date"];
	}
	
	// Composer
	MP4GetMetadataWriter(mp4FileHandle, &s);
	if(NULL != s) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:s] forKey:@"composer"];
	}
	
	// Comment
	MP4GetMetadataComment(mp4FileHandle, &s);
	if(NULL != s) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:s] forKey:@"comment"];
	}
	
	// Track title
	MP4GetMetadataName(mp4FileHandle, &s);
	if(NULL != s) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:s] forKey:@"title"];
	}
	
	// Track number
	MP4GetMetadataTrack(mp4FileHandle, &trackNumber, &totalTracks);
	if(0 != trackNumber) {
		[metadataDictionary setValue:[NSNumber numberWithInt:trackNumber] forKey:@"trackNumber"];
	}
	if(0 != totalTracks) {
		[metadataDictionary setValue:[NSNumber numberWithInt:totalTracks] forKey:@"trackTotal"];
	}
	
	// Disc number
	MP4GetMetadataDisk(mp4FileHandle, &discNumber, &discTotal);
	if(0 != discNumber) {
		[metadataDictionary setValue:[NSNumber numberWithInt:discNumber] forKey:@"discNumber"];
	}
	if(0 != discTotal) {
		[metadataDictionary setValue:[NSNumber numberWithInt:discTotal] forKey:@"discTotal"];
	}
	
	// Compilation
	MP4GetMetadataCompilation(mp4FileHandle, &compilation);
	if(compilation) {
		[metadataDictionary setValue:[NSNumber numberWithBool:YES] forKey:@"compilation"];
	}
	
	// Album art
	artCount = MP4GetMetadataCoverArtCount(mp4FileHandle);
	if(0 < artCount) {
		MP4GetMetadataCoverArt(mp4FileHandle, &bytes, &length, 0);
		NSImage				*image	= [[NSImage alloc] initWithData:[NSData dataWithBytes:bytes length:length]];
		if(nil != image) {
			[metadataDictionary setValue:[image TIFFRepresentation] forKey:@"albumArt"];
			[image release];
		}
	}
	
	MP4Close(mp4FileHandle);	
	
	[self setValue:metadataDictionary forKey:@"metadata"];
	
	return YES;
}

@end
