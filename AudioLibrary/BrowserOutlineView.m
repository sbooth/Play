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

#import "BrowserOutlineView.h"
#import "BrowserTreeController.h"
#import "AudioStreamCollectionNode.h"
#import "WatchFolderNode.h"
#import "CollectionManager.h"
#import "AudioStream.h"
#import "AudioLibrary.h"
#import "PlaylistInformationSheet.h"
#import "SmartPlaylistInformationSheet.h"
#import "WatchFolderInformationSheet.h"
#import "NSBezierPath_RoundRectMethods.h"
#import "CTGradient.h"
#import "CTBadge.h"

static float widthOffset	= 5.0;
static float heightOffset	= 3.0;

// ========================================
// Completely bogus NSTreeController bindings hack
// ========================================
@interface NSObject (NSTreeControllerBogosity)
- (id) observedObject;
@end

@interface BrowserOutlineView (Private)
- (void) showPlaylistInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void) showSmartPlaylistInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void) showWatchFolderInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end

@implementation BrowserOutlineView

- (void) awakeFromNib
{
	[self registerForDraggedTypes:[NSArray arrayWithObject:AudioStreamPboardType]];
}

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if([menuItem action] == @selector(addToPlayQueue:)) {
		BrowserNode *node = [_browserController selectedNode];
		return ([node isKindOfClass:[AudioStreamCollectionNode class]] && 0 != [(AudioStreamCollectionNode *)node countOfStreams]);
	}
	else if([menuItem action] == @selector(showInformationSheet:)) {
		if([_browserController selectedNodeIsPlaylist]) {
			[menuItem setTitle:NSLocalizedStringFromTable(@"Playlist Info", @"Menus", @"")];
			return YES;
		}
		else if([_browserController selectedNodeIsSmartPlaylist]) {
			[menuItem setTitle:NSLocalizedStringFromTable(@"Smart Playlist Info", @"Menus", @"")];
			return YES;
		}
		else if([_browserController selectedNodeIsWatchFolder]) {
			[menuItem setTitle:NSLocalizedStringFromTable(@"Watch Folder Info", @"Menus", @"")];
			return YES;
		}
		else {
			[menuItem setTitle:NSLocalizedStringFromTable(@"No Selection", @"Menus", @"")];
			return NO;
		}
	}
	else if([menuItem action] == @selector(watchFolderInformation:))
		return [_browserController selectedNodeIsWatchFolder];
	else if([menuItem action] == @selector(remove:))
		return [_browserController canRemove];
	
	return YES;
}

- (void) keyDown:(NSEvent *)event
{
	unichar			key		= [[event charactersIgnoringModifiers] characterAtIndex:0];    
	unsigned int	flags	= [event modifierFlags] & 0x00FF;
    
	if((NSDeleteCharacter == key || NSBackspaceCharacter == key || 0xF728 == key) && 0 == flags)
		[self remove:event];
	else if(0x0020 == key && 0 == flags)
		[[AudioLibrary library] playPause:self];
	else if(NSCarriageReturnCharacter == key && 0 == flags)
		[self doubleClickAction:event];
	else
		[super keyDown:event]; // let somebody else handle the event 
}

- (NSImage *) dragImageForRowsWithIndexes:(NSIndexSet *)dragRows tableColumns:(NSArray *)tableColumns event:(NSEvent*)dragEvent offset:(NSPointPointer)dragImageOffset
{
	BrowserNode *node			= [[self itemAtRow:[dragRows firstIndex]] observedObject];

	if(NO == [node isKindOfClass:[AudioStreamCollectionNode class]])
		return [super dragImageForRowsWithIndexes:dragRows tableColumns:tableColumns event:dragEvent offset:dragImageOffset];
	
	NSImage		*badgeImage		= [[CTBadge systemBadge] smallBadgeForValue:[(AudioStreamCollectionNode *)node countOfStreams]];
	NSSize		badgeSize		= [badgeImage size];
	NSImage		*dragImage		= [[NSImage alloc] initWithSize:NSMakeSize(48, 48)];
	NSImage		*genericIcon	= [NSImage imageNamed:@"Generic"];
	
	[genericIcon setSize:NSMakeSize(48, 48)];
	
	[dragImage lockFocus];
	[badgeImage compositeToPoint:NSMakePoint(48 - badgeSize.width, 48 - badgeSize.height) operation:NSCompositeSourceOver];  
	[genericIcon compositeToPoint:NSZeroPoint operation:NSCompositeDestinationOver fraction:0.75];
	[dragImage unlockFocus];
	
	return [dragImage autorelease];
}

- (NSMenu *) menuForEvent:(NSEvent *)event
{
	NSPoint		location		= [event locationInWindow];
	NSPoint		localLocation	= [self convertPoint:location fromView:nil];
	int			row				= [self rowAtPoint:localLocation];
	
	if(-1 != row) {
		
		if([[self delegate] respondsToSelector:@selector(tableView:shouldSelectRow:)] && [[self delegate] tableView:self shouldSelectRow:row])
			[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		else
			[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		
		if([_browserController selectedNodeIsPlaylist] || [_browserController selectedNodeIsSmartPlaylist])
			return _playlistMenu;
		if([_browserController selectedNodeIsWatchFolder])
			return _watchFolderMenu;
		else if([[_browserController selectedNode] isKindOfClass:[AudioStreamCollectionNode class]])
			return [self menu];
	}
	
	return nil;
}

// Only bad people override private methods!
// TOOD: Remove hardcoded colors
-(void) _drawDropHighlightOnRow:(int)rowIndex
{
	[self lockFocus];
	
	NSRect drawRect = [self rectOfRow:rowIndex];
	
	drawRect.size.width -= widthOffset;
	drawRect.origin.x += widthOffset/2.0;
	
	drawRect.size.height -= heightOffset;
	drawRect.origin.y += heightOffset/2.0;
	
	[[NSColor colorWithCalibratedRed:(172/255.f) green:(193/255.f) blue:(226/255.f) alpha:0.2] set];
	[NSBezierPath fillRoundRectInRect:drawRect radius:7.0];
	
	[[NSColor colorWithCalibratedRed:(7/255.f) green:(82/255.f) blue:(215/255.f) alpha:0.8] set];
	[NSBezierPath setDefaultLineWidth:2.0];
	[NSBezierPath strokeRoundRectInRect:drawRect radius:7.0];
	
	[self unlockFocus];
}

- (id) _highlightColorForCell:(NSCell *)cell
{
	return nil;
}

- (void) highlightSelectionInClipRect:(NSRect)clipRect
{
	int selectedRow = [self selectedRow];
	if(-1 == selectedRow)
		return;
	
	CTGradient	*gradient		= nil;
	NSRect		drawingRect		= [self rectOfRow:[self selectedRow]];

	if(([[self window] firstResponder] == self) && [[self window] isMainWindow] && [[self window] isKeyWindow])
		gradient = [CTGradient sourceListSelectedGradient];
	else
		gradient = [CTGradient sourceListUnselectedGradient];

	[gradient fillRect:drawingRect angle:90];
}

/*- (void) drawBackgroundInClipRect:(NSRect)clipRect
{
	[[self backgroundColor] set];
	NSRectFill(clipRect);
}*/

- (IBAction) addToPlayQueue:(id)sender
{
	BrowserNode *node = [_browserController selectedNode];
	
	if(NO == [node isKindOfClass:[AudioStreamCollectionNode class]]) {
		NSBeep();
		return;
	}
	
	NSArray *streams = [node valueForKey:@"streams"];
	
	if(0 == [streams count]) {
		NSBeep();
		return;
	}
	
	[[AudioLibrary library] sortStreamsAndAddToPlayQueue:streams];
}

- (IBAction) showInformationSheet:(id)sender
{
	if(NO == [_browserController selectedNodeIsPlaylist] && NO == [_browserController selectedNodeIsSmartPlaylist] && NO == [_browserController selectedNodeIsWatchFolder]) {
		NSBeep();
		return;
	}
	
	if([_browserController selectedNodeIsPlaylist]) {
		PlaylistInformationSheet *playlistInformationSheet = [[PlaylistInformationSheet alloc] init];
		
		[playlistInformationSheet setPlaylist:[(PlaylistNode *)[_browserController selectedNode] playlist]];
		
		[[CollectionManager manager] beginUpdate];
		
		[[NSApplication sharedApplication] beginSheet:[playlistInformationSheet sheet] 
									   modalForWindow:[[AudioLibrary library] window] 
										modalDelegate:self 
									   didEndSelector:@selector(showPlaylistInformationSheetDidEnd:returnCode:contextInfo:) 
										  contextInfo:playlistInformationSheet];
	}
	else if([_browserController selectedNodeIsSmartPlaylist]) {
		SmartPlaylistInformationSheet *playlistInformationSheet = [[SmartPlaylistInformationSheet alloc] init];
		
		[playlistInformationSheet setSmartPlaylist:[(SmartPlaylistNode *)[_browserController selectedNode] smartPlaylist]];
		
		[[CollectionManager manager] beginUpdate];
		
		[[NSApplication sharedApplication] beginSheet:[playlistInformationSheet sheet] 
									   modalForWindow:[[AudioLibrary library] window] 
										modalDelegate:self 
									   didEndSelector:@selector(showSmartPlaylistInformationSheetDidEnd:returnCode:contextInfo:) 
										  contextInfo:playlistInformationSheet];
	}
	else if([_browserController selectedNodeIsWatchFolder]) {
		WatchFolderInformationSheet *watchFolderInformationSheet = [[WatchFolderInformationSheet alloc] init];
		
		[watchFolderInformationSheet setWatchFolder:[(WatchFolderNode *)[_browserController selectedNode] watchFolder]];
		
		[[CollectionManager manager] beginUpdate];
		
		[[NSApplication sharedApplication] beginSheet:[watchFolderInformationSheet sheet] 
									   modalForWindow:[[AudioLibrary library] window] 
										modalDelegate:self 
									   didEndSelector:@selector(showWatchFolderInformationSheetDidEnd:returnCode:contextInfo:) 
										  contextInfo:watchFolderInformationSheet];
	}
}

- (IBAction) remove:(id)sender
{
	if(NO == [_browserController canRemove]) {
		NSBeep();
		return;
	}
	
	[[CollectionManager manager] beginUpdate];
	[_browserController remove:sender];
	[[CollectionManager manager] finishUpdate];
}

- (IBAction) doubleClickAction:(id)sender
{
	BrowserNode *node = [_browserController selectedNode];
	
	if(NO == [node isKindOfClass:[AudioStreamCollectionNode class]]) {
		NSBeep();
		return;
	}
	
	NSArray *streams = [node valueForKey:@"streams"];
	
	if(0 == [streams count]) {
		NSBeep();
		return;
	}

	if(0 == [[AudioLibrary library] countOfPlayQueue]) {
		[[AudioLibrary library] sortStreamsAndAddToPlayQueue:streams];
		[[AudioLibrary library] playStreamAtIndex:0];
	}
	else
		[[AudioLibrary library] sortStreamsAndAddToPlayQueue:streams];
}

@end

@implementation BrowserOutlineView (Private)

- (void) showPlaylistInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	PlaylistInformationSheet *playlistInformationSheet = (PlaylistInformationSheet *)contextInfo;
	
	[sheet orderOut:self];
	
	if(NSOKButton == returnCode)
		[[CollectionManager manager] finishUpdate];
	else if(NSCancelButton == returnCode) {
		[[CollectionManager manager] cancelUpdate];
		// TODO: refresh affected objects
	}
	
	[playlistInformationSheet release];
}

- (void) showSmartPlaylistInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	SmartPlaylistInformationSheet *playlistInformationSheet = (SmartPlaylistInformationSheet *)contextInfo;
	
	[sheet orderOut:self];
	
	if(NSOKButton == returnCode)
		[[CollectionManager manager] finishUpdate];
	else if(NSCancelButton == returnCode) {
		[[CollectionManager manager] cancelUpdate];
		// TODO: refresh affected objects
	}
	
	[playlistInformationSheet release];
}

- (void) showWatchFolderInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	WatchFolderInformationSheet *watchFolderInformationSheet = (WatchFolderInformationSheet *)contextInfo;
	
	[sheet orderOut:self];
	
	if(NSOKButton == returnCode)
		[[CollectionManager manager] finishUpdate];
	else if(NSCancelButton == returnCode) {
		[[CollectionManager manager] cancelUpdate];
		// TODO: refresh affected objects
	}
	
	[watchFolderInformationSheet release];
}

@end
