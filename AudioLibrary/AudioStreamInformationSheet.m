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

#import "AudioStreamInformationSheet.h"
#import "AudioLibrary.h"
#import "Genres.h"

@implementation AudioStreamInformationSheet

- (id) init
{
	if((self = [super init])) {
		BOOL result = [NSBundle loadNibNamed:@"AudioStreamInformationSheet" owner:self];
		if(NO == result) {
			NSLog(@"Missing resource: \"AudioStreamInformationSheet.nib\".");
			[self release];
			return nil;
		}
	}
	return self;
}

- (void) awakeFromNib
{
	[_albumArtImageView setImage:[NSImage imageNamed:@"Play"]];
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

- (IBAction) chooseAlbumArt:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:NO];
	[panel setCanChooseDirectories:NO];
	[panel setCanChooseFiles:YES];
	
	if(NSOKButton == [panel runModalForTypes:[NSImage imageFileTypes]]) {
		NSArray		*filenames		= [panel filenames];
		unsigned	count			= [filenames count];
		unsigned	i;
		NSImage		*image			= nil;
		
		for(i = 0; i < count; ++i) {
			image	= [[NSImage alloc] initWithContentsOfFile:[filenames objectAtIndex:i]];
			if(nil != image) {
//				[_stream setValue:[image TIFFRepresentation] forKeyPath:@"albumArt"];
				[image release];
			}
		}
	}		
}

- (NSArray *) genres
{
	return [Genres sharedGenres];
}

@end
