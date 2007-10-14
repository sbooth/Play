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
	if(nil == album)
		result = MP4DeleteMetadataAlbum(mp4FileHandle);
	else
		result = MP4SetMetadataAlbum(mp4FileHandle, [album UTF8String]);
	
	// Artist
	NSString *artist = [metadata valueForKey:MetadataArtistKey];
	if(nil == artist)
		result = MP4DeleteMetadataArtist(mp4FileHandle);
	else
		result = MP4SetMetadataArtist(mp4FileHandle, [artist UTF8String]);

	// Album Artist
	NSString *albumArtist = [metadata valueForKey:MetadataAlbumArtistKey];
	if(nil == albumArtist)
		result = MP4DeleteMetadataAlbumArtist(mp4FileHandle);
	else	
		result = MP4SetMetadataAlbumArtist(mp4FileHandle, [albumArtist UTF8String]);
	
	// Composer
	NSString *composer = [metadata valueForKey:MetadataComposerKey];
	if(nil == composer)
		result = MP4DeleteMetadataWriter(mp4FileHandle);
	else	
		result = MP4SetMetadataWriter(mp4FileHandle, [composer UTF8String]);
	
	// Genre
	NSString *genre = [metadata valueForKey:MetadataGenreKey];
	if(nil == genre)
		result = MP4DeleteMetadataGenre(mp4FileHandle);
	else	
		result = MP4SetMetadataGenre(mp4FileHandle, [genre UTF8String]);
	
	// Year
	NSString *date = [metadata valueForKey:MetadataDateKey];
	if(nil == date)
		result = MP4DeleteMetadataYear(mp4FileHandle);
	else	
		result = MP4SetMetadataYear(mp4FileHandle, [date UTF8String]);
	
	// Comment
	NSString *comment = [metadata valueForKey:MetadataCommentKey];
	if(nil == comment)
		result = MP4DeleteMetadataComment(mp4FileHandle);
	else	
		result = MP4SetMetadataComment(mp4FileHandle, [comment UTF8String]);
	
	// Track title
	NSString *title = [metadata valueForKey:MetadataTitleKey];
	if(nil == title)
		result = MP4DeleteMetadataName(mp4FileHandle);
	else	
		result = MP4SetMetadataName(mp4FileHandle, [title UTF8String]);
	
	// Track number
	NSNumber *trackNumber	= [metadata valueForKey:MetadataTrackNumberKey];
	NSNumber *trackTotal	= [metadata valueForKey:MetadataTrackTotalKey];
	if(nil == trackNumber && nil == trackTotal)
		result = MP4DeleteMetadataTrack(mp4FileHandle);
	else
		result = MP4SetMetadataTrack(mp4FileHandle,
									 (nil == trackNumber ? 0 : [trackNumber unsignedIntValue]),
									 (nil == trackTotal ? 0 : [trackTotal unsignedIntValue]));
	
	// Compilation
	NSNumber *compilation = [metadata valueForKey:MetadataCompilationKey];
	if(nil == compilation)
		result = MP4DeleteMetadataCompilation(mp4FileHandle);
	else	
		result = MP4SetMetadataCompilation(mp4FileHandle, [compilation boolValue]);
	
	// Disc number
	NSNumber *discNumber	= [metadata valueForKey:MetadataDiscNumberKey];
	NSNumber *discTotal		= [metadata valueForKey:MetadataDiscTotalKey];
	if(nil == discNumber && nil == discTotal)
		result = MP4DeleteMetadataDisk(mp4FileHandle);
	else	
		result = MP4SetMetadataDisk(mp4FileHandle,
									(nil == discNumber ? 0 : [discNumber unsignedIntValue]),
									(nil == discTotal ? 0 : [discTotal unsignedIntValue]));
	
	// BPM
	NSNumber *bpm = [metadata valueForKey:MetadataBPMKey];
	if(nil == bpm)
		result = MP4DeleteMetadataTempo(mp4FileHandle);
	else	
		result = MP4SetMetadataTempo(mp4FileHandle, [bpm unsignedShortValue]);
	
	// Album art
/*	NSImage *albumArt = [metadata valueForKey:@"albumArt"];
	if(nil != albumArt) {
		NSData *data = getPNGDataForImage(albumArt); 
		MP4SetMetadataCoverArt(mp4FileHandle, (u_int8_t *)[data bytes], [data length]);
	}*/
	
	// ReplayGain
	NSNumber *referenceLoudness = [metadata valueForKey:ReplayGainReferenceLoudnessKey];
	if(nil == referenceLoudness)
		MP4DeleteMetadataFreeForm(mp4FileHandle, "replaygain_reference_loudness", NULL);
	else {
		const char *value = [[NSString stringWithFormat:@"%2.1f dB", [referenceLoudness doubleValue]] UTF8String];
		result = MP4SetMetadataFreeForm(mp4FileHandle, "replaygain_reference_loudness", (const u_int8_t *)value, strlen(value), NULL);
	}

	NSNumber *trackGain = [metadata valueForKey:ReplayGainTrackGainKey];
	if(nil == trackGain)
		MP4DeleteMetadataFreeForm(mp4FileHandle, "replaygain_track_gain", NULL);
	else {
		const char *value = [[NSString stringWithFormat:@"%+2.2f dB", [trackGain doubleValue]] UTF8String];
		result = MP4SetMetadataFreeForm(mp4FileHandle, "replaygain_track_gain", (const u_int8_t *)value, strlen(value), NULL);
	}

	NSNumber *trackPeak = [metadata valueForKey:ReplayGainTrackPeakKey];
	if(nil == trackPeak)
		MP4DeleteMetadataFreeForm(mp4FileHandle, "repaaygain_track_peak", NULL);
	else {
		const char *value = [[NSString stringWithFormat:@"%1.8f", [trackPeak doubleValue]] UTF8String];
		result = MP4SetMetadataFreeForm(mp4FileHandle, "replaygain_track_peak", (const u_int8_t *)value, strlen(value), NULL);
	}

	NSNumber *albumGain = [metadata valueForKey:ReplayGainAlbumGainKey];
	if(nil == albumGain)
		MP4DeleteMetadataFreeForm(mp4FileHandle, "replaygain_album_gain", NULL);
	else {
		const char *value = [[NSString stringWithFormat:@"%+2.2f dB", [albumGain doubleValue]] UTF8String];
		result = MP4SetMetadataFreeForm(mp4FileHandle, "replaygain_album_gain", (const u_int8_t *)value, strlen(value), NULL);
	}

	NSNumber *albumPeak = [metadata valueForKey:ReplayGainAlbumPeakKey];
	if(nil == albumPeak)
		MP4DeleteMetadataFreeForm(mp4FileHandle, "replaygain_album_peak", NULL);
	else {
		const char *value = [[NSString stringWithFormat:@"%1.8f", [albumPeak doubleValue]] UTF8String];
		result = MP4SetMetadataFreeForm(mp4FileHandle, "replaygain_album_peak", (const u_int8_t *)value, strlen(value), NULL);
	}
	
	// Make our mark
	NSString *bundleShortVersionString	= [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
//	NSString *bundleVersion				= [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
//	NSString *applicationVersionString	= [NSString stringWithFormat:@"Play %@ (%@)", bundleShortVersionString, bundleVersion];
	NSString *applicationVersionString	= [NSString stringWithFormat:@"Play %@", bundleShortVersionString];
	
	result = MP4SetMetadataTool(mp4FileHandle, [applicationVersionString UTF8String]);
	
	MP4Close(mp4FileHandle);
	
	return YES;
}

@end
