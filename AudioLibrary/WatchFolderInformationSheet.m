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

#import "WatchFolderInformationSheet.h"
#import "WatchFolder.h"

@implementation WatchFolderInformationSheet

- (id) init
{
	if((self = [super init])) {
		BOOL result = [NSBundle loadNibNamed:@"WatchFolderInformationSheet" owner:self];
		if(NO == result) {
			NSLog(@"Missing resource: \"WatchFolderInformationSheet.nib\".");
			[self release];
			return nil;
		}
	}
	return self;
}

- (void) dealloc
{
	[_watchFolder release], _watchFolder = nil;
	
	[super dealloc];
}

- (NSWindow *) sheet
{
	return _sheet;
}

- (IBAction) ok:(id)sender
{
    [[NSApplication sharedApplication] endSheet:[self sheet] returnCode:NSOKButton];
}

- (IBAction) cancel:(id)sender
{
    [[NSApplication sharedApplication] endSheet:[self sheet] returnCode:NSCancelButton];
}

- (IBAction) chooseFolder:(id)sender
{
	NSOpenPanel		*panel		= [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:NO];
	[panel setCanChooseDirectories:YES];
	[panel setCanChooseFiles:NO];
	
	if(NSOKButton == [panel runModalForTypes:nil]) {
		NSArray		*URLs			= [panel URLs];
		unsigned	count			= [URLs count];
		unsigned	i;
		NSURL		*url;
		
		for(i = 0; i < count; ++i) {
			url = [URLs objectAtIndex:i];
			[_folderImageView setImage:[[NSWorkspace sharedWorkspace] iconForFile:[url path]]];
			[[self watchFolder] setValue:url forKey:WatchFolderURLKey];
		}
	}		
}

- (WatchFolder *) watchFolder
{
	return _watchFolder;
}

- (void) setWatchFolder:(WatchFolder *)watchFolder
{
	[_watchFolder release];
	_watchFolder = [watchFolder retain];
	
	if(nil != watchFolder)
		[_folderImageView setImage:[[NSWorkspace sharedWorkspace] iconForFile:[[_watchFolder valueForKey:WatchFolderURLKey] path]]];
}

/*- (NSUndoManager *) windowWillReturnUndoManager:(NSWindow *)sender
{
	return [_owner undoManager];
}

- (IBAction) undo:(id)sender
{
	[[_owner undoManager] undo];
}

- (IBAction) redo:(id)sender
{
	[[_owner undoManager] redo];
}

- (BOOL) validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
	if([anItem action] == @selector(undo:)) {
		return [[_owner undoManager] canUndo];
	}
	else if([anItem action] == @selector(redo:)) {
		return [[_owner undoManager] canRedo];
	}
	
	return YES;
}*/

@end
