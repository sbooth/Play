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

#import "AudioStreamTableViewDataSource.h"
#import "AudioLibrary.h"
#import "AudioStream.h"

@implementation AudioStreamTableViewDataSource

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
	NSDragOperation			result				= NSDragOperationNone;
	NSDictionary			*infoForBinding		= [tableView infoForBinding:NSContentBinding];
	
	if(nil != infoForBinding && [info draggingSource] != tableView) {		
		[tableView setDropRow:row dropOperation:NSTableViewDropAbove];
		result = NSDragOperationCopy;
	}
	
	return result;
}

- (BOOL) tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	BOOL			success				= NO;
	NSArray			*supportedTypes		= [NSArray arrayWithObjects:NSFilenamesPboardType, NSURLPboardType, nil];
	NSString		*bestType			= [[info draggingPasteboard] availableTypeFromArray:supportedTypes];	
	AudioLibrary	*library			= [[tableView window] valueForKey:@"library"];

	NSAssert(nil != library, @"No AudioLibrary found for AudioStreamTableView");
	
	if([bestType isEqualToString:NSFilenamesPboardType]) {
		NSArray *filenames = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
		success = [library addFiles:filenames];
	}
	else if([bestType isEqualToString:NSURLPboardType]) {
		NSURL *url = [NSURL URLFromPasteboard:[info draggingPasteboard]];
		if([url isFileURL]) {
			success = [library addFile:[url path]];
		}
	}
	
	return success;
}

- (BOOL) tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
	BOOL			success				= NO;
	NSDictionary	*infoForBinding		= [tv infoForBinding:NSContentBinding];
	
	if(nil != infoForBinding) {
		unsigned			i;
		AudioStream			*stream;
		
		NSArrayController	*arrayController		= [infoForBinding objectForKey:NSObservedObjectKey];
		NSArray				*objects				= [[arrayController arrangedObjects] objectsAtIndexes:rowIndexes];
		NSMutableArray		*objectIDs				= [NSMutableArray array];
		NSMutableArray		*filenames				= [NSMutableArray array];
		
		for(i = 0; i < [objects count]; ++i) {
			stream = [objects objectAtIndex:i];
			
			[objectIDs addObject:[stream valueForKey:ObjectIDKey]];
			[filenames addObject:[[stream valueForKey:StreamURLKey] path]];
		}
		
		[pboard declareTypes:[NSArray arrayWithObjects:@"AudioStreamPboardType", NSFilenamesPboardType, nil] owner:nil];
		[pboard addTypes:[NSArray arrayWithObjects:@"AudioStreamPboardType", NSFilenamesPboardType, nil] owner:nil];

		success = [pboard setPropertyList:objectIDs forType:@"AudioStreamPboardType"];
		success &= [pboard setPropertyList:filenames forType:NSFilenamesPboardType];
	}
	
	return success;
}

@end
