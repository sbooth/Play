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
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid MPEG file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not an MPEG file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataReaderErrorDomain 
										 code:AudioMetadataReaderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	char			*s									= NULL;
	u_int16_t		trackNumber, totalTracks;
	u_int16_t		bpm, discNumber, discTotal;
	u_int8_t		compilation;
	
	metadataDictionary = [NSMutableDictionary dictionary];

	// Album title
	if(MP4GetMetadataAlbum(mp4FileHandle, &s))
		[metadataDictionary setValue:[NSString stringWithUTF8String:s] forKey:MetadataAlbumTitleKey];
	
	// Artist
	if(MP4GetMetadataArtist(mp4FileHandle, &s))
		[metadataDictionary setValue:[NSString stringWithUTF8String:s] forKey:MetadataArtistKey];

	// Album Artist
	if(MP4GetMetadataAlbumArtist(mp4FileHandle, &s))
		[metadataDictionary setValue:[NSString stringWithUTF8String:s] forKey:MetadataAlbumArtistKey];
	
	// Genre
	if(MP4GetMetadataGenre(mp4FileHandle, &s))
		[metadataDictionary setValue:[NSString stringWithUTF8String:s] forKey:MetadataGenreKey];
	
	// Year
	if(MP4GetMetadataYear(mp4FileHandle, &s))
		[metadataDictionary setValue:[NSString stringWithUTF8String:s] forKey:MetadataDateKey];
	
	// Composer
	if(MP4GetMetadataWriter(mp4FileHandle, &s))
		[metadataDictionary setValue:[NSString stringWithUTF8String:s] forKey:MetadataComposerKey];
	
	// Comment
	if(MP4GetMetadataComment(mp4FileHandle, &s))
		[metadataDictionary setValue:[NSString stringWithUTF8String:s] forKey:MetadataCommentKey];
	
	// Track title
	if(MP4GetMetadataName(mp4FileHandle, &s))
		[metadataDictionary setValue:[NSString stringWithUTF8String:s] forKey:MetadataTitleKey];
	
	// Track number
	if(MP4GetMetadataTrack(mp4FileHandle, &trackNumber, &totalTracks)) {
		if(0 != trackNumber)
			[metadataDictionary setValue:[NSNumber numberWithInt:trackNumber] forKey:MetadataTrackNumberKey];
		
		if(0 != totalTracks)
			[metadataDictionary setValue:[NSNumber numberWithInt:totalTracks] forKey:MetadataTrackTotalKey];
	}
	
	// Disc number
	if(MP4GetMetadataDisk(mp4FileHandle, &discNumber, &discTotal)) {
		if(0 != discNumber)
			[metadataDictionary setValue:[NSNumber numberWithInt:discNumber] forKey:MetadataDiscNumberKey];

		if(0 != discTotal)
			[metadataDictionary setValue:[NSNumber numberWithInt:discTotal] forKey:MetadataDiscTotalKey];
	}
	
	// Compilation
	if(MP4GetMetadataCompilation(mp4FileHandle, &compilation))
		[metadataDictionary setValue:[NSNumber numberWithBool:YES] forKey:MetadataCompilationKey];

	// BPM
	if(MP4GetMetadataTempo(mp4FileHandle, &bpm))
		[metadataDictionary setValue:[NSNumber numberWithInt:bpm] forKey:MetadataBPMKey];
	
	// Album art
/*	artCount = MP4GetMetadataCoverArtCount(mp4FileHandle);
	if(0 < artCount) {
		MP4GetMetadataCoverArt(mp4FileHandle, &bytes, &length, 0);
		NSImage				*image	= [[NSImage alloc] initWithData:[NSData dataWithBytes:bytes length:length]];
		if(nil != image) {
			[metadataDictionary setValue:[image TIFFRepresentation] forKey:@"albumArt"];
			[image release];
		}
	}*/
	
	// ReplayGain
	u_int8_t *rawValue;
	u_int32_t rawValueSize;

	if(MP4GetMetadataFreeForm(mp4FileHandle, "replaygain_reference_loudness", &rawValue, &rawValueSize, NULL)) {
		NSString	*value			= [[NSString alloc] initWithBytes:rawValue length:rawValueSize encoding:NSUTF8StringEncoding];
		NSScanner	*scanner		= [NSScanner scannerWithString:value];
		double		doubleValue		= 0.0;
		
		if([scanner scanDouble:&doubleValue])
			[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainReferenceLoudnessKey];
		
		[value release];
	}
	
	if(MP4GetMetadataFreeForm(mp4FileHandle, "replaygain_track_gain", &rawValue, &rawValueSize, NULL)) {
		NSString	*value			= [[NSString alloc] initWithBytes:rawValue length:rawValueSize encoding:NSUTF8StringEncoding];
		NSScanner	*scanner		= [NSScanner scannerWithString:value];
		double		doubleValue		= 0.0;
		
		if([scanner scanDouble:&doubleValue])
			[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainTrackGainKey];
		
		[value release];
	}

	if(MP4GetMetadataFreeForm(mp4FileHandle, "replaygain_track_peak", &rawValue, &rawValueSize, NULL)) {
		NSString *value = [[NSString alloc] initWithBytes:rawValue length:rawValueSize encoding:NSUTF8StringEncoding];
		[metadataDictionary setValue:[NSNumber numberWithDouble:[value doubleValue]] forKey:ReplayGainTrackPeakKey];
		[value release];
	}

	if(MP4GetMetadataFreeForm(mp4FileHandle, "replaygain_album_gain", &rawValue, &rawValueSize, NULL)) {
		NSString	*value			= [[NSString alloc] initWithBytes:rawValue length:rawValueSize encoding:NSUTF8StringEncoding];
		NSScanner	*scanner		= [NSScanner scannerWithString:value];
		double		doubleValue		= 0.0;
		
		if([scanner scanDouble:&doubleValue])
			[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainAlbumGainKey];
		
		[value release];
	}
	
	if(MP4GetMetadataFreeForm(mp4FileHandle, "replaygain_album_peak", &rawValue, &rawValueSize, NULL)) {
		NSString *value = [[NSString alloc] initWithBytes:rawValue length:rawValueSize encoding:NSUTF8StringEncoding];
		[metadataDictionary setValue:[NSNumber numberWithDouble:[value doubleValue]] forKey:ReplayGainAlbumPeakKey];
		[value release];
	}
	
	MP4Close(mp4FileHandle);	
	
	[self setValue:metadataDictionary forKey:@"metadata"];
	
	return YES;
}

@end
