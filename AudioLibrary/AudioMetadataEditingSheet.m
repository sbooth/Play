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

#import "AudioMetadataEditingSheet.h"
#import "AudioStream.h"
#import "Genres.h"

@implementation AudioMetadataEditingSheet

- (id) init
{
	if((self = [super init])) {
		BOOL result = [NSBundle loadNibNamed:@"AudioMetadataEditingSheet" owner:self];
		if(NO == result) {
			NSLog(@"Missing resource: \"AudioMetadataEditingSheet.nib\".");
			[self release];
			return nil;
		}
	}
	return self;
}

- (void) awakeFromNib
{
	// Set number formatters	
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	
	[_trackNumberTextField setFormatter:numberFormatter];
	[_trackTotalTextField setFormatter:numberFormatter];
	[_discNumberTextField setFormatter:numberFormatter];
	[_discTotalTextField setFormatter:numberFormatter];
	[_bpmTextField setFormatter:numberFormatter];
	[numberFormatter release];
}

- (NSWindow *) sheet
{
	return [[_sheet retain] autorelease];
}

- (IBAction) ok:(id)sender
{
    [[NSApplication sharedApplication] endSheet:[self sheet] returnCode:NSOKButton];
}

- (IBAction) cancel:(id)sender
{
    [[NSApplication sharedApplication] endSheet:[self sheet] returnCode:NSCancelButton];
}

/*- (IBAction) undo:(id)sender
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
}*/

- (NSArray *) changedStreams
{
	NSMutableArray	*result			= [[NSMutableArray alloc] init];
	
	for(AudioStream *stream in [_streamController arrangedObjects]) {
		if([stream hasChanges])
			[result addObject:stream];
	}
	
	return [result autorelease];
}

- (NSArray *) genres
{
	return [Genres sharedGenres];
}

@end
