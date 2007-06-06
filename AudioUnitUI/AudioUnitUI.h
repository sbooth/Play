/*
 *  $Id$
 *
 *  Copyright (C) 2007 Stephen F. Booth <me@sbooth.org>
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
#include <AudioToolbox/AudioToolbox.h>
#include <CoreAudioKit/CoreAudioKit.h>

@interface AudioUnitUI : NSWindowController
{
	IBOutlet NSDrawer *_presetsDrawer;

	AudioUnit _audioUnit;
	AUEventListenerRef _auEventListener;

	NSString *_auNameAndManufacturer;
	NSString *_auManufacturer;
	NSString *_auName;
	
	NSString *_auPresentPresetName;
	
	AUGenericView *_auView;
	NSMutableArray *_presetsTree;
}

// The AudioUnit to work with
- (AudioUnit) audioUnit;
- (void) setAudioUnit:(AudioUnit)audioUnit;

// Save the current settings as a preset 
- (IBAction) savePreset:(id)sender;

// Toggle whether the AU is bypassed
- (IBAction) toggleBypassEffect:(id)sender;

// Save/Restore settings from a preset file in a non-standard location
- (IBAction) savePresetToFile:(id)sender;
- (IBAction) loadPresetFromFile:(id)sender;

// Load a factory preset
- (void) loadFactoryPresetNumber:(NSNumber *)presetNumber presetName:(NSString *)presetName;

// Save/Restore presets to/from a specific URL
- (void) loadCustomPresetFromURL:(NSURL *)presetURL;
- (void) saveCustomPresetToURL:(NSURL *)presetURL presetName:(NSString *)presetName;

// Not generally used
- (void) selectPresetNumber:(NSNumber *)presetNumber presetName:(NSString *)presetName presetPath:(NSString *)presetPath;

@end
