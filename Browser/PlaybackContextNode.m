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

#import "PlaybackContextNode.h"
#import "AudioLibrary.h"

@interface AudioStreamCollectionNode (Private)
- (NSMutableArray *) streamsArray;
@end

@implementation PlaybackContextNode

- (id) init
{
	if((self = [super initWithName:NSLocalizedStringFromTable(@"Playback Context", @"General", @"")])) {
		[[AudioLibrary library] addObserver:self forKeyPath:@"playbackContext" options:nil context:NULL];
	}
	return self;
}

- (void) dealloc
{
	[[AudioLibrary library] removeObserver:self forKeyPath:@"playbackContext"];
	
	[super dealloc];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self refreshStreams];
}

- (BOOL) nameIsEditable			{ return NO; }
- (BOOL) streamsAreOrdered		{ return YES; }
- (BOOL) allowReordering		{ return NO; }

- (void) loadStreams
{
	[self willChangeValueForKey:@"streams"];
	[[self streamsArray] addObjectsFromArray:[[AudioLibrary library] playbackContext]];
	[self didChangeValueForKey:@"streams"];
}

- (void) refreshStreams
{
	[self willChangeValueForKey:@"streams"];
	[[self streamsArray] removeAllObjects];
	[[self streamsArray] addObjectsFromArray:[[AudioLibrary library] playbackContext]];
	[self didChangeValueForKey:@"streams"];
}

#pragma mark KVC Mutators Overrides

- (void) insertObject:(AudioStream *)stream inStreamsAtIndex:(unsigned)index
{}

- (void) removeObjectFromStreamsAtIndex:(unsigned)index
{}

@end
