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

#import "AudioLibraryWindow.h"
#import "AudioLibrary.h"

@implementation AudioLibraryWindow

- (void) keyDown:(NSEvent *)event
{
	unichar			key		= [[event charactersIgnoringModifiers] characterAtIndex:0];    
	unsigned int	flags	= [event modifierFlags] & 0x00FF;
		
	if(0x0020 == key && 0 == flags) {
		[[AudioLibrary library] playPause:self];
	}
	else if(NSCarriageReturnCharacter == key && 0 == flags) {
		[[AudioLibrary library] playSelection:self];
	}
	else if(0xf702 == key && 0 == flags) {
		[[AudioLibrary library] skipBackward:self];
	}
	else if(0xf703 == key && 0 == flags) {
		[[AudioLibrary library] skipForward:self];
	}
	else {
		[super keyDown:event]; // let somebody else handle the event 
	}
}

@end
