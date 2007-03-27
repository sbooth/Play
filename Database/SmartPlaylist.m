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

#import "SmartPlaylist.h"
#import "CollectionManager.h"
#import "SmartPlaylistManager.h"
#import "AudioStreamManager.h"

NSString * const	SmartPlaylistDidChangeNotification		= @"org.sbooth.Play.SmartPlaylistDidChangeNotification";

NSString * const	SmartPlaylistPredicateKey				= @"predicate";

@interface AudioStreamManager (SmartPlaylistMethods)
- (NSArray *) streamsForSmartPlaylist:(SmartPlaylist *)playlist;
@end

@interface SmartPlaylist (SmartPlaylistNodeMethods)
- (void) loadStreams;
@end

@implementation SmartPlaylist

+ (void) initialize
{
	[self exposeBinding:PlaylistStreamsKey];
}

+ (id) insertSmartPlaylistWithInitialValues:(NSDictionary *)keyedValues
{
	SmartPlaylist *playlist = [[SmartPlaylist alloc] init];
	
	// Call init: methods here to avoid sending change notifications
	[playlist initValue:[NSDate date] forKey:StatisticsDateCreatedKey];
	[playlist initValuesForKeysWithDictionary:keyedValues];
	
	if(NO == [[[CollectionManager manager] smartPlaylistManager] insertSmartPlaylist:playlist]) {
		[playlist release], playlist = nil;
	}
	
	return [playlist autorelease];
}

- (id) init
{
	if((self = [super init])) {
		_streams = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) dealloc
{
	[_streams release], _streams = nil;
	
	[super dealloc];
}

#pragma mark Stream Management

- (NSArray *) streams
{
	return _streams;
}

- (AudioStream *) streamAtIndex:(unsigned)index
{
	return [self objectInStreamsAtIndex:index];
}

#pragma mark KVC Accessors

- (unsigned) countOfStreams
{
	return [_streams count];
}

- (AudioStream *) objectInStreamsAtIndex:(unsigned)index
{
	return [_streams objectAtIndex:index];
}

- (void) getStreams:(id *)buffer range:(NSRange)range
{
	return [_streams getObjects:buffer range:range];
}

- (BOOL) isPlaying							{ return _playing; }
- (void) setPlaying:(BOOL)playing			{ _playing = playing; }

- (void) save
{
	[[[CollectionManager manager] smartPlaylistManager] saveSmartPlaylist:self];
}

- (void) delete
{
	[[[CollectionManager manager] smartPlaylistManager] deleteSmartPlaylist:self];
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"[%@] %@", [self valueForKey:ObjectIDKey], [self valueForKey:PlaylistNameKey]];
}

- (NSString *) debugDscription
{
	return [NSString stringWithFormat:@"<%@, %x> [%@] %@", [self class], self, [self valueForKey:ObjectIDKey], [self valueForKey:PlaylistNameKey]];
}

#pragma mark Callbacks

- (void) didSave
{
	[[NSNotificationCenter defaultCenter] postNotificationName:SmartPlaylistDidChangeNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:self forKey:SmartPlaylistObjectKey]];
}

#pragma mark Reimplementations

- (NSArray *) supportedKeys
{
	if(nil == _supportedKeys) {
		_supportedKeys	= [[NSArray alloc] initWithObjects:
			ObjectIDKey, 

			PlaylistNameKey, 
			
			SmartPlaylistPredicateKey,
			
			StatisticsDateCreatedKey,
			StatisticsFirstPlayedDateKey,
			StatisticsLastPlayedDateKey,
			StatisticsPlayCountKey,
			
			nil];
	}	
	return _supportedKeys;
}

@end

@implementation SmartPlaylist (SmartPlaylistNodeMethods)

- (void) loadStreams
{
	[self willChangeValueForKey:PlaylistStreamsKey];
	[_streams removeAllObjects];
	[_streams addObjectsFromArray:[[[CollectionManager manager] streamManager] streamsForSmartPlaylist:self]];
	[self didChangeValueForKey:PlaylistStreamsKey];
}

@end
