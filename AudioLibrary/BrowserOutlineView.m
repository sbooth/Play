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
#import "AudioStream.h"
#import "AudioLibrary.h"
#import "NSBezierPath_RoundRectMethods.h"
#import "CTGradient.h"

static float widthOffset	= 5.0;
static float heightOffset	= 3.0;

@implementation BrowserOutlineView

- (void) awakeFromNib
{
	[self registerForDraggedTypes:[NSArray arrayWithObject:AudioStreamPboardType]];
}

- (void) keyDown:(NSEvent *)event
{
	unichar			key		= [[event charactersIgnoringModifiers] characterAtIndex:0];    
	unsigned int	flags	= [event modifierFlags] & 0x00FF;
    
	if((NSDeleteCharacter == key || NSBackspaceCharacter == key) && 0 == flags) {
		if(-1 == [self selectedRow] || NO == [_browserController canRemove]) {
			NSBeep();
		}
		else {
			[_browserController remove:event];
		}
	}
	else if(0x0020 == key && 0 == flags) {
		[[AudioLibrary library] playPause:self];
	}
	else if(NSCarriageReturnCharacter == key && 0 == flags) {
		[[AudioLibrary library] browserViewDoubleClicked:self];
	}
	else {
		[super keyDown:event]; // let somebody else handle the event 
	}
}

- (NSMenu *) menuForEvent:(NSEvent *)event
{
	NSPoint		location		= [event locationInWindow];
	NSPoint		localLocation	= [self convertPoint:location fromView:nil];
	int			row				= [self rowAtPoint:localLocation];
	
	if(-1 != row) {
		
		if([[self delegate] respondsToSelector:@selector(tableView:shouldSelectRow:)]) {
			if([[self delegate] tableView:self shouldSelectRow:row]) {
				[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
			}
		}
		else {
			[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		}
				
		if([_browserController selectedNodeIsPlaylist] || [_browserController selectedNodeIsSmartPlaylist]) {
			return _playlistMenu;
		}
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
	if(-1 == selectedRow) {
		return;
	}
	
	CTGradient	*gradient		= nil;
	NSRect		drawingRect		= [self rectOfRow:[self selectedRow]];

	if(([[self window] firstResponder] == self) && [[self window] isMainWindow] && [[self window] isKeyWindow]) {
		gradient = [CTGradient sourceListSelectedGradient];
	}
	else {
		gradient = [CTGradient sourceListUnselectedGradient];
	}

	[gradient fillRect:drawingRect angle:90];
}

/*- (void) drawBackgroundInClipRect:(NSRect)clipRect
{
	[[self backgroundColor] set];
	NSRectFill(clipRect);
}*/

@end
