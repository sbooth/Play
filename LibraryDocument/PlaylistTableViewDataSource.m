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

@implementation PlaylistTableViewDataSource

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
	NSDragOperation			result;
	NSDictionary			*infoForBinding;
	
	result					= NSDragOperationNone;
	infoForBinding			= [tableView infoForBinding:NSContentBinding];

	if(nil != infoForBinding) {
		NSArrayController	*arrayController;
		NSManagedObject		*playlistObject;
		unsigned			objectCount;
		
		arrayController		= [infoForBinding objectForKey:NSObservedObjectKey];
		objectCount			= [[arrayController arrangedObjects] count];

		if(0 < objectCount) {
			if(row >= objectCount) {
				--row;
			}
		
			playlistObject	= [[arrayController arrangedObjects] objectAtIndex:row];

			// Only allow dropping streams on static playlists
			if([[[playlistObject entity] name] isEqualToString:@"StaticPlaylist"]) {
				[tableView setDropRow:row dropOperation:NSTableViewDropOn];
				result			= NSDragOperationCopy;
			}
		}
	}
	
	return result;
}

- (BOOL) tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	BOOL							success;
	NSString						*urlStrings;
	NSDictionary					*destinationContentBindingInfo;
	
	success							= NO;
	urlStrings						= [[info draggingPasteboard] stringForType:@"AudioStreamPboardType"];

	destinationContentBindingInfo	= [tableView infoForBinding:NSContentBinding];
	
	if(nil != destinationContentBindingInfo) {
		NSArrayController			*destinationArrayController;
		NSArrayController			*sourceArrayController;
		NSDictionary				*contentSetBindingInfo;
		
		destinationArrayController	= [destinationContentBindingInfo objectForKey:NSObservedObjectKey];
		sourceArrayController		= nil;

		contentSetBindingInfo		= [destinationArrayController infoForBinding:NSContentSetBinding];
		if(nil != contentSetBindingInfo) {
			sourceArrayController	= [contentSetBindingInfo objectForKey:NSObservedObjectKey];  
		}
		
		if(nil != sourceArrayController) {
			NSManagedObjectContext	*context;
			NSEntityDescription		*destinationControllerEntity;
			NSArray					*items;
			unsigned				i;
			NSString				*urlString;
			NSURL					*url;
			NSManagedObjectID		*objectID;
			
			context					= [destinationArrayController managedObjectContext];
			destinationControllerEntity = [NSEntityDescription entityForName:[destinationArrayController entityName] inManagedObjectContext:context];
			items					= [urlStrings componentsSeparatedByString:@", "];
			
			for(i = 0; i < [items count]; ++i) {
				urlString			= [items objectAtIndex:i];
				url					= [NSURL URLWithString:urlString];
				objectID			= [[context persistentStoreCoordinator] managedObjectIDForURIRepresentation:url];

				if(nil != objectID) {
					NSManagedObject		*streamObject;
					NSManagedObject		*playlistObject;
					NSMutableSet		*streamSet;
					
					streamObject		= [context objectRegisteredForID:objectID];				
					playlistObject		= [[destinationArrayController arrangedObjects] objectAtIndex:row];
					streamSet			= [playlistObject mutableSetValueForKey:@"streams"];

					[streamSet addObject:streamObject];
					success				= YES;					
				}
			}			
		}
	}
	
	return success;
}

@end
