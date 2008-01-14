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

#import <Cocoa/Cocoa.h>
#import <Growl/GrowlApplicationBridge.h>

@class AudioLibrary, AudioScrobbler, iScrobbler, PTKeyCombo, RemoteControl;

@interface PlayApplicationDelegate : NSObject <GrowlApplicationBridgeDelegate>
{
	AudioScrobbler		*_audioScrobbler;
	iScrobbler			*_iScrobbler;
	RemoteControl		*_remoteControl;
}

- (AudioLibrary *) library;
- (AudioScrobbler *) audioScrobbler;
- (iScrobbler *) iScrobbler;

- (IBAction) showPreferences:(id)sender;

@end

@interface PlayApplicationDelegate (HotKeyMethods)
- (void) registerPlayPauseHotKey:(PTKeyCombo *)keyCombo;
- (void) registerPlayNextStreamHotKey:(PTKeyCombo *)keyCombo;
- (void) registerPlayPreviousStreamHotKey:(PTKeyCombo *)keyCombo;
@end

@interface PlayApplicationDelegate (LibraryWrapperMethods)
- (IBAction) playPause:(id)sender;

- (IBAction) playNextStream:(id)sender;
- (IBAction) playPreviousStream:(id)sender;
@end
