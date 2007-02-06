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

#import "PlaylistTableViewDataSource.h"
#import "AudioLibrary.h"
#import "Playlist.h"

@implementation PlaylistTableViewDataSource

// 0 and nil indicate that the table should fall back to its bindings
- (int) numberOfRowsInTableView:(NSTableView *)aTableView
{
	return 0;
}

- (id) tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	return nil;
}

- (NSDragOperation) tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
	NSDragOperation		result				= NSDragOperationNone;
	NSDictionary		*infoForBinding		= [tableView infoForBinding:NSContentBinding];

	if(nil != infoForBinding) {		
		NSArrayController	*arrayController	= [infoForBinding objectForKey:NSObservedObjectKey];
		unsigned			objectCount			= [[arrayController arrangedObjects] count];

		if(0 < objectCount) {
			if(row >= objectCount) {
				--row;
			}
		
			Playlist *playlist = [[arrayController arrangedObjects] objectAtIndex:row];

			// Only allow dropping streams on static playlists
			if(ePlaylistTypeStaticPlaylist == [[playlist valueForKey:@"type"] intValue]) {
				[tableView setDropRow:row dropOperation:NSTableViewDropOn];
				result = NSDragOperationCopy;
			}
		}
	}
	
	return result;
}

- (BOOL) tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	BOOL			success							= NO;
	NSString		*objectIDString					= [[info draggingPasteboard] stringForType:@"AudioStreamPboardType"];
	NSDictionary	*destinationContentBindingInfo	= [tableView infoForBinding:NSContentBinding];
	
	if(nil != destinationContentBindingInfo) {
		NSArrayController	*destinationArrayController	= [destinationContentBindingInfo objectForKey:NSObservedObjectKey];
		NSArrayController	*sourceArrayController		= nil;
		NSDictionary		*sourceContentBindingInfo	= [destinationArrayController infoForBinding:NSContentArrayBinding];
		
		if(nil != sourceContentBindingInfo) {
			sourceArrayController = [sourceContentBindingInfo objectForKey:NSObservedObjectKey];  
		}
		
		if(nil != sourceArrayController) {
			NSArray		*objectIDs		= [objectIDString componentsSeparatedByString:@", "];
			NSNumber	*objectID		= nil;
			unsigned	i;
			
			for(i = 0; i < [objectIDs count]; ++i) {
				objectID = [objectIDs objectAtIndex:i];
				
				if(nil != objectID) {
					Playlist *playlist = [[destinationArrayController arrangedObjects] objectAtIndex:row];
					
					NSLog(@"Add stream %@ to playlist %@", objectID, playlist);
					
					success = YES;					
				}
			}
		}
	}
	
	return success;
}

@end
