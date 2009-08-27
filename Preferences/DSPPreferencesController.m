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

#import "DSPPreferencesController.h"
#import "AudioLibrary.h"
#import "AudioPlayer.h"
#import "PreferencesController.h"
#import "ImageAndTextCell.h"

#include <AudioUnit/AudioUnit.h>
#import <SFBAudioUnitUI/SFBAudioUnitUIWindowController.h>

@implementation DSPPreferencesController

- (id) init
{
	if((self = [super initWithWindowNibName:@"DSPPreferences"])) {
		_effects			= [[NSMutableArray alloc] init];
		_audioUnitUIEditor	= [[SFBAudioUnitUIWindowController alloc] init];
	}
	return self;
}

- (void) dealloc
{
	[_audioUnitUIEditor release], _audioUnitUIEditor = nil;
	[_effects release], _effects = nil;
	[super dealloc];
}

- (void) awakeFromNib
{
	NSArray *effects		= [[[AudioLibrary library] player] availableEffects];
	NSArray *manufacturers	= [effects valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", AUManufacturerStringKey]];

	NSMenu *auMenu = [[NSMenu alloc] init];

	if(1 >= [manufacturers count]) {
		for(NSDictionary *auDictionary in effects) {
			NSMenuItem *menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:[auDictionary valueForKey:AUNameStringKey]];
//			[menuItem setImage:[auDictionary valueForKey:AUIconKey]];
			[menuItem setToolTip:[auDictionary valueForKey:AUInformationStringKey]];
			[menuItem setRepresentedObject:auDictionary];
			[menuItem setTarget:self];
			[menuItem setAction:@selector(addEffect:)];
			
			[auMenu addItem:[menuItem autorelease]];
		}
	}
	else {
		for(NSString *manufacturer in manufacturers) {
			NSPredicate		*manufacturerPredicate	= [NSPredicate predicateWithFormat:@"%K == %@", AUManufacturerStringKey, manufacturer];
			NSArray			*manufacturerEffects	= [effects filteredArrayUsingPredicate:manufacturerPredicate];
			NSMenu			*manufacturerSubMenu	= [[NSMenu alloc] init];
			NSMenuItem		*manufacturerMenuItem	= [[NSMenuItem alloc] init];
			
			[manufacturerMenuItem setTitle:manufacturer];
						
			for(NSDictionary *auDictionary in manufacturerEffects) {
				NSMenuItem *menuItem = [[NSMenuItem alloc] init];
				[menuItem setTitle:[auDictionary valueForKey:AUNameStringKey]];
//				[menuItem setImage:[auDictionary valueForKey:AUIconKey]];
				[menuItem setToolTip:[auDictionary valueForKey:AUInformationStringKey]];
				[menuItem setRepresentedObject:auDictionary];
				[menuItem setTarget:self];
				[menuItem setAction:@selector(addEffect:)];
				
				[manufacturerSubMenu addItem:[menuItem autorelease]];
			}
			
			[manufacturerMenuItem setSubmenu:[manufacturerSubMenu autorelease]];
			[auMenu addItem:[manufacturerMenuItem autorelease]];
		}		
	}
	
	[_addEffectButton setMenu:[auMenu autorelease]];
	
	[_removeEffectButton bind:@"enabled" toObject:_effectsArrayController withKeyPath:@"selectedObjects.@count" options:nil];
	
	for(NSDictionary *auDictionary in [[[AudioLibrary library] player] currentEffects])
		[_effectsArrayController addObject:auDictionary];
	
	// Setup the custom data cell
	NSTableColumn		*tableColumn		= [_effectsTable tableColumnWithIdentifier:@"name"];
	ImageAndTextCell	*imageAndTextCell	= [[ImageAndTextCell alloc] init];
	
	[imageAndTextCell setLineBreakMode:NSLineBreakByTruncatingTail];
	[tableColumn setDataCell:[imageAndTextCell autorelease]];
}

- (IBAction) addEffect:(id)sender
{
	NSParameterAssert(nil != sender);
	
	NSDictionary	*auDictionary	= [sender representedObject];
	AudioPlayer		*player			= [[AudioLibrary library] player];
	NSError			*error			= nil;
	AUNode			node;
	
	BOOL result = [player addEffectToAUGraph:auDictionary newNode:&node error:&error];
	if(!result) {
		if(nil != error)
			[self presentError:error modalForWindow:[[PreferencesController sharedPreferences] window] delegate:nil didPresentSelector:NULL contextInfo:NULL];
		return;
	}
	
	NSMutableDictionary *nodeInfo = [auDictionary mutableCopy];
	[nodeInfo setValue:[NSNumber numberWithInt:node] forKey:AUNodeKey];
	
	[self willChangeValueForKey:@"effects"];
	[_effects addObject:[nodeInfo autorelease]];
	[self didChangeValueForKey:@"effects"];
}

- (IBAction) removeEffect:(id)sender
{
	AudioPlayer		*player		= [[AudioLibrary library] player];
	NSDictionary	*nodeInfo	= [[_effectsArrayController selectedObjects] lastObject];
	AUNode			node		= [[nodeInfo valueForKey:AUNodeKey] intValue];
	AudioUnit		au			= [player audioUnitForAUNode:node];
	NSError			*error		= nil;
	
	if(NULL == au) {
		NSBeep();
		return;
	}
	
	if(au == [_audioUnitUIEditor audioUnit])
		[[_audioUnitUIEditor window] performClose:sender];
	
	BOOL result = [player removeEffectFromAUGraph:node error:&error];
	if(!result) {
		if(nil != error)
			[self presentError:error modalForWindow:[[PreferencesController sharedPreferences] window] delegate:nil didPresentSelector:NULL contextInfo:NULL];
		return;
	}
	
	[_effectsArrayController remove:sender];
}

- (IBAction) editEffectParameters:(id)sender
{
	AudioPlayer		*player		= [[AudioLibrary library] player];
	NSDictionary	*nodeInfo	= [[_effectsArrayController selectedObjects] lastObject];
	AUNode			node		= [[nodeInfo valueForKey:AUNodeKey] intValue];
	AudioUnit		au			= [player audioUnitForAUNode:node];

	if(NULL == au) {
		NSBeep();
		return;
	}
	
	[_audioUnitUIEditor setAudioUnit:au];
	
	/*	[[NSApplication sharedApplication] beginSheet:[_audioUnitUIEditor window] 
modalForWindow:[[PreferencesController sharedPreferences] window] 
modalDelegate:self 
didEndSelector:NULL 
contextInfo:NULL];*/
	
	if(NO == [[_audioUnitUIEditor window] isVisible])
		[[_audioUnitUIEditor window] center];
	
	[_audioUnitUIEditor showWindow:sender];
}

@end

@implementation DSPPreferencesController (NSTableViewDelegateMethods)

- (void) tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if(tableView == _effectsTable) {
		NSDictionary *infoForBinding = [tableView infoForBinding:NSContentBinding];
		
		if(nil != infoForBinding) {
			NSArrayController	*arrayController	= [infoForBinding objectForKey:NSObservedObjectKey];
			NSDictionary		*auDictionary		= [[arrayController arrangedObjects] objectAtIndex:rowIndex];

			[(ImageAndTextCell *)cell setImage:[auDictionary valueForKey:AUIconKey]];
		}
	}
}

@end
