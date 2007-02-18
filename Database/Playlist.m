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
#import "PlaylistManager.h"
#import "AudioStreamManager.h"

NSString * const	PlaylistDidChangeNotification			= @"org.sbooth.Play.PlaylistDidChangeNotification";

NSString * const	PlaylistNameKey							= @"name";

NSString * const	StatisticsDateCreatedKey				= @"dateCreated";

@interface AudioStreamManager (PlaylistMethods)
- (NSArray *) streamsForPlaylist:(Playlist *)playlist;
@end

@interface PlaylistManager (PlaylistMethods)
- (void) playlist:(Playlist *)playlist willInsertStream:(AudioStream *)stream atIndex:(unsigned)index;
- (void) playlist:(Playlist *)playlist didInsertStream:(AudioStream *)stream atIndex:(unsigned)index;

- (void) playlist:(Playlist *)playlist willRemoveStreamAtIndex:(unsigned)index;
- (void) playlist:(Playlist *)playlist didRemoveStreamAtIndex:(unsigned)index;
@end

@interface Playlist (PlaylistNodeMethods)
- (void) loadStreams;
@end

@implementation Playlist

+ (void) initialize
{
	[self exposeBinding:@"streams"];
}

+ (id) insertPlaylistWithInitialValues:(NSDictionary *)keyedValues
{
	Playlist *playlist = [[Playlist alloc] init];
	
	// Call init: methods here to avoid sending change notifications
	[playlist initValue:[NSDate date] forKey:StatisticsDateCreatedKey];
	[playlist initValuesForKeysWithDictionary:keyedValues];
	
	if(NO == [[[CollectionManager manager] playlistManager] insertPlaylist:playlist]) {
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

- (void) addStream:(AudioStream *)stream
{
	[self insertObject:stream inStreamsAtIndex:[_streams count]];
}

- (void) insertStream:(AudioStream *)stream atIndex:(unsigned)index
{
	[self insertObject:stream inStreamsAtIndex:index];
}

- (void) addStreams:(NSArray *)streams
{
	NSParameterAssert(nil != streams);
	NSParameterAssert(0 != [streams count]);
	
	NSEnumerator	*enumerator		= [streams objectEnumerator];
	AudioStream		*stream			= nil;
	
	[[CollectionManager manager] beginUpdate];
	
	while((stream = [enumerator nextObject])) {
		[self addStream:stream];
	}
	
	[[CollectionManager manager] finishUpdate];
}

- (void) insertStreams:(NSArray *)streams atIndexes:(NSIndexSet *)indexes
{
	NSParameterAssert(nil != streams);
	NSParameterAssert(nil != indexes);
	NSParameterAssert(0 != [streams count]);
	NSParameterAssert([streams count] == [indexes count]);
	
	unsigned	i, count;
	unsigned	*indexBuffer	= (unsigned *)calloc([indexes count], sizeof(unsigned));
	NSAssert(NULL != indexBuffer, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	
	count = [indexes getIndexes:indexBuffer maxCount:[indexes count] inIndexRange:nil];
	NSAssert(count == [indexes count], @"Unable to extract all indexes.");
	
	[[CollectionManager manager] beginUpdate];

	for(i = 0; i < [streams count]; ++i) {
		[self insertObject:[streams objectAtIndex:i] inStreamsAtIndex:indexBuffer[i]];
	}
	
	[[CollectionManager manager] finishUpdate];

	free(indexBuffer);
}

- (void) addStreamWithID:(NSNumber *)objectID
{
	AudioStream *stream = [[[CollectionManager manager] streamManager] streamForID:objectID];
	[self insertObject:stream inStreamsAtIndex:[_streams count]];
}

- (void) insertStreamWithID:(NSNumber *)objectID atIndex:(unsigned)index
{
	AudioStream *stream = [[[CollectionManager manager] streamManager] streamForID:objectID];
	[self insertObject:stream inStreamsAtIndex:index];
}

- (void) addStreamsWithIDs:(NSArray *)objectIDs
{
	NSParameterAssert(nil != objectIDs);
	NSParameterAssert(0 != [objectIDs count]);

	NSEnumerator	*enumerator		= [objectIDs objectEnumerator];
	NSNumber		*objectID		= nil;
	AudioStream		*stream			= nil;
	
	[[CollectionManager manager] beginUpdate];

	while((objectID = [enumerator nextObject])) {
		stream = [[[CollectionManager manager] streamManager] streamForID:objectID];
		[self addStream:stream];
	}

	[[CollectionManager manager] finishUpdate];	
}

- (void) insertStreamWithIDs:(NSArray *)objectIDs atIndexes:(NSIndexSet *)indexes
{
	NSParameterAssert(nil != objectIDs);
	NSParameterAssert(nil != indexes);
	NSParameterAssert(0 != [objectIDs count]);
	NSParameterAssert([objectIDs count] == [indexes count]);
	
	unsigned	i, count;
	unsigned	*indexBuffer	= (unsigned *)calloc([indexes count], sizeof(unsigned));
	NSAssert(NULL != indexBuffer, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	
	count = [indexes getIndexes:indexBuffer maxCount:[indexes count] inIndexRange:nil];
	NSAssert(count == [indexes count], @"Unable to extract all indexes.");
	
	[[CollectionManager manager] beginUpdate];
	
	for(i = 0; i < [objectIDs count]; ++i) {
		[self insertStreamWithID:[objectIDs objectAtIndex:i] atIndex:indexBuffer[i]];
	}
	
	[[CollectionManager manager] finishUpdate];	
	
	free(indexBuffer);
}

- (void) removeStreamAtIndex:(unsigned)index
{
	[self removeObjectFromStreamsAtIndex:index];
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

#pragma mark KVC Mutators

- (void) insertObject:(AudioStream *)stream inStreamsAtIndex:(unsigned)index
{
	[[[CollectionManager manager] playlistManager] playlist:self willInsertStream:stream atIndex:index];
	[_streams insertObject:stream atIndex:index];
	[[[CollectionManager manager] playlistManager] playlist:self didInsertStream:stream atIndex:index];
}

- (void) removeObjectFromStreamsAtIndex:(unsigned)index
{
	[[[CollectionManager manager] playlistManager] playlist:self willRemoveStreamAtIndex:index];
	[_streams removeObjectAtIndex:index];
	[[[CollectionManager manager] playlistManager] playlist:self didRemoveStreamAtIndex:index];
}

- (BOOL) isPlaying							{ return _playing; }
- (void) setPlaying:(BOOL)playing			{ _playing = playing; }

- (void) save
{
	[[[CollectionManager manager] playlistManager] savePlaylist:self];
}

- (void) delete
{
	[[[CollectionManager manager] playlistManager] deletePlaylist:self];
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
	[[NSNotificationCenter defaultCenter] postNotificationName:PlaylistDidChangeNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:self forKey:PlaylistObjectKey]];
}

#pragma mark Reimplementations

- (NSArray *) supportedKeys
{
	if(nil == _supportedKeys) {
		_supportedKeys	= [[NSArray alloc] initWithObjects:
			ObjectIDKey, 

			PlaylistNameKey, 
			
			StatisticsDateCreatedKey,
			StatisticsFirstPlayedDateKey,
			StatisticsLastPlayedDateKey,
			StatisticsPlayCountKey,
			
			nil];
	}	
	return _supportedKeys;
}

@end

@implementation Playlist (PlaylistNodeMethods)

- (void) loadStreams
{
	[self willChangeValueForKey:@"streams"];
	[_streams removeAllObjects];
	[_streams addObjectsFromArray:[[[CollectionManager manager] streamManager] streamsForPlaylist:self]];
	[self didChangeValueForKey:@"streams"];
}

@end
