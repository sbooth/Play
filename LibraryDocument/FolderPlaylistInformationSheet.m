/*
 *  $Id$
 *
 *  Copyright (C) 2006 Stephen F. Booth <me@sbooth.org>
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

#import "FolderPlaylistInformationSheet.h"
#import "LibraryDocument.h"

@implementation FolderPlaylistInformationSheet

+ (void) initialize
{
	[self setKeys:[NSArray arrayWithObject:@"owner"] triggerChangeNotificationsForDependentKey:@"managedObjectContext"];
}

- (id) init
{
	if((self = [super init])) {
		BOOL		result;
		
		result		= [NSBundle loadNibNamed:@"FolderPlaylistInformationSheet" owner:self];
		if(NO == result) {
			NSLog(@"Missing resource: \"FolderPlaylistInformationSheet.nib\".");
			[self release];
			return nil;
		}
		
		return self;
	}
	
	return nil;
}

- (NSWindow *) sheet
{
	return [[_sheet retain] autorelease];
}

- (NSManagedObjectContext *) managedObjectContext
{
	return [_owner managedObjectContext];
}

- (IBAction) ok:(id)sender
{
    [[NSApplication sharedApplication] endSheet:[self sheet] returnCode:NSOKButton];
}

- (IBAction) cancel:(id)sender
{
    [[NSApplication sharedApplication] endSheet:[self sheet] returnCode:NSCancelButton];
}

- (IBAction) undo:(id)sender
{
	[[[self managedObjectContext] undoManager] undo];
}

- (IBAction) redo:(id)sender
{
	[[[self managedObjectContext] undoManager] redo];
}

- (BOOL) validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
	if([anItem action] == @selector(undo:)) {
		return [[[self managedObjectContext] undoManager] canUndo];
	}
	else if([anItem action] == @selector(redo:)) {
		return [[[self managedObjectContext] undoManager] canRedo];
	}
	
	return YES;
}

- (IBAction) chooseFolder:(id)sender
{
	NSOpenPanel		*panel		= [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:NO];
	[panel setCanChooseDirectories:YES];
	[panel setCanChooseFiles:NO];
	
	if(NSOKButton == [panel runModalForTypes:nil]) {
		NSArray		*filenames		= [panel filenames];
		unsigned	count			= [filenames count];
		unsigned	i;
		
		for(i = 0; i < count; ++i) {
			[[_playlistObjectController selection] setValue:[filenames objectAtIndex:i] forKeyPath:@"url"];
		}
	}		
}

- (void) controlTextDidChange:(NSNotification *)aNotification
{
	unsigned	matchCount;
	NSArray		*matches;
	id			sender;
	NSString	*path, *longestMatch;
	NSText		*editor;
	
	
	sender		= [aNotification object];
	editor		= [sender currentEditor];
	path		= [sender stringValue];

	if(nil == path || [path isEqualToString:@""]) {
		return;
	}
	
	path		= [path stringByExpandingTildeInPath];
	matchCount	= [path completePathIntoString:&longestMatch caseSensitive:NO matchesIntoArray:&matches filterTypes:nil];
	
	if(1 <= matchCount) {
		if(nil == editor) {
			[editor setString:longestMatch];
		}
		else if([sender textShouldBeginEditing:editor]) {
			NSRange		range		= [editor selectedRange];
			NSString	*string		= [editor string];
			unsigned	length		= [string length];
			
			if(0 == range.length && length == range.location) {
				[editor setString:longestMatch];
				[editor setSelectedRange:NSMakeRange(length, NSNotFound)];
			}

			[sender textShouldEndEditing:editor];
		}
	}
}

@end
