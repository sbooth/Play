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

#import "PreferencesController.h"

#import "UtilityFunctions.h"

// ========================================
// The global instance
// ========================================
static PreferencesController *sharedPreferences = nil;

NSString * const	GeneralPreferencesToolbarItemIdentifier						= @"org.sbooth.Play.Preferences.Toolbar.General";
NSString * const	HotKeyPreferencesToolbarItemIdentifier						= @"org.sbooth.Play.Preferences.Toolbar.HotKey";
NSString * const	OutputPreferencesToolbarItemIdentifier						= @"org.sbooth.Play.Preferences.Toolbar.Output";
NSString * const	DSPPreferencesToolbarItemIdentifier							= @"org.sbooth.Play.Preferences.Toolbar.DSP";
NSString * const	AdvancedPreferencesToolbarItemIdentifier					= @"org.sbooth.Play.Preferences.Toolbar.Advanced";

@interface PreferencesController (Private)
- (IBAction) selectPreferencePaneUsingToolbar:(id)sender;
@end

@implementation PreferencesController

+ (PreferencesController *) sharedPreferences
{
	@synchronized(self) {
		if(nil == sharedPreferences) {
			// assignment not done here
			[[self alloc] init];
		}
	}
	return sharedPreferences;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == sharedPreferences) {
			// assignment and return on first allocation
            sharedPreferences = [super allocWithZone:zone];
			return sharedPreferences;
        }
    }
    return nil;
}

- (id) init
{
	if((self = [super initWithWindowNibName:@"Preferences"])) {
		return self;
	}
	return nil;
}

- (id)			copyWithZone:(NSZone *)zone						{ return self; }
- (id)			retain											{ return self; }
- (unsigned)	retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void)		release											{ /* do nothing */ }
- (id)			autorelease										{ return self; }

- (void) awakeFromNib
{
    NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"org.sbooth.Play.Preferences.Toolbar"];
    [toolbar setAllowsUserCustomization:NO];
    
    [toolbar setDelegate:self];
	
	[[self window] setShowsToolbarButton:NO];
    [[self window] setToolbar:toolbar];
	[toolbar release];
}

- (void) windowDidLoad
{
	NSToolbar	*toolbar			= [[self window] toolbar];	
	NSString	*itemIdentifier		= [[NSUserDefaults standardUserDefaults] stringForKey:@"selectedPreferencePane"];

	if(nil != itemIdentifier)
		[toolbar setSelectedItemIdentifier:itemIdentifier];
	else if(nil != [toolbar visibleItems] && 0 != [[toolbar visibleItems] count])
		[toolbar setSelectedItemIdentifier:[[[toolbar visibleItems] objectAtIndex:0] itemIdentifier]];
	else if(nil != [toolbar items] && 0 != [[toolbar items] count])
		[toolbar setSelectedItemIdentifier:[[[toolbar items] objectAtIndex:0] itemIdentifier]];
	else
		[toolbar setSelectedItemIdentifier:GeneralPreferencesToolbarItemIdentifier];
	[self selectPreferencePaneUsingToolbar:self];
	
	[self setShouldCascadeWindows:NO];
	[[self window] center];
}

- (void) selectPreferencePane:(NSString *)itemIdentifier
{
	NSParameterAssert(nil != itemIdentifier);
	
	NSToolbar				*toolbar;
	Class					prefPaneClass;
	NSWindowController		*prefPaneObject;
	NSView					*prefView, *oldContentView;
	float					toolbarHeight, windowHeight, newWindowHeight, newWindowWidth;
	NSRect					windowFrame, newFrameRect, newWindowFrame;
	NSWindow				*myWindow;
	
	myWindow				= [self window];
	oldContentView			= [myWindow contentView];
	toolbar					= [myWindow toolbar];
	prefPaneClass			= NSClassFromString([[[itemIdentifier componentsSeparatedByString:@"."] lastObject] stringByAppendingString:@"PreferencesController"]);
	prefPaneObject			= [[prefPaneClass alloc] init];
	prefView				= [[prefPaneObject window] contentView];
	windowHeight			= NSHeight([[myWindow contentView] frame]);
	
	
	// Select the appropriate toolbar item if it isn't already
	if(NO == [[[[self window] toolbar] selectedItemIdentifier] isEqualToString:itemIdentifier])
		[[[self window] toolbar] setSelectedItemIdentifier:itemIdentifier];

	// Calculate toolbar height
	if([toolbar isVisible]) {
		windowFrame = [NSWindow contentRectForFrameRect:[myWindow frame] styleMask:[myWindow styleMask]];
		toolbarHeight = NSHeight(windowFrame) - windowHeight;
	}
	
	newWindowHeight		= NSHeight([prefView frame]) + toolbarHeight;
	newWindowWidth		= NSWidth([[myWindow contentView] frame]); // Don't adjust width, only height
	newFrameRect		= NSMakeRect(NSMinX(windowFrame), NSMaxY(windowFrame) - newWindowHeight, newWindowWidth, newWindowHeight);
	newWindowFrame		= [NSWindow frameRectForContentRect:newFrameRect styleMask:[myWindow styleMask]];
	
	[myWindow setContentView:[[[NSView alloc] init] autorelease]];
	[myWindow setTitle:[[self toolbar:toolbar itemForItemIdentifier:itemIdentifier willBeInsertedIntoToolbar:NO] label]];
	[myWindow setFrame:newWindowFrame display:YES animate:[myWindow isVisible]];
	[myWindow setContentView:[prefView retain]];
	
	// Save the selected pane
	[[NSUserDefaults standardUserDefaults] setObject:itemIdentifier forKey:@"selectedPreferencePane"];
	
	// FIXME: Leaking
	//[prefPaneObject release];
}

@end

@implementation PreferencesController (NSToolbarDelegateMethods)

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag 
{
    NSToolbarItem *toolbarItem = nil;
	
    if([itemIdentifier isEqualToString:GeneralPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel:NSLocalizedStringFromTable(@"General", @"Preferences", @"")];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTable(@"General", @"Preferences", @"")];		
		[toolbarItem setToolTip:NSLocalizedStringFromTable(@"Options that control the general behavior of Play", @"Preferences", @"")];
		[toolbarItem setImage:[NSImage imageNamed:@"GeneralPreferencesToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPreferencePaneUsingToolbar:)];
	}
    else if([itemIdentifier isEqualToString:HotKeyPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel:NSLocalizedStringFromTable(@"Hot Keys", @"Preferences", @"")];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTable(@"Hot Keys", @"Preferences", @"")];
		[toolbarItem setToolTip:NSLocalizedStringFromTable(@"Specify hot keys used to control Play", @"Preferences", @"")];
		[toolbarItem setImage:[NSImage imageNamed:@"HotKeyPreferencesToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPreferencePaneUsingToolbar:)];
	}
    else if([itemIdentifier isEqualToString:OutputPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel:NSLocalizedStringFromTable(@"Output", @"Preferences", @"")];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTable(@"Output", @"Preferences", @"")];
		[toolbarItem setToolTip:NSLocalizedStringFromTable(@"Set the output device and replay gain used by Play", @"Preferences", @"")];
		[toolbarItem setImage:[NSImage imageNamed:@"OutputPreferencesToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPreferencePaneUsingToolbar:)];
	}
    else if([itemIdentifier isEqualToString:DSPPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel:NSLocalizedStringFromTable(@"DSP", @"Preferences", @"")];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTable(@"DSP", @"Preferences", @"")];
		[toolbarItem setToolTip:NSLocalizedStringFromTable(@"Set and configure the DSP effects used by Play", @"Preferences", @"")];
		[toolbarItem setImage:[NSImage imageNamed:@"DSPPreferencesToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPreferencePaneUsingToolbar:)];
	}
    else if([itemIdentifier isEqualToString:AdvancedPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel:NSLocalizedStringFromTable(@"Advanced", @"Preferences", @"")];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTable(@"Advanced", @"Preferences", @"")];
		[toolbarItem setToolTip:NSLocalizedStringFromTable(@"Control the size of the audio buffers used by Play", @"Preferences", @"")];
		[toolbarItem setImage:[NSImage imageNamed:@"AdvancedPreferencesToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPreferencePaneUsingToolbar:)];
	}
	
    return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar 
{
	return [NSArray arrayWithObjects:
		GeneralPreferencesToolbarItemIdentifier,
		HotKeyPreferencesToolbarItemIdentifier,
		OutputPreferencesToolbarItemIdentifier,
		DSPPreferencesToolbarItemIdentifier,
		AdvancedPreferencesToolbarItemIdentifier,
		nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar 
{
	return [NSArray arrayWithObjects:
		GeneralPreferencesToolbarItemIdentifier,
		HotKeyPreferencesToolbarItemIdentifier,
		OutputPreferencesToolbarItemIdentifier,
		DSPPreferencesToolbarItemIdentifier,
		AdvancedPreferencesToolbarItemIdentifier,
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		nil];
}

- (NSArray *) toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:
		GeneralPreferencesToolbarItemIdentifier,
		HotKeyPreferencesToolbarItemIdentifier,
		OutputPreferencesToolbarItemIdentifier,
		DSPPreferencesToolbarItemIdentifier,
		AdvancedPreferencesToolbarItemIdentifier,
		nil];
}

@end

@implementation PreferencesController (Private)

- (void) selectPreferencePaneUsingToolbar:(id)sender
{
	[self selectPreferencePane:[[[self window] toolbar] selectedItemIdentifier]];
}

@end
