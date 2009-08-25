/*
 *  $Id$
 *
 *  Copyright (C) 2005 - 2007 Stephen F. Booth <me@sbooth.org>
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

#import "BrowserTreeController.h"
#import "CollectionManager.h"
#import "AudioStreamManager.h"
#import "BrowserNode.h"
#import "LibraryNode.h"
#import "PlaylistNode.h"
#import "SmartPlaylistNode.h"
#import "WatchFolderNode.h"
#import "AudioStream.h"
#import "Playlist.h"
#import "SmartPlaylist.h"

// ========================================
// Pboard Types
// ========================================
NSString * const PlaylistPboardType						= @"org.sbooth.Play.Playlist.PboardType";
NSString * const SmartPlaylistPboardType				= @"org.sbooth.Play.SmartPlaylist.PboardType";

// ========================================
// Completely bogus NSTreeController bindings hack
// ========================================
@interface NSObject (NSTreeControllerBogosity)
- (id) observedObject;
@end

@implementation BrowserTreeController

// An outline view data source MUST implement these methods
// Just return 0 and nil to fall back to bindings
#pragma mark Required data source methods

- (int) outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	return 0;
}

- (BOOL) outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return NO;
}

- (id) outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
	return nil;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	return nil;
}

#pragma mark Overrides

- (BrowserNode *) selectedNode
{
	NSArray *selectedObjects = [self selectedObjects];

	return (0 == [selectedObjects count] ? nil : [selectedObjects objectAtIndex:0]);
}

- (BOOL) selectedNodeIsLibrary
{
	return [[self selectedNode] isKindOfClass:[LibraryNode class]];
}

- (BOOL) selectedNodeIsPlaylist
{
	return [[self selectedNode] isKindOfClass:[PlaylistNode class]];
}

- (BOOL) selectedNodeIsSmartPlaylist
{
	return [[self selectedNode] isKindOfClass:[SmartPlaylistNode class]];
}

- (BOOL) selectedNodeIsWatchFolder
{
	return [[self selectedNode] isKindOfClass:[WatchFolderNode class]];
}

- (BOOL) canRemove
{
	for(BrowserNode *node in [self selectedObjects]) {
		if([node isKindOfClass:[PlaylistNode class]] || [node isKindOfClass:[SmartPlaylistNode class]] || [node isKindOfClass:[WatchFolderNode class]])
			return YES;
	}
	
	return NO;
}

- (BOOL) canInsert
{
	return YES;
}

#pragma mark Drag and Drop

- (BOOL) outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
	NSEnumerator		*enumerator		= [items objectEnumerator];
	BrowserNode			*node			= nil;
	Playlist			*playlist		= nil;
	SmartPlaylist		*smartPlaylist	= nil;
	NSArray				*streams		= nil;
	NSMutableArray		*objectIDs		= [NSMutableArray array];
	AudioStream			*stream			= nil;
	BOOL				success			= NO;
	unsigned			i;
	
	while((node = [[enumerator nextObject] observedObject])) {

		if([node isKindOfClass:[PlaylistNode class]]) {
			playlist	= [(PlaylistNode *)node playlist];
			streams		= [playlist streams];

			for(i = 0; i < [streams count]; ++i) {
				stream = [streams objectAtIndex:i];				
				[objectIDs addObject:[stream valueForKey:ObjectIDKey]];
			}
			
			[pboard declareTypes:[NSArray arrayWithObjects:PlaylistPboardType, AudioStreamPboardType, nil] owner:nil];
			[pboard addTypes:[NSArray arrayWithObjects:PlaylistPboardType, AudioStreamPboardType, nil] owner:nil];
			
			success = [pboard setPropertyList:[playlist valueForKey:ObjectIDKey] forType:PlaylistPboardType];
			success &= [pboard setPropertyList:objectIDs forType:AudioStreamPboardType];
		}
		else if([node isKindOfClass:[SmartPlaylistNode class]]) {
			smartPlaylist	= [(SmartPlaylistNode *)node smartPlaylist];
			streams			= [smartPlaylist streams];
			
			for(i = 0; i < [streams count]; ++i) {
				stream = [streams objectAtIndex:i];
				[objectIDs addObject:[stream valueForKey:ObjectIDKey]];
			}
			
			[pboard declareTypes:[NSArray arrayWithObjects:SmartPlaylistPboardType, AudioStreamPboardType, nil] owner:nil];
			[pboard addTypes:[NSArray arrayWithObjects:SmartPlaylistPboardType, AudioStreamPboardType, nil] owner:nil];
			
			success = [pboard setPropertyList:[smartPlaylist valueForKey:ObjectIDKey] forType:SmartPlaylistPboardType];
			success &= [pboard setPropertyList:objectIDs forType:AudioStreamPboardType];
		}
		else if([node isKindOfClass:[AudioStreamCollectionNode class]]) {
			for(i = 0; i < [(AudioStreamCollectionNode *)node countOfStreams]; ++i) {
				stream = [(AudioStreamCollectionNode *)node objectInStreamsAtIndex:i];
				[objectIDs addObject:[stream valueForKey:ObjectIDKey]];
			}
			
			[pboard declareTypes:[NSArray arrayWithObjects:AudioStreamPboardType, nil] owner:nil];
			[pboard addTypes:[NSArray arrayWithObjects:AudioStreamPboardType, nil] owner:nil];
			
			success = [pboard setPropertyList:objectIDs forType:AudioStreamPboardType];
		}
		
	}
	
	return success;
}

- (NSDragOperation) outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)index
{
	BrowserNode *node = [item observedObject];
	
	return ([node isKindOfClass:[PlaylistNode class]] ? NSDragOperationCopy : NSDragOperationNone);
}

- (BOOL) outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)index
{
	BrowserNode		*node		= [item observedObject];
	NSArray			*objectIDs	= [[info draggingPasteboard] propertyListForType:AudioStreamPboardType];

	if([node isKindOfClass:[PlaylistNode class]]) {
		[[(PlaylistNode *)node playlist] addStreamsWithIDs:objectIDs];		
		return YES;
	}
		
	return NO;
}

@end
