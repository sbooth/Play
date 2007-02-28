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
#import "AudioStream.h"
#import "AudioLibrary.h"

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
		[[AudioLibrary library] streamTableDoubleClicked:self];
	}
	else {
		[super keyDown:event]; // let somebody else handle the event 
	}
}

/*- (NSMenu *) menuForEvent:(NSEvent *)event
{
	NSPoint		location		= [event locationInWindow];
	NSPoint		localLocation	= [self convertPoint:location fromView:nil];
	int			row				= [self rowAtPoint:localLocation];
	
	if(-1 != row) {
		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		return [self menu];
	}
	
	return nil;
}
*/

@end
