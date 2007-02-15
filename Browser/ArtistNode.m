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

#import "ArtistNode.h"
#import "AudioLibrary.h"
#import "CollectionManager.h"
#import "AudioStreamManager.h"
#import "AudioStream.h"

@interface AudioStreamCollectionNode (Private)
- (NSMutableArray *) streamsArray;
@end

@implementation ArtistNode

- (id) initWithArtist:(NSString *)artist
{
	NSParameterAssert(nil != artist);
	
	if((self = [super initWithName:artist])) {
		[[[CollectionManager manager] streamManager] addObserver:self 
													  forKeyPath:@"streams" 
														 options:nil//(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) 
														 context:nil];
	}
	return self;
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	NSLog(@"ArtistNode observeValueForKeyPath:%@ ofObject:%@ change:%@", keyPath, object, change);
	// The streams in the library changed, so refresh them
	[self refreshData];
}

- (void) refreshData
{
	[self willChangeValueForKey:@"streams"];
	[[self streamsArray] removeAllObjects];
	[[self streamsArray] addObjectsFromArray:[[[CollectionManager manager] streamManager] streamsForArtist:[self name]]];
	[self didChangeValueForKey:@"streams"];
}

#pragma mark KVC Mutator Overrides

- (void) insertObject:(AudioStream *)stream inStreamsAtIndex:(unsigned)index
{
	NSAssert([self canInsertStream], @"Attempt to insert a stream in an immutable ArtistNode");

	// Only add streams that match our artist
	if([[stream valueForKey:MetadataArtistKey] isEqualToString:[self name]]) {
		[[self streamsArray] insertObject:stream atIndex:index];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamAddedToLibraryNotification 
														object:[AudioLibrary library] 
													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
}

- (void) removeObjectFromStreamsAtIndex:(unsigned)index
{
	NSAssert([self canRemoveStream], @"Attempt to remove a stream from an immutable ArtistNode");	
	
	AudioStream *stream = [[self streamsArray] objectAtIndex:index];
	
	if([stream isPlaying]) {
		[[AudioLibrary library] stop:self];
	}
	
	// To keep the database and in-memory representation in sync, remove the 
	// stream from the database first
	[stream delete];
	
	[[self streamsArray] removeObjectAtIndex:index];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamRemovedFromLibraryNotification 
														object:[AudioLibrary library] 
													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
}

@end
