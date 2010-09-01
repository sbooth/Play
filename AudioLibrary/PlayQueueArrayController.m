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

#import "PlayQueueArrayController.h"
#import "CollectionManager.h"
#import "AudioStreamManager.h"
#import "AudioStream.h"
#import "AudioLibrary.h"
#import "BrowserTreeController.h"
#import "FileAdditionProgressSheet.h"

// ========================================
// Pboard Types
// ========================================
NSString * const PlayQueueTableMovedRowsPboardType	= @"org.sbooth.Play.AudioLibrary.PlayQueueTable.MovedRowsPboardType";

@interface AudioLibrary (Private)
- (unsigned) playbackIndex;
- (void) setPlaybackIndex:(unsigned)playbackIndex;
@end

@interface AudioStreamArrayController (Private)
- (void) moveObjectsInArrangedObjectsFromIndexes:(NSIndexSet *)indexSet toIndex:(unsigned)insertIndex;
- (NSIndexSet *) indexSetForRows:(NSArray *)rows;
- (int) rowsAboveRow:(int)row inIndexSet:(NSIndexSet *)indexSet;
@end

@implementation PlayQueueArrayController

- (BOOL) tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
	NSArray				*objects		= [[self arrangedObjects] objectsAtIndexes:rowIndexes];
	NSMutableArray		*objectIDs		= [NSMutableArray array];
	AudioStream			*stream			= nil;
	BOOL				success			= NO;
	unsigned			i;
	
	for(i = 0; i < [objects count]; ++i) {
		stream = [objects objectAtIndex:i];		
		[objectIDs addObject:[stream valueForKey:ObjectIDKey]];
	}
	
	[pboard declareTypes:[NSArray arrayWithObjects:PlayQueueTableMovedRowsPboardType, AudioStreamPboardType, nil] owner:nil];
	[pboard addTypes:[NSArray arrayWithObjects:PlayQueueTableMovedRowsPboardType, AudioStreamPboardType, nil] owner:nil];
	
	success = [pboard setPropertyList:objectIDs forType:AudioStreamPboardType];
	
	// Copy the row numbers to the pasteboard
    NSData *indexData = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
	success &= [pboard setData:indexData forType:PlayQueueTableMovedRowsPboardType];
	
	return success;
}

- (NSDragOperation) tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
	NSDragOperation dragOperation = NSDragOperationNone;
	
	// Move rows if this is an internal drag
	if(tableView == [info draggingSource]) {
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

- (BOOL) tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op
{
    if(0 > row)
		row = 0;

	// First handle internal drops for reordering
    if(tableView == [info draggingSource]) {
		NSData			*indexData		= [[info draggingPasteboard] dataForType:PlayQueueTableMovedRowsPboardType];
		NSIndexSet		*rowIndexes		= [NSKeyedUnarchiver unarchiveObjectWithData:indexData];
		unsigned		playbackIndex	= NSNotFound;
		int				rowsAbove;
		NSRange			range;
		
		// If the currently playing stream is being dragged, determine what its new index will be
		// First count how many rows with indexes less than the currently playing stream's index are being dragged
		if([rowIndexes containsIndex:[[AudioLibrary library] playbackIndex]]) {
			unsigned count		= 0;
			unsigned index		= [rowIndexes lastIndex];
			
			while(NSNotFound != index) {
				if(index < [[AudioLibrary library] playbackIndex]) {
					++count;				
				}
				index = [rowIndexes indexLessThanIndex:index];
			}
			
			playbackIndex = count;
			
			// Don't let the library reorder the playbackIndex during the drag
			[[AudioLibrary library] setPlaybackIndex:NSNotFound];
		}
		
		[self moveObjectsInArrangedObjectsFromIndexes:rowIndexes toIndex:row];
		
		rowsAbove	= [self rowsAboveRow:row inIndexSet:rowIndexes];
		range		= NSMakeRange(row - rowsAbove, [rowIndexes count]);
		rowIndexes	= [NSIndexSet indexSetWithIndexesInRange:range];
		
		// Adjust the current playbackIndex, if the currently playing stream was dragged
		if(NSNotFound != playbackIndex)
			[[AudioLibrary library] setPlaybackIndex:(row - rowsAbove + playbackIndex)];
		
		[self setSelectionIndexes:rowIndexes];
		
		return YES;
	}
	
	NSArray			*supportedTypes		= [NSArray arrayWithObjects:AudioStreamPboardType, NSFilenamesPboardType, NSURLPboardType, iTunesPboardType, nil];
	NSString		*bestType			= [[info draggingPasteboard] availableTypeFromArray:supportedTypes];	
	
	if([bestType isEqualToString:AudioStreamPboardType]) {
		AudioStream		*stream			= nil;
			
		for(NSNumber *objectID in [[info draggingPasteboard] propertyListForType:AudioStreamPboardType]) {
			stream = [[[CollectionManager manager] streamManager] streamForID:objectID];
			[self insertObject:stream atArrangedObjectIndex:row++];
		}
		
		return YES;
	}
	// Handle drops of files
	else if([bestType isEqualToString:NSFilenamesPboardType]) {
		NSArray						*filenames		= [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
		FileAdditionProgressSheet	*progressSheet	= [[FileAdditionProgressSheet alloc] init];
		
		[[NSApplication sharedApplication] beginSheet:[progressSheet sheet]
									   modalForWindow:[[AudioLibrary library] window]
										modalDelegate:nil
									   didEndSelector:nil
										  contextInfo:nil];
		
		NSModalSession modalSession = [[NSApplication sharedApplication] beginModalSessionForWindow:[progressSheet sheet]];
		
		[progressSheet startProgressIndicator:self];
		BOOL result = [[AudioLibrary library] addFiles:filenames inModalSession:modalSession];
		[progressSheet stopProgressIndicator:self];
		
		[NSApp endModalSession:modalSession];
		
		[NSApp endSheet:[progressSheet sheet]];
		[[progressSheet sheet] close];
		[progressSheet release];
		
		if(result) {
			NSMutableArray	*streams		= [NSMutableArray array];
			NSURL			*url			= nil;
			
			for(NSString *filename in filenames) {
				url = [NSURL fileURLWithPath:filename];
				[streams addObjectsFromArray:[[[CollectionManager manager] streamManager] streamsContainedByURL:url]];
			}

			[self insertObjects:streams atArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row, [streams count])]];
		}
		
		return result;
	}
	else if([bestType isEqualToString:NSURLPboardType]) {
		NSURL *url = [NSURL URLFromPasteboard:[info draggingPasteboard]];
		if([url isFileURL]) {
			BOOL success = [[AudioLibrary library] addFile:[url path]];
			if(success) {
				NSArray *streams = [[[CollectionManager manager] streamManager] streamsContainedByURL:url];
				if(nil != streams)
					[self insertObjects:streams atArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row, [streams count])]];
			}
			   
			return success;
		}
		
		return NO;
	}
	// Handle iTunes drops
	else if([bestType isEqualToString:iTunesPboardType]) {
		NSDictionary	*iTunesDictionary	= [[info draggingPasteboard] propertyListForType:iTunesPboardType];
		NSDictionary	*tracks				= [iTunesDictionary objectForKey:@"Tracks"];
		NSURL			*url				= nil;
		BOOL			success				= NO;
		NSMutableArray	*streams			= [NSMutableArray array];

		for(NSNumber *iTunesTrackNumber in [tracks allKeys]) {
			NSDictionary *track = [tracks objectForKey:iTunesTrackNumber];
			url = [NSURL URLWithString:[track objectForKey:@"Location"]];
			if([url isFileURL]) {
				BOOL added = [[AudioLibrary library] addFile:[url path]];
				
				if(added)
					[streams addObjectsFromArray:[[[CollectionManager manager] streamManager] streamsContainedByURL:url]];

				success |= added;
			}
		}
		
		if(success && [streams count])
			[self insertObjects:streams atArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row, [streams count])]];
		
		return success;
	}
	
	return NO;
}

@end
