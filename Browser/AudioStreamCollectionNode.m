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

#import "AudioStreamCollectionNode.h"
#import "AudioLibrary.h"
#import "AudioStream.h"

@interface AudioStreamCollectionNode (Private)
- (NSMutableArray *) streamsArray;
@end

@implementation AudioStreamCollectionNode

+ (void) initialize
{
	[self exposeBinding:@"streams"];
}

- (void) dealloc
{
	[_streams release], _streams = nil;
	
	[super dealloc];
}

- (void) loadStreams
{}

- (void) refreshStreams
{}

- (BOOL) streamsAreOrdered			{ return NO; }
- (BOOL) streamReorderingAllowed	{ return NO; }

#pragma mark State management

- (BOOL) canInsertStream			{ return YES; }
- (BOOL) canRemoveStream			{ return YES; }

#pragma mark KVC Accessors

- (unsigned)		countOfStreams											{ return [[self streamsArray] count]; }
- (AudioStream *)	objectInStreamsAtIndex:(unsigned)index					{ return [[self streamsArray] objectAtIndex:index]; }
- (void)			getStreams:(id *)buffer range:(NSRange)aRange			{ return [[self streamsArray] getObjects:buffer range:aRange]; }

#pragma mark KVC Mutators

- (void) insertObject:(AudioStream *)stream inStreamsAtIndex:(unsigned)index
{
	NSAssert([self canInsertStream], @"Attempt to insert a stream in an immutable AudioStreamCollectionNode");
	[[self streamsArray] insertObject:stream atIndex:index];
}

- (void) removeObjectFromStreamsAtIndex:(unsigned)index
{
	NSAssert([self canRemoveStream], @"Attempt to remove a stream from an immutable AudioStreamCollectionNode");	
	[[self streamsArray] removeObjectAtIndex:index];
}

@end

@implementation AudioStreamCollectionNode (Private)

- (NSMutableArray *) streamsArray
{
	@synchronized(self) {
		if(nil == _streams) {
			_streams = [[NSMutableArray alloc] init];
			[self loadStreams];
		}
	}
	return _streams;
}

@end
