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

#import "LibraryNode.h"
#import "AudioLibrary.h"
#import "CollectionManager.h"
#import "AudioStreamManager.h"
#import "AudioLibrary.h"
#import "AudioStream.h"

@interface AudioStreamCollectionNode (Private)
- (NSMutableArray *) streamsArray;
@end

@interface LibraryNode (Private)
- (void) streamsChanged:(NSNotification *)aNotification;
@end

@implementation LibraryNode

- (id) init
{
	if((self = [super initWithName:NSLocalizedStringFromTable(@"Library", @"Library", @"")])) {

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
	[[[CollectionManager manager] streamManager] removeObserver:self forKeyPath:@"streams"];
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
}

- (void) loadStreams
{
	[self willChangeValueForKey:@"streams"];
	[[self streamsArray] addObjectsFromArray:[[[CollectionManager manager] streamManager] streams]];
	[self didChangeValueForKey:@"streams"];
}

- (void) refreshStreams
{
	[self willChangeValueForKey:@"streams"];
	[[self streamsArray] removeAllObjects];
	[[self streamsArray] addObjectsFromArray:[[[CollectionManager manager] streamManager] streams]];
	[self didChangeValueForKey:@"streams"];
}

#pragma mark KVC Mutator Overrides

- (void) removeObjectFromStreamsAtIndex:(unsigned)index
{
	NSAssert([self canRemoveStream], @"Attempt to remove a stream from an immutable LibraryNode");	
	AudioStream *stream = [[self streamsArray] objectAtIndex:index];
	
	if([stream isPlaying]) {
		[[AudioLibrary library] stop:self];
	}
	
	[stream delete];
	[[self streamsArray] removeObjectAtIndex:index];
}

@end

@implementation LibraryNode (Private)

- (void) streamsChanged:(NSNotification *)aNotification
{
	[self refreshStreams];
}

@end
