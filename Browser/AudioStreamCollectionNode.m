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

@implementation AudioStreamCollectionNode

+ (void) initialize
{
	[self exposeBinding:@"streams"];
}

- (id) init
{
	if((self = [super init])) {
		_streams = [[NSMutableArray alloc] init];
		[self refreshData];
	}	
	return self;
}

- (void) dealloc
{
	[_streams release], _streams = nil;
	
	[super dealloc];
}

- (void) refreshData
{}

#pragma mark Subclass hooks

- (void) willInsertStream:(AudioStream *)stream 
{}

- (void) didInsertStream:(AudioStream *)stream 
{}

- (void) willRemoveStream:(AudioStream *)stream 
{}

- (void) didRemoveStream:(AudioStream *)stream 
{}

#pragma mark KVC Accessors

- (unsigned)		countOfStreams											{ return [_streams count]; }
- (AudioStream *)	objectInStreamsAtIndex:(unsigned)index					{ return [_streams objectAtIndex:index]; }
- (void)			getStreams:(id *)buffer range:(NSRange)aRange			{ return [_streams getObjects:buffer range:aRange]; }

#pragma mark KVC Mutators

- (void) insertObject:(AudioStream *)stream inStreamsAtIndex:(unsigned)index
{
	[self willInsertStream:stream];
	[_streams insertObject:stream atIndex:index];
	[self didInsertStream:stream];
}

- (void) removeObjectFromStreamsAtIndex:(unsigned)index
{
	AudioStream *stream = [_streams objectAtIndex:index];
	[self willRemoveStream:stream];
	[_streams removeObjectAtIndex:index];
	[self didRemoveStream:stream];
}

@end
