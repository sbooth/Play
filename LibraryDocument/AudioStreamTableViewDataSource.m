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

#import "AudioStreamTableViewDataSource.h"
#import "LibraryDocument.h"

@implementation AudioStreamTableViewDataSource

- (NSDragOperation) tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
	NSDragOperation			result;
	NSDictionary			*infoForBinding;
	
	result					= NSDragOperationNone;
	infoForBinding			= [tableView infoForBinding:NSContentBinding];
	
	if(nil != infoForBinding && [info draggingSource] != tableView) {
		NSArrayController	*arrayController;
		unsigned			objectCount;
		
		arrayController		= [infoForBinding objectForKey:NSObservedObjectKey];
		objectCount			= [[arrayController arrangedObjects] count];
		
		[tableView setDropRow:row dropOperation:NSTableViewDropAbove];
			
		result			= NSDragOperationCopy;
	}
	
	return result;
}

- (BOOL) tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	BOOL							success;
	NSArray							*supportedTypes; 
	NSString						*bestType;
	unsigned						i;
	id								document;
	LibraryDocument					*libraryDocument;
	
	success							= NO;
	supportedTypes					= [NSArray arrayWithObjects: @"NSURLsPboardType", NSFilenamesPboardType, nil];
	bestType						= [[info draggingPasteboard] availableTypeFromArray:supportedTypes];
	document						= [[[tableView window] windowController] document];
	libraryDocument					= (LibraryDocument *)document;

	NSAssert(nil != document, @"No NSDocument found for NSTableView");
	NSAssert([document isKindOfClass:[LibraryDocument class]], @"NSDocument subclass was not LibraryDocument");
	
	if([bestType isEqualToString:NSFilenamesPboardType]) {
		NSArray						*filenames;
		NSString					*filename;
		
		filenames					= [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];

		for(i = 0; i < [filenames count]; ++i) {
			filename				= [filenames objectAtIndex:i];		
			[libraryDocument addFileToLibrary:filename];
		}			
		
		success						= YES;
	}
	else if([bestType isEqualToString:@"NSURLsPboardType"]) {
		NSArray						*urls;
		NSURL						*url;
		
		urls						= [[info draggingPasteboard] propertyListForType:@"NSURLsPboardType"];
		
		for(i = 0; i < [urls count]; ++i) {
			urls					= [urls objectAtIndex:i];
			[libraryDocument addURLToLibrary:url];
		}
		
		success						= YES;
	}
	
	return success;
}

- (BOOL) tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
	BOOL					success;
	NSDictionary			*infoForBinding;
	
	success					= NO;
	infoForBinding			= [tv infoForBinding:NSContentBinding];
	
	if(nil != infoForBinding) {
		NSArrayController	*arrayController;
		NSArray				*objects;
		NSMutableArray		*objectIDs;
		NSMutableArray		*filenames;
		NSMutableArray		*urls;
		unsigned			i;
		NSManagedObject		*item;
		NSManagedObjectID	*objectID;
		NSURL				*representedURL;
		NSURL				*streamURL;
		
		arrayController		= [infoForBinding objectForKey:NSObservedObjectKey];
		objects				= [[arrayController arrangedObjects] objectsAtIndexes:rowIndexes];
		objectIDs			= [NSMutableArray array];
		filenames			= [NSMutableArray array];
		urls				= [NSMutableArray array];
		
		for(i = 0; i < [objects count]; ++i) {
			item			= [objects objectAtIndex:i];
			objectID		= [item objectID];
			representedURL	= [objectID URIRepresentation];
			streamURL		= [NSURL URLWithString:[item valueForKey:@"url"]];
			
			[objectIDs addObject:representedURL];

			if([streamURL isFileURL]) {
				[filenames addObject:[streamURL path]];
				[urls addObject:streamURL];
			}
		}
		
		[pboard declareTypes:[NSArray arrayWithObjects:@"AudioStreamPboardType", @"NSURLsPboardType", NSFilenamesPboardType, nil] owner:nil];
		[pboard addTypes:[NSArray arrayWithObjects:@"AudioStreamPboardType", @"NSURLsPboardType", NSFilenamesPboardType, nil] owner:nil];

		success				= [pboard setString:[objectIDs componentsJoinedByString:@", "] forType:@"AudioStreamPboardType"];
		success				&= [pboard setPropertyList:filenames forType:NSFilenamesPboardType];
		success				&= [pboard setPropertyList:urls forType:@"NSURLsPboardType"];
	}
	
	return success;
}

@end
