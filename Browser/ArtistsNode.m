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

#import "ArtistsNode.h"
#import "CollectionManager.h"
#import "AudioStreamManager.h"
#import "AudioStream.h"
#import "ArtistNode.h"

@interface ArtistsNode (Private)
- (void) loadChildren;
@end

@implementation ArtistsNode

- (id) init
{
	if((self = [super initWithName:NSLocalizedStringFromTable(@"Artists", @"General", @"")])) {
		[self loadChildren];
		[[[CollectionManager manager] streamManager] addObserver:self 
													  forKeyPath:MetadataArtistKey
														 options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
														 context:nil];
	}
	return self;
}

- (void) dealloc
{
	[[[CollectionManager manager] streamManager] removeObserver:self forKeyPath:MetadataArtistKey];
	
	[super dealloc];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	NSSet 			*old 		= [NSSet setWithArray:[change valueForKey:NSKeyValueChangeOldKey]];
	NSSet 			*new 		= [NSSet setWithArray:[change valueForKey:NSKeyValueChangeNewKey]];
	BOOL			needsSort	= NO;
	
	// Remove any modified nodes with empty streams from our children
	NSEnumerator 	*enumerator 	= nil;
	NSString 		*artist 		= nil;
	BrowserNode 	*node 			= nil;

	if(0 != [old count]) {
		enumerator = [old objectEnumerator];
		while((artist = [enumerator nextObject])) {
			node = [self findChildWithName:artist];
			if([node isKindOfClass:[AudioStreamCollectionNode class]]) {
				[(AudioStreamCollectionNode *)node refreshStreams];
				if(0 == [(AudioStreamCollectionNode *)node countOfStreams]) {
					[self removeChild:node];
					needsSort = YES;
				}
			}
		}
	}
	
	// Add the new artists if they don't already exist
	if(0 != [new count]) {
		enumerator = [new objectEnumerator];
		while((artist = [enumerator nextObject])) {
			node = [self findChildWithName:artist];
			if(nil == node) {
				node = [[ArtistNode alloc] initWithName:artist];
				[self addChild:[node autorelease]];
				node = nil;
				needsSort = YES;
			}
		}
	}
	
	if(needsSort) {
		[self sortChildren];
	}
}

@end

@implementation ArtistsNode (Private)

- (void) loadChildren
{
	NSArray			*artists		= [[[CollectionManager manager] streamManager] valueForKey:MetadataArtistKey];
	NSEnumerator	*enumerator		= [artists objectEnumerator];
	NSString		*artist			= nil;
	ArtistNode		*node			= nil;
	
	[self willChangeValueForKey:@"children"];
	[_children makeObjectsPerformSelector:@selector(setParent:) withObject:nil];
	[_children removeAllObjects];
	while((artist = [enumerator nextObject])) {
		node = [[ArtistNode alloc] initWithName:artist];
		[node setParent:self];
		[_children addObject:[node autorelease]];
	}
	[self didChangeValueForKey:@"children"];
}

@end
