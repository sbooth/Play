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

#import "PlaylistsNode.h"
#import "CollectionManager.h"
#import "PlaylistManager.h"
#import "Playlist.h"
#import "PlaylistNode.h"

@interface PlaylistsNode (Private)
- (void) loadChildren;
- (PlaylistNode *) findChildForPlaylist:(Playlist *)playlist;
@end

@implementation PlaylistsNode

- (id) init
{
	if((self = [super initWithName:NSLocalizedStringFromTable(@"Playlists", @"Library", @"")])) {
		[self loadChildren];
		[[[CollectionManager manager] playlistManager] addObserver:self 
														forKeyPath:@"playlists"
														   options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
														   context:nil];
	}
	return self;
}

- (void) dealloc
{
	[[[CollectionManager manager] playlistManager] removeObserver:self forKeyPath:@"playlists"];
	
	[super dealloc];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	NSArray			*old			= [change valueForKey:NSKeyValueChangeOldKey];
	NSArray			*new			= [change valueForKey:NSKeyValueChangeNewKey];
	int				changeKind		= [[change valueForKey:NSKeyValueChangeKindKey] intValue];
	BOOL			needsSort		= NO;
	BrowserNode		*node			= nil;
	Playlist		*playlist		= nil;
	unsigned		i;
	
	switch(changeKind) {
		case NSKeyValueChangeInsertion:
			for(playlist in new) {
				node = [[PlaylistNode alloc] initWithPlaylist:playlist];
				[self addChild:node];
			}
			break;

		case NSKeyValueChangeRemoval:
			for(playlist in old) {
				node = [self findChildForPlaylist:playlist];
				if(nil != node) {
					[self removeChild:node];
				}
			}
			break;

		case NSKeyValueChangeSetting:
			for(i = 0; i < [new count]; ++i) {
				playlist = [old objectAtIndex:i];
				node = [self findChildForPlaylist:playlist];
				if(nil != node) {
					playlist = [new objectAtIndex:i];
					[node setName:[playlist valueForKey:PlaylistNameKey]];
				}
			}
			break;
			
		case NSKeyValueChangeReplacement:
			NSLog(@"PlaylistsNode REPLACEMENT !! (?)");
			break;
	}
	
	if(needsSort) {
		[self sortChildren];
	}
}

#pragma mark KVC Mutator Overrides

- (void) removeObjectFromChildrenAtIndex:(unsigned)index
{
	PlaylistNode *node = [[self childAtIndex:index] retain];
	
/*	if([node isPlaying]) {
		[[AudioLibrary library] stop:self];
	}*/
	
	[super removeObjectFromChildrenAtIndex:index];
	[[node playlist] delete];
	[node release];
}

@end

@implementation PlaylistsNode (Private)

- (void) loadChildren
{
	PlaylistNode	*node			= nil;
	
	[self willChangeValueForKey:@"children"];

	[_children makeObjectsPerformSelector:@selector(setParent:) withObject:nil];
	[_children removeAllObjects];
	for(Playlist *playlist in [[[CollectionManager manager] playlistManager] playlists]) {
		node = [[PlaylistNode alloc] initWithPlaylist:playlist];
		[node setParent:self];
		[_children addObject:[node autorelease]];
	}
	
	[self didChangeValueForKey:@"children"];
}

- (PlaylistNode *) findChildForPlaylist:(Playlist *)playlist
{
	// Breadth-first search
	PlaylistNode 	*match 		= nil;
	
	for(PlaylistNode *child in _children) {
		if([[child playlist] isEqual:playlist]) {
			match = child;
			break;
		}
	}

	// Hierarchical playlists aren't implemented yet
/*	if(nil == match) {
		enumerator 	= [_children objectEnumerator];
		child 		= nil;
		
		while(match == nil && (child = [enumerator nextObject])) {
			match = [child findChildForPlaylist:playlist];
		}
	}*/
	
	return match;
}

@end
