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
#import "AudioStream.h"

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
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Ogg FLAC file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not an Ogg FLAC file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
										 code:AudioMetadataWriterFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
		
	// Album title
	NSString *album = [metadata valueForKey:MetadataAlbumTitleKey];
	f.tag()->addField("ALBUM", (nil == album ? TagLib::String::null : TagLib::String([album UTF8String], TagLib::String::UTF8)));
	
	// Artist
	NSString *artist = [metadata valueForKey:MetadataArtistKey];
	f.tag()->addField("ARTIST", (nil == artist ? TagLib::String::null : TagLib::String([artist UTF8String], TagLib::String::UTF8)));

	// Album Artist
	NSString *albumArtist = [metadata valueForKey:MetadataAlbumArtistKey];
	f.tag()->addField("ALBUMARTIST", (nil == albumArtist ? TagLib::String::null : TagLib::String([albumArtist UTF8String], TagLib::String::UTF8)));
	
	// Composer
	NSString *composer = [metadata valueForKey:MetadataComposerKey];
	f.tag()->addField("COMPOSER", (nil == composer ? TagLib::String::null : TagLib::String([composer UTF8String], TagLib::String::UTF8)));
	
	// Genre
	NSString *genre = [metadata valueForKey:MetadataGenreKey];
	f.tag()->addField("GENRE", (nil == genre ? TagLib::String::null : TagLib::String([genre UTF8String], TagLib::String::UTF8)));
	
	// Date
	NSString *date = [metadata valueForKey:MetadataDateKey];
	f.tag()->addField("DATE", (nil == date ? TagLib::String::null : TagLib::String([date UTF8String], TagLib::String::UTF8)));
	
	// Comment
	NSString *comment = [metadata valueForKey:MetadataCommentKey];
	f.tag()->addField("DESCRIPTION", (nil == comment ? TagLib::String::null : TagLib::String([comment UTF8String], TagLib::String::UTF8)));
	
	// Track title
	NSString *title = [metadata valueForKey:MetadataTitleKey];
	f.tag()->addField("TITLE", (nil == title ? TagLib::String::null : TagLib::String([title UTF8String], TagLib::String::UTF8)));
	
	// Track number
	NSNumber *trackNumber = [metadata valueForKey:MetadataTrackNumberKey];
	f.tag()->addField("TRACKNUMBER", (nil == trackNumber ? TagLib::String::null : TagLib::String([[trackNumber stringValue] UTF8String], TagLib::String::UTF8)));
	
	// Total tracks
	NSNumber *trackTotal = [metadata valueForKey:MetadataTrackTotalKey];
	f.tag()->addField("TRACKTOTAL", (nil == trackTotal ? TagLib::String::null : TagLib::String([[trackTotal stringValue] UTF8String], TagLib::String::UTF8)));
	
	// Compilation
	NSNumber *compilation = [metadata valueForKey:MetadataCompilationKey];
	f.tag()->addField("COMPILATION", (nil == compilation ? TagLib::String::null : TagLib::String([[compilation stringValue] UTF8String], TagLib::String::UTF8)));
	
	// Disc number
	NSNumber *discNumber = [metadata valueForKey:MetadataDiscNumberKey];
	f.tag()->addField("DISCNUMBER", (nil == discNumber ? TagLib::String::null : TagLib::String([[discNumber stringValue] UTF8String], TagLib::String::UTF8)));
	
	// Discs in set
	NSNumber *discTotal = [metadata valueForKey:MetadataDiscTotalKey];
	f.tag()->addField("DISCTOTAL", (nil == discTotal ? TagLib::String::null : TagLib::String([[discTotal stringValue] UTF8String], TagLib::String::UTF8)));
	
	// ISRC
	NSString *isrc = [metadata valueForKey:MetadataISRCKey];
	f.tag()->addField("ISRC", (nil == isrc ? TagLib::String::null : TagLib::String([isrc UTF8String], TagLib::String::UTF8)));
	
	// MCN
	NSString *mcn = [metadata valueForKey:MetadataMCNKey];
	f.tag()->addField("MCN", (nil == mcn ? TagLib::String::null : TagLib::String([mcn UTF8String], TagLib::String::UTF8)));

	// BPM
	NSNumber *bpm = [metadata valueForKey:MetadataBPMKey];
	f.tag()->addField("BPM", (nil == bpm ? TagLib::String::null : TagLib::String([[bpm stringValue] UTF8String], TagLib::String::UTF8)));

	// ReplayGain
	NSNumber *referenceLoudness = [metadata valueForKey:ReplayGainReferenceLoudnessKey];
	f.tag()->addField("REPLAYGAIN_REFERENCE_LOUDNESS", (nil == referenceLoudness ? TagLib::String::null : TagLib::String([[NSString stringWithFormat:@"%2.1f dB", [referenceLoudness doubleValue]] UTF8String], TagLib::String::UTF8)));
	
	NSNumber *trackGain = [metadata valueForKey:ReplayGainTrackGainKey];
	f.tag()->addField("REPLAYGAIN_TRACK_GAIN", (nil == trackGain ? TagLib::String::null : TagLib::String([[NSString stringWithFormat:@"%+2.2f dB", [trackGain doubleValue]] UTF8String], TagLib::String::UTF8)));
	
	NSNumber *trackPeak = [metadata valueForKey:ReplayGainTrackPeakKey];
	f.tag()->addField("REPLAYGAIN_TRACK_PEAK", (nil == trackPeak ? TagLib::String::null : TagLib::String([[NSString stringWithFormat:@"%1.8f", [trackPeak doubleValue]] UTF8String], TagLib::String::UTF8)));
	
	NSNumber *albumGain = [metadata valueForKey:ReplayGainAlbumGainKey];
	f.tag()->addField("REPLAYGAIN_ALBUM_GAIN", (nil == albumGain ? TagLib::String::null : TagLib::String([[NSString stringWithFormat:@"%+2.2f dB", [albumGain doubleValue]] UTF8String], TagLib::String::UTF8)));
	
	NSNumber *albumPeak = [metadata valueForKey:ReplayGainAlbumPeakKey];
	f.tag()->addField("REPLAYGAIN_ALBUM_PEAK", (nil == albumPeak ? TagLib::String::null : TagLib::String([[NSString stringWithFormat:@"%1.8f", [albumPeak doubleValue]] UTF8String], TagLib::String::UTF8)));

	NSString *puid = [metadata valueForKey:MetadataMusicDNSPUIDKey];
	f.tag()->addField("MUSICDNS_PUID", (nil == puid ? TagLib::String::null : TagLib::String([puid UTF8String], TagLib::String::UTF8)));

	NSString *mbid = [metadata valueForKey:MetadataMusicBrainzIDKey];
	f.tag()->addField("MUSICBRAINZ_ID", (nil == mbid ? TagLib::String::null : TagLib::String([mbid UTF8String], TagLib::String::UTF8)));

	result = f.save();
	if(NO == result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [_url path];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Musepack file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
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
