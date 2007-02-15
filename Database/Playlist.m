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

#import "Playlist.h"
#import "CollectionManager.h"
#import "AudioStreamManager.h"

NSString * const	PlaylistDidChangeNotification			= @"org.sbooth.Play.PlaylistDidChangeNotification";

NSString * const	PlaylistNameKey							= @"name";

NSString * const	StatisticsDateCreatedKey				= @"dateCreated";

@implementation Playlist

+ (id) insertPlaylistWithInitialValues:(NSDictionary *)keyedValues
{
	Playlist *playlist = [[Playlist alloc] init];
	
	// Call init: methods here to avoid sending change notifications to the context
	[playlist initValue:[NSDate date] forKey:StatisticsDateCreatedKey];
	[playlist initValuesForKeysWithDictionary:keyedValues];
	
	if(NO == [[CollectionManager playlistManager] insertPlaylist:playlist]) {
		[playlist release], playlist = nil;
	}
	
	return [playlist autorelease];
}

- (NSArray *) entries
{
	return [[CollectionManager playlistManager] playlistEntriesForPlaylist:self];
}

- (NSArray *) streams
{
	return [[CollectionManager playlistManager] streamsForPlaylist:self];
}

- (void) addStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	
	[self addStreams:[NSArray arrayWithObject:stream]];
}

- (void) addStreams:(NSArray *)streams
{
	NSParameterAssert(nil != streams);
	NSParameterAssert(0 != [streams count]);
	
	NSEnumerator	*enumerator		= [streams objectEnumerator];
	AudioStream		*stream			= nil;

	[[CollectionManager manager] beginUpdate];
	
	while((stream = [enumerator nextObject])) {
		[[CollectionManager playlistManager] addStream:stream toPlaylist:self];
	}

	[[CollectionManager manager] finishUpdate];
}


- (void) addStreamWithID:(NSNumber *)objectID
{
	NSParameterAssert(nil != objectID);

	AudioStream *stream = [[[CollectionManager manager] streamManager] streamForID:objectID];
	if(nil != stream) {
		[self addStream:stream];
	}
}

- (void) addStreamsWithIDs:(NSArray *)objectIDs
{
	NSParameterAssert(nil != objectIDs);
	NSParameterAssert(0 != [objectIDs count]);
	
	NSEnumerator	*enumerator		= [objectIDs objectEnumerator];
	NSNumber		*objectID		= nil;
	AudioStream		*stream			= nil;
	NSMutableArray	*streams		= [NSMutableArray array];
	
	while((objectID = [enumerator nextObject])) {
		stream = [[[CollectionManager manager] streamManager] streamForID:objectID];
		if(nil != stream) {
			[streams addObject:stream];
		}
	}
	
	if(0 != [streams count]) {
		[self addStreams:streams];
	}

/*	NSArray *streams = [[self databaseContext] streamsForIDs:objectIDs];
	if(nil != streams && 0 != [streams count]) {
		[self addStreams:streams];
	}*/
}

- (BOOL) isPlaying							{ return _playing; }
- (void) setPlaying:(BOOL)playing			{ _playing = playing; }

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
	[[NSNotificationCenter defaultCenter] postNotificationName:PlaylistDidChangeNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:self forKey:PlaylistObjectKey]];
}

#pragma mark Reimplementations

- (NSArray *) databaseKeys
{
	if(nil == _databaseKeys) {
		_databaseKeys	= [[NSArray alloc] initWithObjects:
			ObjectIDKey, 

			PlaylistNameKey, 
			
			StatisticsDateCreatedKey,
			StatisticsFirstPlayedDateKey,
			StatisticsLastPlayedDateKey,
			StatisticsPlayCountKey,
			
			nil];
	}	
	return _databaseKeys;
}

@end
