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

#import "AudioStream.h"
#import "AudioLibrary.h"

NSString * const	StreamIDKey								= @"id";
NSString * const	StreamURLKey							= @"url";

NSString * const	StatisticsDateAddedKey					= @"dateAdded";
NSString * const	StatisticsFirstPlayedDateKey			= @"firstPlayed";
NSString * const	StatisticsLastPlayedDateKey				= @"lastPlayed";
NSString * const	StatisticsPlayCountKey					= @"playCount";

NSString * const	MetadataTitleKey						= @"title";
NSString * const	MetadataAlbumTitleKey					= @"albumTitle";
NSString * const	MetadataArtistKey						= @"artist";
NSString * const	MetadataAlbumArtistKey					= @"albumArtist";
NSString * const	MetadataGenreKey						= @"genre";
NSString * const	MetadataComposerKey						= @"composer";
NSString * const	MetadataDateKey							= @"date";
NSString * const	MetadataCompilationKey					= @"compilation";
NSString * const	MetadataTrackNumberKey					= @"trackNumber";
NSString * const	MetadataTrackTotalKey					= @"trackTotal";
NSString * const	MetadataDiscNumberKey					= @"discNumber";
NSString * const	MetadataDiscTotalKey					= @"discTotal";
NSString * const	MetadataCommentKey						= @"comment";
NSString * const	MetadataISRCKey							= @"isrc";
NSString * const	MetadataMCNKey							= @"mcn";

NSString * const	PropertiesFileTypeKey					= @"fileType";
NSString * const	PropertiesFormatTypeKey					= @"formatType";
NSString * const	PropertiesBitsPerChannelKey				= @"bitsPerChannel";
NSString * const	PropertiesChannelsPerFrameKey			= @"channelsPerFrame";
NSString * const	PropertiesSampleRateKey					= @"sampleRate";
NSString * const	PropertiesTotalFramesKey				= @"totalFrames";
NSString * const	PropertiesDurationKey					= @"duration";
NSString * const	PropertiesBitrateKey					= @"bitrate";

@implementation AudioStream

- (id) init
{
	if((self = [super init])) {
		_streamInfo		= [[NSMutableDictionary alloc] init];
		_databaseKeys	= [[NSArray alloc] initWithObjects:
			StreamIDKey, 
			StreamURLKey,
			
			StatisticsDateAddedKey,
			StatisticsFirstPlayedDateKey,
			StatisticsLastPlayedDateKey,
			StatisticsPlayCountKey,
			
			MetadataTitleKey,
			MetadataAlbumTitleKey,
			MetadataArtistKey,
			MetadataAlbumArtistKey,
			MetadataGenreKey,
			MetadataComposerKey,
			MetadataDateKey,
			MetadataCompilationKey,
			MetadataTrackNumberKey,
			MetadataTrackTotalKey,
			MetadataDiscNumberKey,
			MetadataDiscTotalKey,
			MetadataCommentKey,
			MetadataISRCKey,
			MetadataMCNKey,

			PropertiesFileTypeKey,
			PropertiesFormatTypeKey,
			PropertiesBitsPerChannelKey,
			PropertiesChannelsPerFrameKey,
			PropertiesSampleRateKey,
			PropertiesTotalFramesKey,
			PropertiesDurationKey,
			PropertiesBitrateKey,
			
			nil];
		
		_notificationsEnabled = YES;

		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_streamInfo release], _streamInfo = nil;
	[_databaseKeys release], _databaseKeys = nil;
	[super dealloc];
}

- (id) valueForKey:(NSString *)key
{
	return ([_databaseKeys containsObject:key] ? [_streamInfo valueForKey:key] : [super valueForKey:key]);
}

- (void) initValue:(id)value forKey:(NSString *)key
{
	[_streamInfo setValue:value forKey:key];
}

- (BOOL) isDirty					{ return _isDirty; }
- (void) setIsDirty:(BOOL)isDirty	{ _isDirty = isDirty; }

- (void) enableNotifications		{ [self setNotificationsEnabled:YES]; }
- (void) disableNotifications		{ [self setNotificationsEnabled:NO]; }

- (BOOL) notificationsEnabled		{ return _notificationsEnabled; }
- (void) setNotificationsEnabled:(BOOL)notificationsEnabled
{
	_notificationsEnabled = notificationsEnabled;
	
	if([self notificationsEnabled] && [self isDirty]) {
		[[AudioLibrary defaultLibrary] audioStreamDidChange:self];
	}
}

- (void) setValue:(id)value forKey:(NSString *)key
{
	if([_databaseKeys containsObject:key]) {
		[_streamInfo setValue:value forKey:key];

		[self setIsDirty:YES];

		// Propagate changes to database
		if([self notificationsEnabled]) {
			[[AudioLibrary defaultLibrary] audioStreamDidChange:self];
			[self setIsDirty:NO];
		}
	}
	else {
		[super setValue:value forKey:key];
	}
}

- (BOOL) isPlaying							{ return _isPlaying; }
- (void) setIsPlaying:(BOOL)isPlaying		{ _isPlaying = isPlaying; }

- (unsigned) hash
{
	// Database ID is guaranteed to be unique
	return [[_streamInfo valueForKey:StreamIDKey] unsignedIntValue];
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"[%@] %@", [_streamInfo valueForKey:StreamIDKey], [[NSFileManager defaultManager] displayNameAtPath:[[_streamInfo valueForKey:StreamURLKey] path]]];
}

@end
