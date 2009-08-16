/*
 *  $Id$
 *
 *  Copyright (C) 2005 - 2009 Stephen F. Booth <me@sbooth.org>
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

#import "HotKeyPreferencesController.h"
#import "PTKeyCombo.h"
#import "PlayApplicationDelegate.h"

#import "ShortcutRecorder/ShortcutRecorder.h"

@implementation HotKeyPreferencesController

- (id) init
{
	if((self = [super initWithWindowNibName:@"HotKeyPreferences"])) {
	}
	return self;
}

- (void) awakeFromNib
{
	NSDictionary	*dictionary		= [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"playPauseHotKey"];
	PTKeyCombo		*keyCombo		= nil;
	KeyCombo		combo;

	if(nil != dictionary) {
		keyCombo = [[PTKeyCombo alloc] initWithPlistRepresentation:dictionary];
		combo.flags = [_playPauseShortcutRecorder carbonToCocoaFlags:[keyCombo modifiers]];
		combo.code	= [keyCombo keyCode];
		[_playPauseShortcutRecorder setKeyCombo:combo];
		[keyCombo release];
	}

	dictionary = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"playNextStreamHotKey"];
	
	if(nil != dictionary) {
		keyCombo = [[PTKeyCombo alloc] initWithPlistRepresentation:dictionary];
		combo.flags = [_nextStreamShortcutRecorder carbonToCocoaFlags:[keyCombo modifiers]];
		combo.code	= [keyCombo keyCode];
		[_nextStreamShortcutRecorder setKeyCombo:combo];
		[keyCombo release];
	}

	dictionary = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"playPreviousStreamHotKey"];
	
	if(nil != dictionary) {
		keyCombo = [[PTKeyCombo alloc] initWithPlistRepresentation:dictionary];
		combo.flags = [_previousStreamShortcutRecorder carbonToCocoaFlags:[keyCombo modifiers]];
		combo.code	= [keyCombo keyCode];
		[_previousStreamShortcutRecorder setKeyCombo:combo];
		[keyCombo release];
	}
}

@end

@implementation HotKeyPreferencesController (ShortcutRecorderDelegateMethods)

- (void) shortcutRecorder:(SRRecorderControl *)aRecorder keyComboDidChange:(KeyCombo)newKeyCombo
{
	if(aRecorder == _playPauseShortcutRecorder) {
		PTKeyCombo *keyCombo = [PTKeyCombo keyComboWithKeyCode:[aRecorder keyCombo].code
													 modifiers:[aRecorder cocoaToCarbonFlags:[aRecorder keyCombo].flags]];
		[[NSUserDefaults standardUserDefaults] setObject:[keyCombo plistRepresentation] forKey:@"playPauseHotKey"];

		[(PlayApplicationDelegate *)[[NSApplication sharedApplication] delegate] registerPlayPauseHotKey:keyCombo];
	}
	else if(aRecorder == _nextStreamShortcutRecorder) {
		PTKeyCombo *keyCombo = [PTKeyCombo keyComboWithKeyCode:[aRecorder keyCombo].code
													 modifiers:[aRecorder cocoaToCarbonFlags:[aRecorder keyCombo].flags]];
		[[NSUserDefaults standardUserDefaults] setObject:[keyCombo plistRepresentation] forKey:@"playNextStreamHotKey"];
		
		[(PlayApplicationDelegate *)[[NSApplication sharedApplication] delegate] registerPlayNextStreamHotKey:keyCombo];
	}
	else if(aRecorder == _previousStreamShortcutRecorder) {
		PTKeyCombo *keyCombo = [PTKeyCombo keyComboWithKeyCode:[aRecorder keyCombo].code
													 modifiers:[aRecorder cocoaToCarbonFlags:[aRecorder keyCombo].flags]];
		[[NSUserDefaults standardUserDefaults] setObject:[keyCombo plistRepresentation] forKey:@"playPreviousStreamHotKey"];
		
		[(PlayApplicationDelegate *)[[NSApplication sharedApplication] delegate] registerPlayPreviousStreamHotKey:keyCombo];
	}
}

@end
