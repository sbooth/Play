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

#import "GenresNode.h"
#import "CollectionManager.h"
#import "AudioStreamManager.h"
#import "AudioStream.h"
#import "AudioLibrary.h"
#import "GenreNode.h"

@interface GenresNode (Private)
- (void) streamsChanged:(NSNotification *)aNotification;
- (void) loadChildren;
@end

@implementation GenresNode

- (id) init
{
	if((self = [super initWithName:NSLocalizedStringFromTable(@"Genres", @"Library", @"")])) {
		[self loadChildren];
		
		[[[CollectionManager manager] streamManager] addObserver:self 
													  forKeyPath:MetadataGenreKey
														 options:0
														 context:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(streamsChanged:) 
													 name:AudioStreamAddedToLibraryNotification
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(streamsChanged:) 
													 name:AudioStreamsAddedToLibraryNotification
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(streamsChanged:) 
													 name:AudioStreamRemovedFromLibraryNotification
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(streamsChanged:) 
													 name:AudioStreamsRemovedFromLibraryNotification
												   object:nil];
		
	}
	return self;
}

- (void) dealloc
{
	[[[CollectionManager manager] streamManager] removeObserver:self forKeyPath:MetadataGenreKey];
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self loadChildren];
}

@end

@implementation GenresNode (Private)

- (void) streamsChanged:(NSNotification *)aNotification
{
	[self loadChildren];
}

- (void) loadChildren
{
	NSString		*keyName		= [NSString stringWithFormat:@"@distinctUnionOfObjects.%@", MetadataGenreKey];
	NSArray			*streams		= [[[CollectionManager manager] streamManager] streams];
	NSArray			*genres			= [[streams valueForKeyPath:keyName] sortedArrayUsingSelector:@selector(compare:)];
	GenreNode		*node			= nil;
	
	[self willChangeValueForKey:@"children"];
	
	[_children makeObjectsPerformSelector:@selector(setParent:) withObject:nil];
	[_children removeAllObjects];
	for(NSString *genre in genres) {
		node = [[GenreNode alloc] initWithName:genre];
		[node setParent:self];
		[_children addObject:[node autorelease]];
	}
	
	[self didChangeValueForKey:@"children"];
}

@end
