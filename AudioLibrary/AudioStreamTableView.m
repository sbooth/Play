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

#import "AudioStreamTableView.h"
#import "AudioStream.h"
#import "AudioLibrary.h"
#import "SecondsFormatter.h"

#import "CTBadge.h"

#define kMaximumStreamsForContextMenuAction 10

@interface AudioStreamTableView (Private)
- (void) drawRowHighlight;
- (void) openWithPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end

@implementation AudioStreamTableView

- (void) awakeFromNib
{
	_highlightedRow = -1;
	[self registerForDraggedTypes:[NSArray arrayWithObjects:AudioStreamTableMovedRowsPboardType, AudioStreamPboardType, NSFilenamesPboardType, NSURLPboardType, iTunesPboardType, nil]];
	NSFormatter *formatter = [[SecondsFormatter alloc] init];
	[[[self tableColumnWithIdentifier:@"duration"] dataCell] setFormatter:formatter];
	[formatter release];
}

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if([menuItem action] == @selector(convertWithMax:)) {
		return (nil != [[NSWorkspace sharedWorkspace] fullPathForApplication:@"Max"] && kMaximumStreamsForContextMenuAction >= [[_streamController selectedObjects] count]);
	}
	else if([menuItem action] == @selector(revealInFinder:)
			|| [menuItem action] == @selector(openWithFinder:)
			|| [menuItem action] == @selector(openWith:)) {
		return (kMaximumStreamsForContextMenuAction >= [[_streamController selectedObjects] count]);
	}
	else {
		return YES;
	}
}

- (void) keyDown:(NSEvent *)event
{
	unichar			key		= [[event charactersIgnoringModifiers] characterAtIndex:0];    
	unsigned int	flags	= [event modifierFlags] & 0x00FF;
    
	if((NSDeleteCharacter == key || NSBackspaceCharacter == key) && 0 == flags) {
		if(-1 == [self selectedRow]) {
			NSBeep();
		}
		else {
			[[AudioLibrary library] removeSelectedStreams:event];
		}
	}
	else {
		[super keyDown:event]; // let somebody else handle the event 
	}
}

- (NSImage *) dragImageForRowsWithIndexes:(NSIndexSet *)dragRows tableColumns:(NSArray *)tableColumns event:(NSEvent*)dragEvent offset:(NSPointPointer)dragImageOffset
{
	if(1 < [dragRows count]) {
		NSImage		*badgeImage		= [[CTBadge systemBadge] smallBadgeForValue:[dragRows count]];
		NSSize		badgeSize		= [badgeImage size];
		NSImage		*dragImage		= [[NSImage alloc] initWithSize:NSMakeSize(48, 48)];
		NSImage		*genericIcon	= [NSImage imageNamed:@"Generic"];

		[genericIcon setSize:NSMakeSize(48, 48)];
		
		[dragImage lockFocus];
		[badgeImage compositeToPoint:NSMakePoint(48 - badgeSize.width, 48 - badgeSize.height) operation:NSCompositeSourceOver];  
		[genericIcon compositeToPoint:NSZeroPoint operation:NSCompositeDestinationOver fraction:0.75];
		[dragImage unlockFocus];
				
		return dragImage;
	}
	return [super dragImageForRowsWithIndexes:dragRows tableColumns:tableColumns event:dragEvent offset:dragImageOffset];
}

- (NSMenu *) menuForEvent:(NSEvent *)event
{
	NSPoint		location		= [event locationInWindow];
	NSPoint		localLocation	= [self convertPoint:location fromView:nil];
	int			row				= [self rowAtPoint:localLocation];
	BOOL		shiftPressed	= 0 != ([event modifierFlags] & NSShiftKeyMask);
//	BOOL		commandPressed	= 0 != ([event modifierFlags] & NSCommandKeyMask);

	if(-1 != row) {
		
		// If a row contained in the selection was right-clicked, don't change anything
		if(NO == [[self selectedRowIndexes] containsIndex:row]) {
			if([[self delegate] respondsToSelector:@selector(tableView:shouldSelectRow:)] && [[self delegate] tableView:self shouldSelectRow:row]) {
				[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:shiftPressed];
			}
			else {
				[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:shiftPressed];
			}			
		}
		
		return [self menu];
	}
	
	return nil;
}

- (void) setHighlightedRow:(int)row
{
	_highlightedRow = row;
}

- (void) setDrawRowHighlight:(BOOL)flag
{
	_drawRowHighlight = flag;
}

- (void) drawRect:(NSRect)drawRect
{
	[self drawRowHighlight];
	[super drawRect:drawRect];
}

- (void) drawBackgroundInClipRect:(NSRect)clipRect
{
	[super drawBackgroundInClipRect:clipRect];
	[self drawRowHighlight];
}

- (IBAction) openWithFinder:(id)sender
{
	NSEnumerator	*enumerator		= [[_streamController selectedObjects] objectEnumerator];
	AudioStream		*stream			= nil;
	NSString		*path			= nil;
	
	while((stream = [enumerator nextObject])) {
		path = [[stream valueForKey:StreamURLKey] path];
		[[NSWorkspace sharedWorkspace] openFile:path];
	}
}

- (IBAction) revealInFinder:(id)sender
{
	NSEnumerator	*enumerator		= [[_streamController selectedObjects] objectEnumerator];
	AudioStream		*stream			= nil;
	NSString		*path			= nil;
	
	while((stream = [enumerator nextObject])) {
		path = [[stream valueForKey:StreamURLKey] path];
		[[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:nil];
	}
}

- (IBAction) convertWithMax:(id)sender
{
	NSEnumerator	*enumerator		= [[_streamController selectedObjects] objectEnumerator];
	AudioStream		*stream			= nil;
	NSString		*path			= nil;
	
	while((stream = [enumerator nextObject])) {
		path = [[stream valueForKey:StreamURLKey] path];
		[[NSWorkspace sharedWorkspace] openFile:path withApplication:@"Max"];
	}
}

- (IBAction) openWith:(id)sender
{
	NSOpenPanel		*panel				= [NSOpenPanel openPanel];
	NSArray			*paths				= NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES);
	NSString		*applicationFolder	= (0 == [paths count] ? nil : [paths objectAtIndex:0]);
	
	[panel beginSheetForDirectory:applicationFolder 
							 file:nil
							types:[NSArray arrayWithObject:@"app"] 
				   modalForWindow:[self window] 
					modalDelegate:self 
				   didEndSelector:@selector(openWithPanelDidEnd:returnCode:contextInfo:) 
					  contextInfo:NULL];	
}

@end

@implementation AudioStreamTableView (Private)

- (void) drawRowHighlight
{
	if(_drawRowHighlight && -1 != _highlightedRow && NO == [[self selectedRowIndexes] containsIndex:_highlightedRow]) {
		NSRect rowRect = [self rectOfRow:_highlightedRow];
		NSImage *highlightImage = [[NSImage alloc] initWithSize:rowRect.size];
		CTGradient *highlightGradient = [CTGradient unifiedNormalGradient];
		
		[highlightImage lockFocus];
		[highlightGradient fillRect:NSMakeRect(0, 0, rowRect.size.width, rowRect.size.height) angle:90];
		[highlightImage unlockFocus];
		
		[highlightImage compositeToPoint:NSMakePoint(rowRect.origin.x, rowRect.origin.y + [highlightImage size].height)
							   operation:NSCompositeSourceAtop
								fraction:1.0];
		
		[highlightImage release];
	}
}

- (void) openWithPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{	
	if(NSOKButton == returnCode) {
		NSEnumerator	*enumerator			= nil;
		AudioStream		*stream				= nil;
		NSString		*path				= nil;
		NSArray			*applications		= [panel filenames];
		NSString		*applicationPath	= nil;
		unsigned		i;
		
		for(i = 0; i < [applications count]; ++i) {
			applicationPath		= [applications objectAtIndex:i];
			enumerator			= [[_streamController selectedObjects] objectEnumerator];
			
			while((stream = [enumerator nextObject])) {
				path = [[stream valueForKey:StreamURLKey] path];
				[[NSWorkspace sharedWorkspace] openFile:path withApplication:applicationPath];
			}
		}
	}
}

@end
