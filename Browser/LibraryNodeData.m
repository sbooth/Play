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

#import "LibraryNodeData.h"
#import "AudioStream.h"
#import "AudioLibrary.h"

@implementation LibraryNodeData

- (id) init
{
	if((self = [super initWithName:NSLocalizedStringFromTable(@"Library", @"General", @"")])) {
		_streams = [[NSMutableArray alloc] init];
		return self;
	}	
	return nil;
}

- (void) dealloc
{
	[_streams release], _streams = nil;
	
	[super dealloc];
}

- (void) refreshData
{
	[self willChangeValueForKey:@"streams"];
	[_streams release];
	_streams = [[[AudioLibrary defaultLibrary] allStreams] mutableCopy];
	[self didChangeValueForKey:@"streams"];
}

#pragma mark KVC Accessors

- (unsigned)		countOfStreams											{ return [_streams count]; }
- (AudioStream *)	objectInStreamsAtIndex:(unsigned int)index				{ return [_streams objectAtIndex:index]; }
- (void)			getUnorderedStreams:(id *)buffer range:(NSRange)aRange	{ return [_streams getObjects:buffer range:aRange]; }

#pragma mark KVC Mutators

- (void) insertObject:(AudioStream *)stream inStreamsAtIndex:(unsigned int)index
{
	[_streams insertObject:stream atIndex:index];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamAddedToLibraryNotification 
														object:[AudioLibrary defaultLibrary] 
													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
}

- (void) removeObjectFromStreamsAtIndex:(unsigned int)index
{
	AudioStream *stream = [_streams objectAtIndex:index];
	
	if([stream isPlaying]) {
		[[AudioLibrary defaultLibrary] stop:self];
	}
	
	// To keep the database and in-memory representation in sync, remove the 
	// stream from the database first and then from the array
	[stream delete];
	[_streams removeObjectAtIndex:index];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamRemovedFromLibraryNotification 
														object:[AudioLibrary defaultLibrary] 
													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
}

@end
