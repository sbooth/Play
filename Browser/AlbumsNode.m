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

#import "AlbumsNode.h"
#import "CollectionManager.h"
#import "AudioStreamManager.h"
#import "AudioStream.h"
#import "AlbumNode.h"

@interface AlbumsNode (Private)
- (void) refreshData;
@end

@implementation AlbumsNode

- (id) init
{
	if((self = [super initWithName:NSLocalizedStringFromTable(@"Albums", @"General", @"")])) {
		[self refreshData];
		[[[CollectionManager manager] streamManager] addObserver:self 
													  forKeyPath:@"streams" 
														 options:nil
														 context:nil];
	}
	return self;
}

- (void) dealloc
{
	[[[CollectionManager manager] streamManager] removeObserver:self forKeyPath:@"streams"];
	
	[super dealloc];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self refreshData];
}

@end

@implementation AlbumsNode (Private)

- (void) refreshData
{
	NSString		*keyName		= [NSString stringWithFormat:@"@distinctUnionOfObjects.%@", MetadataAlbumTitleKey];
	NSArray			*albums			= [[[[[CollectionManager manager] streamManager] streams] valueForKeyPath:keyName] sortedArrayUsingSelector:@selector(compare:)];
	NSEnumerator	*enumerator		= [albums objectEnumerator];
	NSString		*album			= nil;
	AlbumNode		*node			= nil;
	
	[self willChangeValueForKey:@"children"];
	[_children makeObjectsPerformSelector:@selector(setParent:) withObject:nil];
	[_children removeAllObjects];
	while((album = [enumerator nextObject])) {
		node = [[AlbumNode alloc] initWithAlbum:album];
		[node setParent:self];
		[_children addObject:node];
	}
	[self didChangeValueForKey:@"children"];
}

@end
