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

#import "PlayQueueTableView.h"
#import "AudioLibrary.h"
#import "CollectionManager.h"
#import "SecondsFormatter.h"
#import "CTGradient.h"

@interface AudioLibrary (Private)
- (unsigned) playbackIndex;
@end

@interface PlayQueueTableView (Private)
- (void) drawRowHighlight;
@end

@implementation PlayQueueTableView

- (void) awakeFromNib
{
	[self registerForDraggedTypes:[NSArray arrayWithObjects:PlayQueueTableMovedRowsPboardType, AudioStreamPboardType, NSFilenamesPboardType, NSURLPboardType, iTunesPboardType, nil]];
	NSFormatter *formatter = [[SecondsFormatter alloc] init];
	[[[self tableColumnWithIdentifier:@"duration"] dataCell] setFormatter:formatter];
	[formatter release];
	_highlightedRow = -1;
}

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{	
	if([menuItem action] == @selector(addToPlayQueue:)) {
		return NO;
	}

	return [super validateMenuItem:menuItem];
}

- (IBAction) remove:(id)sender
{
	if(NO == [_streamController canRemove] || 0 == [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}

	// If removing the currently playing stream, stop playback
	if([[_streamController selectionIndexes] containsIndex:[[AudioLibrary library] playbackIndex]]) {
		[[AudioLibrary library] stop:sender];
	}
	
	[[CollectionManager manager] beginUpdate];
	[_streamController remove:sender];
	[[CollectionManager manager] finishUpdate];
}

- (IBAction) doubleClickAction:(id)sender
{
	if(0 == [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
	[[AudioLibrary library] playStreamAtIndex:[_streamController selectionIndex]];
}

- (void) setHighlightedRow:(int)row
{
	_highlightedRow = row;
}

- (void) drawRect:(NSRect)drawRect
{
	[self drawRowHighlight];
	[super drawRect:drawRect];
	
	// Draw the empty message
	if(0 == [self numberOfRows]) {
		NSRect	rect	= [self frame];
		float	deltaY	= rect.size.height / 2;
		float	deltaX	= rect.size.width / 2;

		rect.origin.y		+= deltaY / 2;
		rect.origin.x		+= deltaX / 2;
		rect.size.height	-= deltaY;
		rect.size.width		-= deltaX;
		
		if(NO == NSIsEmptyRect(rect)) {
			NSDictionary	*attributes		= nil;
			NSString		*empty			= NSLocalizedStringFromTable(@"Play Queue Empty", @"Library", @"");
			NSRect			bounds			= NSZeroRect;
			float			fontSize		= 36;
			
			do {
				attributes = [NSDictionary dictionaryWithObjectsAndKeys:
					[NSFont systemFontOfSize:fontSize], NSFontAttributeName,
					[[NSColor blackColor] colorWithAlphaComponent:0.75], NSForegroundColorAttributeName,
					nil];
				
				bounds = [empty boundingRectWithSize:rect.size options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes];
				
				fontSize -= 2;
				
			} while(bounds.size.width > rect.size.width || bounds.size.height > rect.size.height);
			
			NSRect drawRect = NSInsetRect(rect, (rect.size.width - bounds.size.width) / 2, (rect.size.height - bounds.size.height) / 2);

			[empty drawWithRect:drawRect options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes];
		}
	}
}

- (void) drawBackgroundInClipRect:(NSRect)clipRect
{
	[super drawBackgroundInClipRect:clipRect];
	[self drawRowHighlight];
}

@end

@implementation PlayQueueTableView (Private)

- (void) drawRowHighlight
{
	if(-1 != _highlightedRow && NO == [[self selectedRowIndexes] containsIndex:_highlightedRow]) {
		NSRect rowRect = [self rectOfRow:_highlightedRow];
		if(NSIsEmptyRect(rowRect)) {
			return;
		}
		
		NSImage *highlightImage = [[NSImage alloc] initWithSize:rowRect.size];
//		CTGradient *highlightGradient = [CTGradient unifiedNormalGradient];
 		CTGradient *highlightGradient = [CTGradient aquaNormalGradient];
		
		[highlightImage lockFocus];
		[highlightGradient fillRect:NSMakeRect(0, 0, rowRect.size.width, rowRect.size.height) angle:90];
		[highlightImage unlockFocus];
		
		[highlightImage compositeToPoint:NSMakePoint(rowRect.origin.x, rowRect.origin.y + [highlightImage size].height)
							   operation:NSCompositeSourceAtop
								fraction:1.0];
		
		[highlightImage release];
	}
}

@end
