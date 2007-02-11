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

#import <Cocoa/Cocoa.h>
#import "DatabaseObject.h"

// ========================================
// Notification Names
// ========================================
extern NSString * const		PlaylistDidChangeNotification;

// ========================================
// Notification Keys
// ========================================
extern NSString * const		PlaylistObjectKey;

// ========================================
// Key Names
// ========================================
extern NSString * const		PlaylistNameKey;

extern NSString * const		StatisticsDateCreatedKey;
extern NSString * const		StatisticsFirstPlayedDateKey;
extern NSString * const		StatisticsLastPlayedDateKey;
extern NSString * const		StatisticsPlayCountKey;

@class DatabaseContext;
@class AudioStream;

@interface Playlist : DatabaseObject
{
	BOOL	_isPlaying;
}

+ (id) insertPlaylistWithInitialValues:(NSDictionary *)keyedValues inDatabaseContext:(DatabaseContext *)context;

// ========================================
// Returns an array of PlaylistEntries contained in this Playlist
- (NSArray *) entries;


- (NSArray *) streams;

- (void) addStream:(AudioStream *)stream;
- (void) addStreams:(NSArray *)streams;

- (void) addStreamWithID:(NSNumber *)objectID;
- (void) addStreamsWithIDs:(NSArray *)objectIDs;

- (void) removeStream:(AudioStream *)stream;
- (void) removeStreams:(NSArray *)streams;

- (BOOL) isPlaying;
- (void) setIsPlaying:(BOOL)isPlaying;

@end
