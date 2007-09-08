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

#import "SmartPlaylistNode.h"
#import "SmartPlaylist.h"
#import "AudioLibrary.h"
#import "AudioStream.h"

@interface AudioStreamCollectionNode (Private)
- (NSMutableArray *) streamsArray;
@end

@interface SmartPlaylistNode (Private)
- (void) streamsChanged:(NSNotification *)aNotification;
@end

@implementation SmartPlaylistNode

- (id) initWithSmartPlaylist:(SmartPlaylist *)playlist
{
	NSParameterAssert(nil != playlist);
	
	if((self = [super initWithName:[playlist valueForKey:PlaylistNameKey]])) {
		_playlist = [playlist retain];

		[_playlist addObserver:self forKeyPath:PlaylistNameKey options:NSKeyValueObservingOptionNew context:NULL];
		[_playlist addObserver:self forKeyPath:SmartPlaylistPredicateKey options:NSKeyValueObservingOptionNew context:NULL];

		// Register so we can keep ourselves up to date
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(streamsChanged:) 
													 name:AudioStreamDidChangeNotification
												   object:nil];

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
	[_playlist removeObserver:self forKeyPath:PlaylistNameKey];
	[_playlist removeObserver:self forKeyPath:SmartPlaylistPredicateKey];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_playlist release], _playlist = nil;
	
	[super dealloc];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if([keyPath isEqualToString:PlaylistNameKey]) {
		[self setName:[change valueForKey:NSKeyValueChangeNewKey]];
	}
	else if([keyPath isEqualToString:SmartPlaylistPredicateKey]) {
		[self refreshStreams];
	}
}

- (void) setName:(NSString *)name
{
	[_name release];
	_name = [name retain];
	
	// Avoid an infinite loop- this can be called from bindings as well as from observeValueForKeyPath:
	if(NO == [name isEqualToString:[[self smartPlaylist] valueForKey:PlaylistNameKey]]) {
		[[self smartPlaylist] setValue:_name forKey:PlaylistNameKey];
	}
}

- (BOOL) nameIsEditable				{ return YES; }
- (BOOL) streamsAreOrdered			{ return NO; }
- (BOOL) streamReorderingAllowed	{ return NO; }

- (void) loadStreams
{
	// Avoid infinite recursion by using _playlist instead of [self smartPlaylist] here
	_playlistLoadedStreams = YES;
	[_playlist loadStreams];
}

- (void) refreshStreams
{
	[self willChangeValueForKey:@"streams"];
	[_playlist loadStreams];
	[self didChangeValueForKey:@"streams"];
}

- (SmartPlaylist *) smartPlaylist
{
	if(NO == _playlistLoadedStreams) {
		[self loadStreams];		
	}
	return _playlist;
}

#pragma mark KVC Accessor Overrides

- (unsigned)		countOfStreams											{ return [[self smartPlaylist] countOfStreams]; }
- (AudioStream *)	objectInStreamsAtIndex:(unsigned)index					{ return [[self smartPlaylist] objectInStreamsAtIndex:index]; }
- (void)			getStreams:(id *)buffer range:(NSRange)aRange			{ return [[self smartPlaylist] getStreams:buffer range:aRange]; }

#pragma mark KVC Mutators Overrides

- (void) insertObject:(AudioStream *)stream inStreamsAtIndex:(unsigned)index
{}

- (void) removeObjectFromStreamsAtIndex:(unsigned)index
{}

@end

@implementation SmartPlaylistNode (Private)

- (void) streamsChanged:(NSNotification *)aNotification
{
	[self refreshStreams];
}

@end
