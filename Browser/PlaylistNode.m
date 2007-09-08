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

#import "PlaylistNode.h"
#import "Playlist.h"

@interface AudioStreamCollectionNode (Private)
- (NSMutableArray *) streamsArray;
@end

@implementation PlaylistNode

- (id) initWithPlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	
	if((self = [super initWithName:[playlist valueForKey:PlaylistNameKey]])) {
		_playlist = [playlist retain];
		[_playlist addObserver:self forKeyPath:PlaylistNameKey options:NSKeyValueObservingOptionNew context:NULL];
	}
	return self;
}

- (void) dealloc
{
	[_playlist removeObserver:self forKeyPath:PlaylistNameKey];
	[_playlist removeObserver:self forKeyPath:PlaylistStreamsKey];

	[_playlist release], _playlist = nil;
	
	[super dealloc];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if([keyPath isEqualToString:PlaylistNameKey]) {
		[self setName:[change valueForKey:NSKeyValueChangeNewKey]];
	}
	else if([keyPath isEqualToString:PlaylistStreamsKey]) {
		[self refreshStreams];
	}
}

- (void) setName:(NSString *)name
{
	[_name release];
	_name = [name retain];

	// Avoid an infinite loop- this can be called from bindings as well as from observeValueForKeyPath:
	if(NO == [name isEqualToString:[[self playlist] valueForKey:PlaylistNameKey]]) {
		[[self playlist] setValue:_name forKey:PlaylistNameKey];
	}
}

- (BOOL) nameIsEditable				{ return YES; }
- (BOOL) streamsAreOrdered			{ return YES; }
- (BOOL) streamReorderingAllowed	{ return YES; }

- (void) loadStreams
{
	// Avoid infinite recursion by using _playlist instead of [self playlist] here
	_playlistLoadedStreams = YES;
	[_playlist loadStreams];

	// Now that the streams are loaded, observe changes in them
	[_playlist addObserver:self forKeyPath:@"streams" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:NULL];
}

- (void) refreshStreams
{
	[self willChangeValueForKey:@"streams"];
	[self didChangeValueForKey:@"streams"];
}

- (Playlist *) playlist
{
	if(NO == _playlistLoadedStreams) {
		[self loadStreams];		
	}
	return _playlist;
}

#pragma mark KVC Accessor Overrides

- (unsigned)		countOfStreams											{ return [[self playlist] countOfStreams]; }
- (AudioStream *)	objectInStreamsAtIndex:(unsigned)index					{ return [[self playlist] objectInStreamsAtIndex:index]; }
- (void)			getStreams:(id *)buffer range:(NSRange)aRange			{ return [[self playlist] getStreams:buffer range:aRange]; }

#pragma mark KVC Mutators Overrides

- (void) insertObject:(AudioStream *)stream inStreamsAtIndex:(unsigned)index
{
	NSAssert([self canInsertStream], @"Attempt to insert a stream in an immutable PlaylistNode");
	[[self playlist] insertObject:stream inStreamsAtIndex:index];
}

- (void) removeObjectFromStreamsAtIndex:(unsigned)index
{
	NSAssert([self canRemoveStream], @"Attempt to remove a stream from an immutable PlaylistNode");	
	[[self playlist] removeObjectFromStreamsAtIndex:index];
}

@end
