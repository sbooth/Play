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

#import "MonkeysAudioMetadataReader.h"
#import "AudioStream.h"
#include <mac/All.h>
#include <mac/MACLib.h>
#include <mac/APETag.h>
#include <mac/CharacterHelper.h>

static NSString *
getAPETag(CAPETag		*f, 
		  const char	*name)
{
	NSCParameterAssert(NULL != f);
	NSCParameterAssert(NULL != name);

	NSString *result = nil;

	str_utf16 *tagName = GetUTF16FromANSI(name);
	NSCAssert(NULL != tagName, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	
	CAPETagField *tag = f->GetTagField(tagName);
	if(NULL != tag && tag->GetIsUTF8Text()) {
		result = [[NSString alloc] initWithUTF8String:tag->GetFieldValue()];
	}
	
	free(tagName);
	
	return [result autorelease];
}

@implementation MonkeysAudioMetadataReader

- (BOOL) readMetadata:(NSError **)error
{
	NSMutableDictionary				*metadataDictionary		= nil;
	NSString						*path					= [[self valueForKey:StreamURLKey] path];
	CAPETag							*f						= NULL;
	
	str_utf16 *chars = GetUTF16FromANSI([path fileSystemRepresentation]);
	NSAssert(NULL != chars, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	
	f = new CAPETag(chars);
	NSAssert(NULL != f, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));

	metadataDictionary = [NSMutableDictionary dictionary];

	// Album title
	[metadataDictionary setValue:getAPETag(f, "ALBUM") forKey:MetadataAlbumTitleKey];
	
	// Artist
	[metadataDictionary setValue:getAPETag(f, "ARTIST") forKey:MetadataArtistKey];
	
	// Album Artist
	[metadataDictionary setValue:getAPETag(f, "ALBUMARTIST") forKey:MetadataAlbumArtistKey];
	
	// Composer
	[metadataDictionary setValue:getAPETag(f, "COMPOSER") forKey:MetadataComposerKey];
	
	// Genre
	[metadataDictionary setValue:getAPETag(f, "GENRE") forKey:MetadataGenreKey];
	
	// Year
	[metadataDictionary setValue:getAPETag(f, "YEAR") forKey:MetadataDateKey];
	
	// Comment
	[metadataDictionary setValue:getAPETag(f, "COMMENT") forKey:MetadataCommentKey];
	
	// Track title
	[metadataDictionary setValue:getAPETag(f, "TITLE") forKey:MetadataTitleKey];
	
	// Track number
	NSString *trackNumber = getAPETag(f, "TRACK");
	if(nil != trackNumber)
		[metadataDictionary setValue:[NSNumber numberWithInt:[trackNumber intValue]] forKey:MetadataTrackNumberKey];	
	
	// Total tracks
	NSString *trackTotal = getAPETag(f, "TRACKTOTAL");
	if(nil != trackTotal)
		[metadataDictionary setValue:[NSNumber numberWithInt:[trackTotal intValue]] forKey:MetadataTrackTotalKey];	
	
	// Disc number
	NSString *discNumber = getAPETag(f, "DISCNUMBER");
	if(nil != discNumber)
		[metadataDictionary setValue:[NSNumber numberWithInt:[discNumber intValue]] forKey:MetadataDiscNumberKey];	
	
	// Discs in set
	NSString *discTotal = getAPETag(f, "DISCTOTAL");
	if(nil != discTotal)
		[metadataDictionary setValue:[NSNumber numberWithInt:[discTotal intValue]] forKey:MetadataDiscTotalKey];	
	
	// Compilation
	NSString *compilation = getAPETag(f, "COMPILATION");
	if(nil != compilation)
		[metadataDictionary setValue:[NSNumber numberWithBool:[compilation intValue]] forKey:MetadataCompilationKey];	
	
	// ISRC
	[metadataDictionary setValue:getAPETag(f, "ISRC") forKey:MetadataISRCKey];
	
	// MCN
	[metadataDictionary setValue:getAPETag(f, "MCN") forKey:MetadataMCNKey];
	
	// BPM
	NSString *bpm = getAPETag(f, "BPM");
	if(nil != bpm)
		[metadataDictionary setValue:[NSNumber numberWithInt:[bpm intValue]] forKey:MetadataBPMKey];		
	
	// Replay Gain
	NSString *peak = getAPETag(f, "Peak Level");
	if(nil != peak)
		[metadataDictionary setValue:[NSNumber numberWithDouble:[peak doubleValue]] forKey:ReplayGainTrackPeakKey];		
	
	NSString *trackGain = getAPETag(f, "Replay Gain (radio)");
	if(nil != trackGain)
		[metadataDictionary setValue:[NSNumber numberWithDouble:[trackGain doubleValue]] forKey:ReplayGainTrackGainKey];		
	
	NSString *albumGain = getAPETag(f, "Replay Gain (album)");
	if(nil != albumGain) {
		[metadataDictionary setValue:[NSNumber numberWithDouble:[albumGain doubleValue]] forKey:ReplayGainAlbumGainKey];		
	}

	NSString *referenceLoudness = getAPETag(f, "REPLAYGAIN_REFERENCE_LOUDNESS");
	if(nil != referenceLoudness) {
		NSScanner	*scanner		= [NSScanner scannerWithString:referenceLoudness];						
		double		doubleValue		= 0.0;
		
		if([scanner scanDouble:&doubleValue])
			[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainReferenceLoudnessKey];
	}
	
	trackGain = getAPETag(f, "REPLAYGAIN_TRACK_GAIN");
	if(nil != trackGain) {
		NSScanner	*scanner		= [NSScanner scannerWithString:trackGain];						
		double		doubleValue		= 0.0;
		
		if([scanner scanDouble:&doubleValue])
			[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainTrackGainKey];
	}
	
	NSString *trackPeak = getAPETag(f, "REPLAYGAIN_TRACK_PEAK");
	if(nil != trackPeak)
		[metadataDictionary setValue:[NSNumber numberWithDouble:[trackPeak doubleValue]] forKey:ReplayGainTrackPeakKey];
	
	albumGain = getAPETag(f, "REPLAYGAIN_ALBUM_GAIN");
	if(nil != albumGain) {
		NSScanner	*scanner		= [NSScanner scannerWithString:albumGain];						
		double		doubleValue		= 0.0;
		
		if([scanner scanDouble:&doubleValue])
			[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainAlbumGainKey];
	}
	
	NSString *albumPeak = getAPETag(f, "REPLAYGAIN_ALBUM_PEAK");
	if(nil != albumPeak)
		[metadataDictionary setValue:[NSNumber numberWithDouble:[albumPeak doubleValue]] forKey:ReplayGainAlbumPeakKey];
	
	[metadataDictionary setValue:getAPETag(f, "MUSICDNS_PUID") forKey:MetadataMusicDNSPUIDKey];
	[metadataDictionary setValue:getAPETag(f, "MUSICBRAINZ_ID") forKey:MetadataMusicBrainzIDKey];

	delete f;
	free(chars);
	
	[self setValue:metadataDictionary forKey:@"metadata"];
	
	return YES;
}

@end
