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
// Key Names
// ========================================
extern NSString * const		PlaylistNameKey;

extern NSString * const		StatisticsDateCreatedKey;
extern NSString * const		StatisticsFirstPlayedDateKey;
extern NSString * const		StatisticsLastPlayedDateKey;
extern NSString * const		StatisticsPlayCountKey;

extern NSString * const		PlaylistStreamsKey;

@class CollectionManager;
@class AudioStream;

@interface Playlist : DatabaseObject
{
	@private
	NSMutableArray	*_streams;
	BOOL			_playing;
}

+ (id) insertPlaylistWithInitialValues:(NSDictionary *)keyedValues;

// ========================================
// Stream management
- (NSArray *) streams;
- (AudioStream *) streamAtIndex:(unsigned)index;

- (void) addStream:(AudioStream *)stream;
- (void) insertStream:(AudioStream *)stream atIndex:(unsigned)index;

- (void) addStreams:(NSArray *)streams;
- (void) insertStreams:(NSArray *)streams atIndexes:(NSIndexSet *)indexes;

- (void) addStreamWithID:(NSNumber *)objectID;
- (void) insertStreamWithID:(NSNumber *)objectID atIndex:(unsigned)index;

- (void) addStreamsWithIDs:(NSArray *)objectIDs;
- (void) insertStreamWithIDs:(NSArray *)objectIDs atIndexes:(NSIndexSet *)indexes;

- (void) removeStreamAtIndex:(unsigned)index;

// ========================================
// KVC Accessors
- (unsigned)		countOfStreams;
- (AudioStream *)	objectInStreamsAtIndex:(unsigned)index;
- (void)			getStreams:(id *)buffer range:(NSRange)range;

// ========================================
// KVC Mutators
- (void) insertObject:(AudioStream *)stream inStreamsAtIndex:(unsigned)index;
- (void) removeObjectFromStreamsAtIndex:(unsigned)index;

// ========================================
// Object state
- (BOOL) isPlaying;
- (void) setPlaying:(BOOL)playing;

@end

// ========================================
// Interfaces for other classes, not for general consumption
@interface Playlist (PlaylistNodeMethods)
- (void) loadStreams;
@end

