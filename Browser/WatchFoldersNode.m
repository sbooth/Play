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

#import "WatchFoldersNode.h"
#import "CollectionManager.h"
#import "WatchFolderManager.h"
#import "WatchFolder.h"
#import "WatchFolderNode.h"

@interface WatchFoldersNode (Private)
- (void) loadChildren;
- (WatchFolderNode *) findChildForWatchFolder:(WatchFolder *)folder;
@end

@implementation WatchFoldersNode

- (id) init
{
	if((self = [super initWithName:NSLocalizedStringFromTable(@"Watch Folders", @"Library", @"")])) {
		[self loadChildren];
		[[[CollectionManager manager] watchFolderManager] addObserver:self 
														   forKeyPath:@"watchFolders"
															  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
															  context:nil];
	}
	return self;
}

- (void) dealloc
{
	[[[CollectionManager manager] watchFolderManager] removeObserver:self forKeyPath:@"watchFolders"];
	
	[super dealloc];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	NSArray			*old			= [change valueForKey:NSKeyValueChangeOldKey];
	NSArray			*new			= [change valueForKey:NSKeyValueChangeNewKey];
	int				changeKind		= [[change valueForKey:NSKeyValueChangeKindKey] intValue];
	BOOL			needsSort		= NO;
	BrowserNode		*node			= nil;
	WatchFolder		*folder			= nil;
	unsigned		i;
	
	switch(changeKind) {
		case NSKeyValueChangeInsertion:
			for(folder in new) {
				node = [[WatchFolderNode alloc] initWithWatchFolder:folder];
				[self addChild:node];
			}
			break;
			
		case NSKeyValueChangeRemoval:
			for(folder in old) {
				node = [self findChildForWatchFolder:folder];
				if(nil != node) {
					[self removeChild:node];
				}
			}
			break;
			
		case NSKeyValueChangeSetting:
			for(i = 0; i < [new count]; ++i) {
				folder = [old objectAtIndex:i];
				node = [self findChildForWatchFolder:folder];
				if(nil != node) {
					node = [new objectAtIndex:i];
					[node setName:[folder valueForKey:WatchFolderNameKey]];
				}
			}
			break;
			
		case NSKeyValueChangeReplacement:
			NSLog(@"WatchFoldersNode REPLACEMENT !! (?)");
			break;
	}
	
	if(needsSort) {
		[self sortChildren];
	}
}

#pragma mark KVC Mutator Overrides

- (void) removeObjectFromChildrenAtIndex:(unsigned)index
{
	WatchFolderNode *node = [[self childAtIndex:index] retain];
	
	[super removeObjectFromChildrenAtIndex:index];
	[[node watchFolder] delete];
	[node release];
}

@end

@implementation WatchFoldersNode (Private)

- (void) loadChildren
{
	NSArray			*watchFolders	= [[[CollectionManager manager] watchFolderManager] watchFolders];
	WatchFolder		*folder			= nil;
	WatchFolderNode	*node			= nil;
	
	[self willChangeValueForKey:@"children"];
	[_children makeObjectsPerformSelector:@selector(setParent:) withObject:nil];
	[_children removeAllObjects];
	for(folder in watchFolders) {
		node = [[WatchFolderNode alloc] initWithWatchFolder:folder];
		[node setParent:self];
		[_children addObject:[node autorelease]];
	}
	[self didChangeValueForKey:@"children"];
}

- (WatchFolderNode *) findChildForWatchFolder:(WatchFolder *)folder
{
	// Breadth-first search
	WatchFolderNode 	*match 		= nil;
	
	for(WatchFolderNode *child in _children) {
		if([[child watchFolder] isEqual:folder]) {
			match = child;
			break;
		}
	}
		
	return match;
}

@end
