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

#import "PlayQueueNode.h"
#import "AudioLibrary.h"

@interface AudioStreamCollectionNode (Private)
- (NSMutableArray *) streamsArray;
@end

@implementation PlayQueueNode

- (id) init
{
	if((self = [super initWithName:NSLocalizedStringFromTable(@"Play Queue", @"General", @"")])) {
		[[AudioLibrary library] addObserver:self forKeyPath:@"currentStreams" options:nil context:NULL];
	}
	return self;
}

- (void) dealloc
{
	[[AudioLibrary library] removeObserver:self forKeyPath:@"currentStreams"];
	
	[super dealloc];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self refreshStreams];
}

- (BOOL) nameIsEditable				{ return NO; }
- (BOOL) streamsAreOrdered			{ return YES; }
- (BOOL) streamReorderingAllowed	{ return YES; }

- (void) loadStreams
{
	[self willChangeValueForKey:@"streams"];
	[self didChangeValueForKey:@"streams"];
}

- (void) refreshStreams
{
	[self willChangeValueForKey:@"streams"];
	[self didChangeValueForKey:@"streams"];
}

#pragma mark KVC Accessor Overrides

- (unsigned)		countOfStreams											{ return [[AudioLibrary library] countOfCurrentStreams]; }
- (AudioStream *)	objectInStreamsAtIndex:(unsigned)index					{ return [[AudioLibrary library] objectInCurrentStreamsAtIndex:index]; }
- (void)			getStreams:(id *)buffer range:(NSRange)aRange			{ return [[AudioLibrary library] getCurrentStreams:buffer range:aRange]; }

#pragma mark KVC Mutators Overrides

- (void) insertObject:(AudioStream *)stream inStreamsAtIndex:(unsigned)index
{
	NSAssert([self canInsertStream], @"Attempt to insert a stream in an immutable PlayQueueNode");
	[[AudioLibrary library] insertObject:stream inCurrentStreamsAtIndex:index];
}

- (void) removeObjectFromStreamsAtIndex:(unsigned)index
{
	NSAssert([self canRemoveStream], @"Attempt to remove a stream from an immutable PlayQueueNode");
	[[AudioLibrary library] removeObjectFromCurrentStreamsAtIndex:index];
}

@end
