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

#import "MonkeysAudioMetadataWriter.h"
#import "AudioStream.h"
#include <mac/All.h>
#include <mac/MACLib.h>
#include <mac/APETag.h>
#include <mac/CharacterHelper.h>

static void 
setField(CAPETag		*f, 
		 const char		*name, 
		 NSString		*value)
{
	NSCParameterAssert(NULL != f);
	NSCParameterAssert(NULL != name);
	
	str_utf16 *fieldName = GetUTF16FromANSI(name);
	NSCAssert(NULL != fieldName, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	
	f->RemoveField(fieldName);
	
	if(nil != value) {
		f->SetFieldString(fieldName, [value UTF8String], TRUE);
	}
	
	free(fieldName);
}

@implementation MonkeysAudioMetadataWriter

- (BOOL) writeMetadata:(id)metadata error:(NSError **)error
{
	NSString				*path				= [_url path];
	str_utf16				*chars				= NULL;
	CAPETag					*f					= NULL;
	NSNumber				*numericValue		= nil;
	int						result;
	
	chars = GetUTF16FromANSI([path fileSystemRepresentation]);
	NSAssert(NULL != chars, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	
	f = new CAPETag(chars);
	NSAssert(NULL != f, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	
	if(NULL == f) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Monkey's Audio file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a Monkey's Audio file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
										 code:AudioMetadataWriterFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		free(chars);
		
		return NO;
	}
	
	// Album title
	setField(f, "ALBUM", [metadata valueForKey:MetadataAlbumTitleKey]);
	
	// Artist
	setField(f, "ARTIST", [metadata valueForKey:MetadataArtistKey]);

	// Album Artist
	setField(f, "ALBUM ARTIST", [metadata valueForKey:MetadataAlbumArtistKey]);
	
	// Composer
	setField(f, "COMPOSER", [metadata valueForKey:MetadataComposerKey]);
	
	// Genre
	setField(f, "GENRE", [metadata valueForKey:MetadataGenreKey]);

	// Date
	setField(f, "YEAR", [metadata valueForKey:MetadataDateKey]);
	
	// Comment
	setField(f, "COMMENT", [metadata valueForKey:MetadataCommentKey]);
	
	// Track title
	setField(f, "TITLE", [metadata valueForKey:MetadataTitleKey]);
	
	// Track number
	numericValue = [metadata valueForKey:MetadataTrackNumberKey];
	setField(f, "TRACK", (nil == numericValue ? nil : [numericValue stringValue]));
	
	// Total tracks
	numericValue = [metadata valueForKey:MetadataTrackTotalKey];
	setField(f, "TRACKTOTAL", (nil == numericValue? nil : [numericValue stringValue]));
	
	// Compilation
	numericValue = [metadata valueForKey:MetadataCompilationKey];
	setField(f, "COMPILATION", (nil == numericValue? nil : [numericValue stringValue]));
	
	// Disc number
	numericValue = [metadata valueForKey:MetadataDiscNumberKey];
	setField(f, "DISCNUMBER", (nil == numericValue? nil : [numericValue stringValue]));
	
	// Discs in set
	numericValue = [metadata valueForKey:MetadataDiscTotalKey];
	setField(f, "DISCTOTAL", (nil == numericValue? nil : [numericValue stringValue]));
	
	// ISRC
	setField(f, "ISRC", [metadata valueForKey:MetadataISRCKey]);
	
	// MCN
	setField(f, "MCN", [metadata valueForKey:MetadataMCNKey]);

	// BPM
	numericValue = [metadata valueForKey:MetadataBPMKey];
	setField(f, "BPM", (nil == numericValue? nil : [numericValue stringValue]));
	
	// ReplayGain
	NSNumber *referenceLoudness = [metadata valueForKey:ReplayGainReferenceLoudnessKey];
	setField(f, "REPLAYGAIN_REFERENCE_LOUDNESS", (nil == referenceLoudness ? nil : [NSString stringWithFormat:@"%2.1f dB", [referenceLoudness doubleValue]]));
	
	NSNumber *trackGain = [metadata valueForKey:ReplayGainTrackGainKey];
	setField(f, "REPLAYGAIN_TRACK_GAIN", (nil == trackGain ? nil : [NSString stringWithFormat:@"%+2.2f dB", [trackGain doubleValue]]));
	setField(f, "Replay Gain (radio)", (nil == trackGain ? nil : [trackGain stringValue]));
	
	NSNumber *trackPeak = [metadata valueForKey:ReplayGainTrackPeakKey];
	setField(f, "REPLAYGAIN_TRACK_PEAK", (nil == trackPeak ? nil : [NSString stringWithFormat:@"%1.8f", [trackPeak doubleValue]]));
	setField(f, "Peak Level", (nil == trackPeak ? nil : [trackPeak stringValue]));
	
	NSNumber *albumGain = [metadata valueForKey:ReplayGainAlbumGainKey];
	setField(f, "REPLAYGAIN_ALBUM_GAIN", (nil == albumGain ? nil : [NSString stringWithFormat:@"%+2.2f dB", [albumGain doubleValue]]));
	setField(f, "Replay Gain (album)", (nil == albumGain ? nil : [albumGain stringValue]));
	
	NSNumber *albumPeak = [metadata valueForKey:ReplayGainAlbumPeakKey];
	setField(f, "REPLAYGAIN_ALBUM_PEAK", (nil == albumPeak ? nil : [NSString stringWithFormat:@"%1.8f", [albumPeak doubleValue]]));

	setField(f, "MUSICDNS_PUID", [metadata valueForKey:MetadataMusicDNSPUIDKey]);
	setField(f, "MUSICBRAINZ_ID", [metadata valueForKey:MetadataMusicBrainzIDKey]);

	result = f->Save();
	if(ERROR_SUCCESS != result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [_url path];
						
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Monkey's Audio file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a Monkey's Audio file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
										 code:AudioMetadataWriterFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}

		delete f;
		free(chars);
		
		return NO;
	}

	delete f;
	free(chars);
	
	return YES;
}

@end
