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

#import "AudioStreamArrayController.h"
#import "AudioStream.h"
#import "AudioLibrary.h"

// ========================================
// Pboard Types
// ========================================
NSString * const AudioStreamPboardType					= @"org.sbooth.Play.AudioStream.PboardType";
NSString * const AudioStreamTableMovedRowsPboardType	= @"org.sbooth.Play.AudioLibrary.AudioStreamTable.MovedRowsPboardType";

@interface AudioStreamArrayController (Private)
- (void) moveObjectsInArrangedObjectsFromIndexes:(NSIndexSet *)indexSet toIndex:(unsigned)insertIndex;
- (NSIndexSet *) indexSetForRows:(NSArray *)rows;
- (int) rowsAboveRow:(int)row inIndexSet:(NSIndexSet *)indexSet;
@end

@implementation AudioStreamArrayController

- (BOOL) tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
	NSArray				*objects		= [[self arrangedObjects] objectsAtIndexes:rowIndexes];
	NSMutableArray		*objectIDs		= [NSMutableArray array];
	NSMutableArray		*filenames		= [NSMutableArray array];
	AudioStream			*stream			= nil;
	BOOL				success			= NO;
	unsigned			i;
	
	for(i = 0; i < [objects count]; ++i) {
		stream = [objects objectAtIndex:i];
		
		[objectIDs addObject:[stream valueForKey:ObjectIDKey]];
		[filenames addObject:[[stream valueForKey:StreamURLKey] path]];
	}
	
	[pboard declareTypes:[NSArray arrayWithObjects:AudioStreamTableMovedRowsPboardType, AudioStreamPboardType, NSFilenamesPboardType, nil] owner:nil];
	[pboard addTypes:[NSArray arrayWithObjects:AudioStreamTableMovedRowsPboardType, AudioStreamPboardType, NSFilenamesPboardType, nil] owner:nil];
	
	success = [pboard setPropertyList:objectIDs forType:AudioStreamPboardType];
	success &= [pboard setPropertyList:filenames forType:NSFilenamesPboardType];
	
	// Copy the row numbers to the pasteboard
    NSData *indexData = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
	success &= [pboard setData:indexData forType:AudioStreamTableMovedRowsPboardType];
	
	return success;
}

- (NSDragOperation) tableView:(NSTableView*)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
	NSDragOperation dragOperation = NSDragOperationNone;
	
	// Move rows if this is an internal drag and the library is displaying an ordered set of streams
	if(tableView == [info draggingSource] && [[AudioLibrary library] streamsAreOrdered]) {
		[tableView setDropRow:row dropOperation:NSTableViewDropAbove];
		dragOperation = NSDragOperationMove;
	}
	// Otherwise it is a copy if the drag isn't internal
	else if(tableView != [info draggingSource]) {
		[tableView setDropRow:row dropOperation:NSTableViewDropAbove];
		dragOperation = NSDragOperationCopy;
	}
	
	return dragOperation;
}

- (BOOL) tableView:(NSTableView*)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op
{
    if(0 > row) {
		row = 0;
	}
	
	// First handle internal drops
    if(_tableView == [info draggingSource]) {
		if(NO == [[AudioLibrary library] streamsAreOrdered]) {
			return NO;
		}
		
		NSData			*indexData		= [[info draggingPasteboard] dataForType:AudioStreamTableMovedRowsPboardType];
		NSIndexSet		*rowIndexes		= [NSKeyedUnarchiver unarchiveObjectWithData:indexData];
		int				rowsAbove;
		NSRange			range;
		
		[self moveObjectsInArrangedObjectsFromIndexes:rowIndexes toIndex:row];
		
		rowsAbove	= [self rowsAboveRow:row inIndexSet:rowIndexes];
		range		= NSMakeRange(row - rowsAbove, [rowIndexes count]);
		rowIndexes	= [NSIndexSet indexSetWithIndexesInRange:range];
		
		[self setSelectionIndexes:rowIndexes];
		
		return YES;
	}

	// Handle drops of files
	NSArray			*supportedTypes		= [NSArray arrayWithObjects:NSFilenamesPboardType, NSURLPboardType, nil];
	NSString		*bestType			= [[info draggingPasteboard] availableTypeFromArray:supportedTypes];	
	AudioLibrary	*library			= [[tableView window] valueForKey:@"library"];
	
	NSAssert(nil != library, @"No AudioLibrary found for AudioStreamTableView");

	if([bestType isEqualToString:NSFilenamesPboardType]) {
		NSArray *filenames = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
		return [library addFiles:filenames];
	}
	else if([bestType isEqualToString:NSURLPboardType]) {
		NSURL *url = [NSURL URLFromPasteboard:[info draggingPasteboard]];
		if([url isFileURL]) {
			return [library addFile:[url path]];
		}
	}

	return NO;
}

@end

@implementation AudioStreamArrayController (Private)

- (void) moveObjectsInArrangedObjectsFromIndexes:(NSIndexSet*)indexSet toIndex:(unsigned)insertIndex
{
	NSArray			*objects					= [self arrangedObjects];
	unsigned		index						= [indexSet lastIndex];
	unsigned		aboveInsertIndexCount		= 0;
	unsigned		removeIndex;
	id				object;
	
	while(NSNotFound != index) {
		if(index >= insertIndex) {
			removeIndex = index + aboveInsertIndexCount;
			++aboveInsertIndexCount;
		}
		else {
			removeIndex = index;
			--insertIndex;
		}
		object = [[objects objectAtIndex:removeIndex] retain];
		[self removeObjectAtArrangedObjectIndex:removeIndex];
		[self insertObject:[object autorelease] atArrangedObjectIndex:insertIndex];
		
		index = [indexSet indexLessThanIndex:index];
	}
}

- (NSIndexSet *) indexSetForRows:(NSArray *)rows
{
	NSArray					*arrangedObjects		= [self arrangedObjects];
	NSEnumerator			*enumerator				= nil;
	NSMutableIndexSet		*indexSet				= [NSMutableIndexSet indexSet];
	NSEnumerator			*rowEnumerator			= [rows objectEnumerator];
	id						object;
	NSNumber				*objectID;
	
	while((objectID = [rowEnumerator nextObject])) {
		enumerator = [arrangedObjects objectEnumerator];
		while((object = [enumerator nextObject])) {
			if([[object valueForKey:ObjectIDKey] isEqual:objectID]) {
				[indexSet addIndex:[arrangedObjects indexOfObject:object]];
			}
		}
	}
	
	return indexSet;
}

- (int) rowsAboveRow:(int)row inIndexSet:(NSIndexSet *)indexSet
{
	int				i				= 0;
	unsigned		currentIndex	= [indexSet firstIndex];
	
	while(NSNotFound != currentIndex) {
		if(currentIndex < (unsigned)row) {
			++i;
		}
		
		currentIndex = [indexSet indexGreaterThanIndex:currentIndex];
	}
	
	return i;
}

@end
