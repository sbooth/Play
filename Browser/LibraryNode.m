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
#import "AudioStream.h"

@implementation LibraryNode

- (id) init
{
	if((self = [super init])) {
		[self setName:NSLocalizedStringFromTable(@"Library", @"General", @"")];
//		[[foo bar] addObserver:forKeyPath:options:context:];
	}
	return self;
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	// The streams in the library changed, so refresh them
	[self refreshData];
}

- (void) refreshData
{
	 [self willChangeValueForKey:@"streams"];
	 [_streams release];
	 _streams = [[[CollectionManager streamManager] streams] mutableCopy];
	 [self didChangeValueForKey:@"streams"];
}

- (void) didInsertStream:(AudioStream *)stream
{
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamAddedToLibraryNotification 
														object:[AudioLibrary library] 
													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
}

- (void) willRemoveStream:(AudioStream *)stream
{
	if([stream isPlaying]) {
		[[AudioLibrary library] stop:self];
	}
	
	// To keep the database and in-memory representation in sync, remove the 
	// stream from the database first
	[stream delete];
}

- (void) didRemoveStream:(AudioStream *)stream
{
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamRemovedFromLibraryNotification 
														object:[AudioLibrary library] 
													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
}

@end
