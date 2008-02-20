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

#import "WavPackMetadataReader.h"
#import "AudioStream.h"
#include <wavpack/wavpack.h>

static NSString *
getWavPackTag(WavpackContext	*wpc, 
			  const char		*name)
{
	NSCParameterAssert(NULL != wpc);
	NSCParameterAssert(NULL != name);
	
	NSString	*result		= nil;
	int			len			= WavpackGetTagItem(wpc, name, NULL, 0);

	if(0 != len) {
		char *tagValue = (char *)calloc(len + 1, sizeof(char));
		NSCAssert(NULL != tagValue, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
		
		len = WavpackGetTagItem(wpc, name, tagValue, len + 1);
		result = [[NSString alloc] initWithBytesNoCopy:tagValue length:len encoding:NSUTF8StringEncoding freeWhenDone:YES];
	}
	
	return [result autorelease];
}

@implementation WavPackMetadataReader

- (BOOL) readMetadata:(NSError **)error
{
	NSMutableDictionary				*metadataDictionary		= nil;
	NSString						*path					= [[self valueForKey:StreamURLKey] path];
	char							errorMsg [80];
    WavpackContext					*wpc					= NULL;

	wpc = WavpackOpenFileInput([path fileSystemRepresentation], errorMsg, OPEN_TAGS, 0);
	if(NULL == wpc) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid WavPack file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a WavPack file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataReaderErrorDomain 
										 code:AudioMetadataReaderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}

	metadataDictionary = [NSMutableDictionary dictionary];

	// Album title
	[metadataDictionary setValue:getWavPackTag(wpc, "ALBUM") forKey:MetadataAlbumTitleKey];
	
	// Artist
	[metadataDictionary setValue:getWavPackTag(wpc, "ARTIST") forKey:MetadataArtistKey];

	// Album Artist
	[metadataDictionary setValue:getWavPackTag(wpc, "ALBUMARTIST") forKey:MetadataAlbumArtistKey];
	
	// Composer
	[metadataDictionary setValue:getWavPackTag(wpc, "COMPOSER") forKey:MetadataComposerKey];
	
	// Genre
	[metadataDictionary setValue:getWavPackTag(wpc, "GENRE") forKey:MetadataGenreKey];
	
	// Year
	[metadataDictionary setValue:getWavPackTag(wpc, "YEAR") forKey:MetadataDateKey];
	
	// Comment
	[metadataDictionary setValue:getWavPackTag(wpc, "COMMENT") forKey:MetadataCommentKey];
	
	// Track title
	[metadataDictionary setValue:getWavPackTag(wpc, "TITLE") forKey:MetadataTitleKey];
	
	// Track number
	NSString *trackNumber = getWavPackTag(wpc, "TRACK");
	if(nil != trackNumber)
		[metadataDictionary setValue:[NSNumber numberWithInt:[trackNumber intValue]] forKey:MetadataTrackNumberKey];	
	
	// Total tracks
	NSString *trackTotal = getWavPackTag(wpc, "TRACKTOTAL");
	if(nil != trackTotal)
		[metadataDictionary setValue:[NSNumber numberWithInt:[trackTotal intValue]] forKey:MetadataTrackTotalKey];	
	
	// Disc number
	NSString *discNumber = getWavPackTag(wpc, "DISCNUMBER");
	if(nil != discNumber)
		[metadataDictionary setValue:[NSNumber numberWithInt:[discNumber intValue]] forKey:MetadataDiscNumberKey];	
	
	// Discs in set
	NSString *discTotal = getWavPackTag(wpc, "DISCTOTAL");
	if(nil != discTotal)
		[metadataDictionary setValue:[NSNumber numberWithInt:[discTotal intValue]] forKey:MetadataDiscTotalKey];	
	
	// Compilation
	NSString *compilation = getWavPackTag(wpc, "COMPILATION");
	if(nil != compilation)
		[metadataDictionary setValue:[NSNumber numberWithBool:[compilation intValue]] forKey:MetadataCompilationKey];	
	
	// ISRC
	[metadataDictionary setValue:getWavPackTag(wpc, "ISRC") forKey:MetadataISRCKey];
	
	// MCN
	[metadataDictionary setValue:getWavPackTag(wpc, "MCN") forKey:MetadataMCNKey];
	
	// BPM
	NSString *bpm = getWavPackTag(wpc, "BPM");
	if(nil != bpm)
		[metadataDictionary setValue:[NSNumber numberWithInt:[bpm intValue]] forKey:MetadataBPMKey];	
	
	// ReplayGain
	NSString *referenceLoudness = getWavPackTag(wpc, "REPLAYGAIN_REFERENCE_LOUDNESS");
	if(nil != referenceLoudness) {
		NSScanner	*scanner		= [NSScanner scannerWithString:referenceLoudness];						
		double		doubleValue		= 0.0;
		
		if([scanner scanDouble:&doubleValue])
			[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainReferenceLoudnessKey];
	}

	NSString *trackGain = getWavPackTag(wpc, "REPLAYGAIN_TRACK_GAIN");
	if(nil != trackGain) {
		NSScanner	*scanner		= [NSScanner scannerWithString:trackGain];						
		double		doubleValue		= 0.0;
		
		if([scanner scanDouble:&doubleValue])
			[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainTrackGainKey];
	}

	NSString *trackPeak = getWavPackTag(wpc, "REPLAYGAIN_TRACK_PEAK");
	if(nil != trackPeak)
		[metadataDictionary setValue:[NSNumber numberWithDouble:[trackPeak doubleValue]] forKey:ReplayGainTrackPeakKey];

	NSString *albumGain = getWavPackTag(wpc, "REPLAYGAIN_ALBUM_GAIN");
	if(nil != albumGain) {
		NSScanner	*scanner		= [NSScanner scannerWithString:albumGain];						
		double		doubleValue		= 0.0;
		
		if([scanner scanDouble:&doubleValue])
			[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainAlbumGainKey];
	}
	
	NSString *albumPeak = getWavPackTag(wpc, "REPLAYGAIN_ALBUM_PEAK");
	if(nil != albumPeak)
		[metadataDictionary setValue:[NSNumber numberWithDouble:[albumPeak doubleValue]] forKey:ReplayGainAlbumPeakKey];
	
	[metadataDictionary setValue:getWavPackTag(wpc, "MUSICDNS_PUID") forKey:MetadataMusicDNSPUIDKey];
	[metadataDictionary setValue:getWavPackTag(wpc, "MUSICBRAINZ_ID") forKey:MetadataMusicBrainzIDKey];

	WavpackCloseFile(wpc);
	
	[self setValue:metadataDictionary forKey:@"metadata"];
	
	return YES;
}

@end
