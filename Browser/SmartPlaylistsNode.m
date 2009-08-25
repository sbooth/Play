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

#import "SmartPlaylistsNode.h"
#import "CollectionManager.h"
#import "SmartPlaylistManager.h"
#import "SmartPlaylist.h"
#import "SmartPlaylistNode.h"

@interface SmartPlaylistsNode (Private)
- (void) loadChildren;
- (SmartPlaylistNode *) findChildForSmartPlaylist:(SmartPlaylist *)playlist;
@end

@implementation SmartPlaylistsNode

- (id) init
{
	if((self = [super initWithName:NSLocalizedStringFromTable(@"Smart Playlists", @"Library", @"")])) {
		[self loadChildren];
		[[[CollectionManager manager] smartPlaylistManager] addObserver:self 
															 forKeyPath:@"smartPlaylists"
																options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
																context:nil];
	}
	return self;
}

- (void) dealloc
{
	[[[CollectionManager manager] smartPlaylistManager] removeObserver:self forKeyPath:@"smartPlaylists"];
	
	[super dealloc];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	NSArray			*old			= [change valueForKey:NSKeyValueChangeOldKey];
	NSArray			*new			= [change valueForKey:NSKeyValueChangeNewKey];
	int				changeKind		= [[change valueForKey:NSKeyValueChangeKindKey] intValue];
	BOOL			needsSort		= NO;
	BrowserNode		*node			= nil;
	SmartPlaylist	*playlist		= nil;
	unsigned		i;
	
	switch(changeKind) {
		case NSKeyValueChangeInsertion:
			for(playlist in new) {
				node = [[SmartPlaylistNode alloc] initWithSmartPlaylist:playlist];
				[self addChild:node];
			}
			break;
			
		case NSKeyValueChangeRemoval:
			for(playlist in old) {
				node = [self findChildForSmartPlaylist:playlist];
				if(nil != node) {
					[self removeChild:node];
				}
			}
			break;
			
		case NSKeyValueChangeSetting:
			for(i = 0; i < [new count]; ++i) {
				playlist = [old objectAtIndex:i];
				node = [self findChildForSmartPlaylist:playlist];
				if(nil != node) {
					playlist = [new objectAtIndex:i];
					[node setName:[playlist valueForKey:PlaylistNameKey]];
				}
			}
			break;
			
		case NSKeyValueChangeReplacement:
			NSLog(@"SmartPlaylistsNode REPLACEMENT !! (?)");
			break;
	}
	
	if(needsSort) {
		[self sortChildren];
	}
}

#pragma mark KVC Mutator Overrides

- (void) removeObjectFromChildrenAtIndex:(unsigned)index
{
	SmartPlaylistNode *node = [[self childAtIndex:index] retain];
	
	/*	if([node isPlaying]) {
	[[AudioLibrary library] stop:self];
	}*/
	
	[super removeObjectFromChildrenAtIndex:index];
	[[node smartPlaylist] delete];
	[node release];
}

@end

@implementation SmartPlaylistsNode (Private)

- (void) loadChildren
{
	NSArray				*playlists		= [[[CollectionManager manager] smartPlaylistManager] smartPlaylists];
	SmartPlaylist		*playlist		= nil;
	SmartPlaylistNode	*node			= nil;
	
	[self willChangeValueForKey:@"children"];
	[_children makeObjectsPerformSelector:@selector(setParent:) withObject:nil];
	[_children removeAllObjects];
	for(playlist in playlists) {
		node = [[SmartPlaylistNode alloc] initWithSmartPlaylist:playlist];
		[node setParent:self];
		[_children addObject:[node autorelease]];
	}
	[self didChangeValueForKey:@"children"];
}

- (SmartPlaylistNode *) findChildForSmartPlaylist:(SmartPlaylist *)playlist
{
	// Breadth-first search
	SmartPlaylistNode 	*match 		= nil;
	
	for(SmartPlaylistNode *child in _children) {
		if([[child smartPlaylist] isEqual:playlist]) {
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
