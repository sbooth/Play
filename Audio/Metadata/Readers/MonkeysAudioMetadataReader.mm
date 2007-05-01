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
	[metadataDictionary setValue:[NSNumber numberWithInt:[trackNumber intValue]] forKey:MetadataTrackNumberKey];	
	
	// Total tracks
	NSString *trackTotal = getAPETag(f, "TRACKTOTAL");
	[metadataDictionary setValue:[NSNumber numberWithInt:[trackTotal intValue]] forKey:MetadataTrackTotalKey];	
	
	// Disc number
	NSString *discNumber = getAPETag(f, "DISCNUMBER");
	[metadataDictionary setValue:[NSNumber numberWithInt:[discNumber intValue]] forKey:MetadataDiscNumberKey];	
	
	// Discs in set
	NSString *discTotal = getAPETag(f, "DISCTOTAL");
	[metadataDictionary setValue:[NSNumber numberWithInt:[discTotal intValue]] forKey:MetadataAlbumTitleKey];	
	
	// Compilation
	NSString *compilation = getAPETag(f, "COMPILATION");
	[metadataDictionary setValue:[NSNumber numberWithInt:[compilation intValue]] forKey:MetadataCompilationKey];	
	
	// ISRC
	[metadataDictionary setValue:getAPETag(f, "ISRC") forKey:MetadataISRCKey];
	
	// MCN
	[metadataDictionary setValue:getAPETag(f, "MCN") forKey:MetadataMCNKey];
	
	// BPM
	NSString *bpm = getAPETag(f, "BPM");
	[metadataDictionary setValue:[NSNumber numberWithInt:[bpm intValue]] forKey:MetadataBPMKey];		

	delete f;
	free(chars);
	
	[self setValue:metadataDictionary forKey:@"metadata"];
	
	return YES;
}

@end
