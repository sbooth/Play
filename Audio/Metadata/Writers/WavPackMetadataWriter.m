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

#import "WavPackMetadataWriter.h"
#import "AudioStream.h"
#include <wavpack/wavpack.h>

@implementation WavPackMetadataWriter

- (BOOL) writeMetadata:(id)metadata error:(NSError **)error
{
	NSString			*path				= [_url path];
    WavpackContext		*wpc				= NULL;
	char				errorBuf [80];
	int					result;
	
	wpc = WavpackOpenFileInput([path fileSystemRepresentation], errorBuf, OPEN_EDIT_TAGS, 0);

	if(NULL == wpc) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid WavPack file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a WavPack file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
										 code:AudioMetadataWriterFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	// Album title
	NSString *album = [metadata valueForKey:MetadataAlbumTitleKey];
	WavpackDeleteTagItem(wpc, "ALBUM");
	if(nil != album)
		WavpackAppendTagItem(wpc, "ALBUM", [album UTF8String], strlen([album UTF8String]));
	
	// Artist
	NSString *artist = [metadata valueForKey:MetadataArtistKey];
	WavpackDeleteTagItem(wpc, "ARTIST");
	if(nil != artist)
		WavpackAppendTagItem(wpc, "ARTIST", [artist UTF8String], strlen([artist UTF8String]));

	// Album Artist
	NSString *albumArtist = [metadata valueForKey:MetadataAlbumArtistKey];
	WavpackDeleteTagItem(wpc, "ALBUMARTIST");
	if(nil != albumArtist)
		WavpackAppendTagItem(wpc, "ALBUMARTIST", [albumArtist UTF8String], strlen([albumArtist UTF8String]));
	
	// Composer
	NSString *composer = [metadata valueForKey:MetadataComposerKey];
	WavpackDeleteTagItem(wpc, "COMPOSER");
	if(nil != composer)
		WavpackAppendTagItem(wpc, "COMPOSER", [composer UTF8String], strlen([composer UTF8String]));
	
	// Genre
	NSString *genre = [metadata valueForKey:MetadataGenreKey];
	WavpackDeleteTagItem(wpc, "GENRE");
	if(nil != genre)
		WavpackAppendTagItem(wpc, "GENRE", [genre UTF8String], strlen([genre UTF8String]));
	
	// Date
	NSString *year = [metadata valueForKey:MetadataDateKey];
	WavpackDeleteTagItem(wpc, "YEAR");
	if(nil != year)
		WavpackAppendTagItem(wpc, "YEAR", [year UTF8String], strlen([year UTF8String]));
	
	// Comment
	NSString *comment = [metadata valueForKey:MetadataCommentKey];
	WavpackDeleteTagItem(wpc, "COMMENT");
	if(nil != comment)
		WavpackAppendTagItem(wpc, "COMMENT", [comment UTF8String], strlen([comment UTF8String]));
	
	// Track title
	NSString *title = [metadata valueForKey:MetadataTitleKey];
	WavpackDeleteTagItem(wpc, "TITLE");
	if(nil != title)
		WavpackAppendTagItem(wpc, "TITLE", [title UTF8String], strlen([title UTF8String]));
	
	// Track number
	NSNumber *trackNumber = [metadata valueForKey:MetadataTrackNumberKey];
	WavpackDeleteTagItem(wpc, "TRACK");
	if(nil != trackNumber)
		WavpackAppendTagItem(wpc, "TRACK", [[trackNumber stringValue] UTF8String], strlen([[trackNumber stringValue] UTF8String]));
	
	// Track total
	NSNumber *trackTotal = [metadata valueForKey:MetadataTrackTotalKey];
	WavpackDeleteTagItem(wpc, "TRACKTOTAL");
	if(nil != trackTotal)
		WavpackAppendTagItem(wpc, "TRACKTOTAL", [[trackTotal stringValue] UTF8String], strlen([[trackTotal stringValue] UTF8String]));
	
	// Compilation
	NSNumber *compilation	= [metadata valueForKey:MetadataCompilationKey];
	WavpackDeleteTagItem(wpc, "COMPILATION");
	if(nil != compilation)
		WavpackAppendTagItem(wpc, "COMPILATION", [[compilation stringValue] UTF8String], strlen([[compilation stringValue] UTF8String]));
	
	// Disc number
	NSNumber *discNumber = [metadata valueForKey:MetadataDiscNumberKey];
	WavpackDeleteTagItem(wpc, "DISCNUMBER");
	if(nil != discNumber)
		WavpackAppendTagItem(wpc, "DISCNUMBER", [[discNumber stringValue] UTF8String], strlen([[discNumber stringValue] UTF8String]));
	
	// Discs in set
	NSNumber *discTotal	= [metadata valueForKey:MetadataDiscTotalKey];
	WavpackDeleteTagItem(wpc, "DISCTOTAL");
	if(nil != discTotal)
		WavpackAppendTagItem(wpc, "DISCTOTAL", [[discTotal stringValue] UTF8String], strlen([[discTotal stringValue] UTF8String]));
	
	// ISRC
	NSString *isrc = [metadata valueForKey:MetadataISRCKey];
	WavpackDeleteTagItem(wpc, "ISRC");
	if(nil != isrc)
		WavpackAppendTagItem(wpc, "ISRC", [isrc UTF8String], strlen([isrc UTF8String]));
	
	// MCN
	NSString *mcn = [metadata valueForKey:MetadataMCNKey];
	WavpackDeleteTagItem(wpc, "MCN");
	if(nil != mcn)
		WavpackAppendTagItem(wpc, "MCN", [mcn UTF8String], strlen([mcn UTF8String]));

	// BPM
	NSNumber *bpm	= [metadata valueForKey:MetadataBPMKey];
	WavpackDeleteTagItem(wpc, "BPM");
	if(nil != bpm)
		WavpackAppendTagItem(wpc, "BPM", [[bpm stringValue] UTF8String], strlen([[bpm stringValue] UTF8String]));

	// ReplayGain
	NSNumber *referenceLoudness = [metadata valueForKey:ReplayGainReferenceLoudnessKey];
	WavpackDeleteTagItem(wpc, "REPLAYGAIN_REFERENCE_LOUDNESS");
	if(nil != referenceLoudness) {
		NSString *referenceLoudnessString = [NSString stringWithFormat:@"%2.1f dB", [referenceLoudness doubleValue]];
		WavpackAppendTagItem(wpc, "REPLAYGAIN_REFERENCE_LOUDNESS", [referenceLoudnessString UTF8String], strlen([referenceLoudnessString UTF8String]));
	}

	NSNumber *trackGain = [metadata valueForKey:ReplayGainTrackGainKey];
	WavpackDeleteTagItem(wpc, "REPLAYGAIN_TRACK_GAIN");
	if(nil != trackGain) {
		NSString *trackGainString = [NSString stringWithFormat:@"%+2.2f dB", [trackGain doubleValue]];
		WavpackAppendTagItem(wpc, "REPLAYGAIN_TRACK_GAIN", [trackGainString UTF8String], strlen([trackGainString UTF8String]));
	}

	NSNumber *trackPeak = [metadata valueForKey:ReplayGainTrackPeakKey];
	WavpackDeleteTagItem(wpc, "REPLAYGAIN_TRACK_PEAK");
	if(nil != trackPeak) {
		NSString *trackPeakString = [NSString stringWithFormat:@"%1.8f", [trackPeak doubleValue]];
		WavpackAppendTagItem(wpc, "REPLAYGAIN_TRACK_PEAK", [trackPeakString UTF8String], strlen([trackPeakString UTF8String]));
	}

	NSNumber *albumGain = [metadata valueForKey:ReplayGainAlbumGainKey];
	WavpackDeleteTagItem(wpc, "REPLAYGAIN_ALBUM_GAIN");
	if(nil != albumGain) {
		NSString *albumGainString = [NSString stringWithFormat:@"%+2.2f dB", [albumGain doubleValue]];
		WavpackAppendTagItem(wpc, "REPLAYGAIN_ALBUM_GAIN", [albumGainString UTF8String], strlen([albumGainString UTF8String]));
	}

	NSNumber *albumPeak = [metadata valueForKey:ReplayGainAlbumPeakKey];
	WavpackDeleteTagItem(wpc, "REPLAYGAIN_ALBUM_PEAK");
	if(nil != albumPeak) {
		NSString *albumPeakString = [NSString stringWithFormat:@"%1.8f", [albumPeak doubleValue]];
		WavpackAppendTagItem(wpc, "REPLAYGAIN_ALBUM_PEAK", [albumPeakString UTF8String], strlen([albumPeakString UTF8String]));
	}
	
	NSString *puid = [metadata valueForKey:MetadataMusicDNSPUIDKey];
	WavpackDeleteTagItem(wpc, "MUSICDNS_PUID");
	if(nil != puid)
		WavpackAppendTagItem(wpc, "MUSICDNS_PUID", [puid UTF8String], strlen([puid UTF8String]));

	NSString *mbid = [metadata valueForKey:MetadataMusicBrainzIDKey];
	WavpackDeleteTagItem(wpc, "MUSICBRAINZ_ID");
	if(nil != mbid)
		WavpackAppendTagItem(wpc, "MUSICBRAINZ_ID", [mbid UTF8String], strlen([mbid UTF8String]));

	result = WavpackWriteTag(wpc);

	if(NO == result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [_url path];
						
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid WavPack file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Unable to write metadata", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
										 code:AudioMetadataWriterFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	wpc = WavpackCloseFile(wpc);
	if(NULL != wpc) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [_url path];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid WavPack file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
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
