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

#import "WatchFolderNode.h"
#import "WatchFolder.h"
#import "AudioLibrary.h"
#import "CollectionManager.h"

@interface AudioStreamCollectionNode (Private)
- (NSMutableArray *) streamsArray;
@end

@implementation WatchFolderNode

- (id) initWithWatchFolder:(WatchFolder *)folder
{
	NSParameterAssert(nil != folder);

	if((self = [super initWithName:[folder valueForKey:WatchFolderNameKey]])) {
		_watchFolder = [folder retain];
		
		NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:[[_watchFolder valueForKey:WatchFolderURLKey] path]];
		[icon setSize:NSMakeSize(16.0, 16.0)];
		[self setIcon:icon];
		
		[_watchFolder addObserver:self forKeyPath:WatchFolderNameKey options:NSKeyValueObservingOptionNew context:NULL];
		[_watchFolder addObserver:self forKeyPath:WatchFolderURLKey options:NSKeyValueObservingOptionNew context:NULL];
	}
	return self;
}

- (void) dealloc
{
	[_watchFolder removeObserver:self forKeyPath:WatchFolderNameKey];
	[_watchFolder removeObserver:self forKeyPath:WatchFolderURLKey];
	[_watchFolder removeObserver:self forKeyPath:WatchFolderStreamsKey];
	
	[super dealloc];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if([keyPath isEqualToString:WatchFolderNameKey]) {
		[self setName:[change valueForKey:NSKeyValueChangeNewKey]];
	}
	if([keyPath isEqualToString:WatchFolderURLKey]) {
		[self willChangeValueForKey:@"streams"];
		[_watchFolder loadStreams];
		[self didChangeValueForKey:@"streams"];
	}
	else if([keyPath isEqualToString:WatchFolderStreamsKey]) {
		[self refreshStreams];
	}
}

- (void) setName:(NSString *)name
{
	[_name release];
	_name = [name retain];
	
	// Avoid an infinite loop- this can be called from bindings as well as from observeValueForKeyPath:
	if(NO == [name isEqualToString:[[self watchFolder] valueForKey:WatchFolderNameKey]]) {
		[[self watchFolder] setValue:_name forKey:WatchFolderNameKey];
	}
}

- (BOOL) nameIsEditable				{ return YES; }
- (BOOL) streamsAreOrdered			{ return NO; }
- (BOOL) streamReorderingAllowed	{ return NO; }

- (void) loadStreams
{
	// Avoid infinite recursion by using _watchFolder instead of [self watchFolder] here
	_watchFolderLoadedStreams = YES;
	[_watchFolder loadStreams];
	
	// Now that the streams are loaded, observe changes in them
	[_watchFolder addObserver:self forKeyPath:WatchFolderStreamsKey options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:NULL];
}

- (void) refreshStreams
{
	[self willChangeValueForKey:@"streams"];
	[self didChangeValueForKey:@"streams"];
}

- (WatchFolder *) watchFolder
{
	if(NO == _watchFolderLoadedStreams) {
		[self loadStreams];		
	}
	return _watchFolder;
}

#pragma mark KVC Accessor Overrides

- (unsigned)		countOfStreams											{ return [[self watchFolder] countOfStreams]; }
- (AudioStream *)	objectInStreamsAtIndex:(unsigned)index					{ return [[self watchFolder] objectInStreamsAtIndex:index]; }
- (void)			getStreams:(id *)buffer range:(NSRange)aRange			{ return [[self watchFolder] getStreams:buffer range:aRange]; }

#pragma mark KVC Mutators Overrides

- (void) insertObject:(AudioStream *)stream inStreamsAtIndex:(unsigned)index
{}

- (void) removeObjectFromStreamsAtIndex:(unsigned)index
{}

@end
