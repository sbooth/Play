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

#import "AudioStreamTableView.h"

#import "AudioStream.h"
#import "Playlist.h"
#import "AudioLibrary.h"

#import "AudioStreamInformationSheet.h"
#import "AudioMetadataEditingSheet.h"

#import "CollectionManager.h"
#import "AudioStreamManager.h"

#import "SecondsFormatter.h"

#import "ReplayGainUtilities.h"
#import "ReplayGainCalculationProgressSheet.h"

#import "CTBadge.h"

#define kMaximumStreamsForContextMenuAction 10

@interface AudioStreamTableView (Private)
- (void) openWithPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void) showStreamInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void) showMetadataEditingSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void) performReplayGainCalculationForStreams:(NSArray *)streams calculateAlbumGain:(BOOL)calculateAlbumGain;
@end

@implementation AudioStreamTableView

- (void) awakeFromNib
{
	[self registerForDraggedTypes:[NSArray arrayWithObjects:AudioStreamTableMovedRowsPboardType, AudioStreamPboardType, NSFilenamesPboardType, NSURLPboardType, iTunesPboardType, nil]];
	NSFormatter *formatter = [[SecondsFormatter alloc] init];
	[[[self tableColumnWithIdentifier:@"duration"] dataCell] setFormatter:formatter];
	[formatter release];
}

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if([menuItem action] == @selector(addToPlayQueue:)) {
		return (0 != [[_streamController selectedObjects] count]);
	}
	else if([menuItem action] == @selector(streamInformation:)) {
		return (1 == [[_streamController selectedObjects] count]);
	}
	else if([menuItem action] == @selector(resetPlayCount:)) {
		return (0 != [[_streamController selectedObjects] count]);
	}
	else if([menuItem action] == @selector(resetSkipCount:)) {
		return (0 != [[_streamController selectedObjects] count]);
	}
	else if([menuItem action] == @selector(editMetadata:)) {
		return (0 != [[_streamController selectedObjects] count]);
	}
	else if([menuItem action] == @selector(rescanMetadata:)) {
		return (0 != [[_streamController selectedObjects] count]);
	}
	else if([menuItem action] == @selector(saveMetadata:)) {
		return (0 != [[_streamController selectedObjects] count]);
	}
	else if([menuItem action] == @selector(calculateTrackReplayGain:)) {
		return (0 != [[_streamController selectedObjects] count]);
	}
	else if([menuItem action] == @selector(calculateTrackAndAlbumReplayGain:)) {
		return (0 != [[_streamController selectedObjects] count]);
	}
	else if([menuItem action] == @selector(clearReplayGain:)) {
		return (0 != [[_streamController selectedObjects] count]);
	}
	else if([menuItem action] == @selector(remove:)) {
		return [_streamController canRemove];
	}
	else if([menuItem action] == @selector(insertPlaylistWithSelection:)) {
		return (/*[_browserController canInsert] && */0 != [[_streamController selectedObjects] count]);
	}
	else if([menuItem action] == @selector(convertWithMax:)) {
		return (nil != [[NSWorkspace sharedWorkspace] fullPathForApplication:@"Max"] && kMaximumStreamsForContextMenuAction >= [[_streamController selectedObjects] count]);
	}
	else if([menuItem action] == @selector(revealInFinder:)
			|| [menuItem action] == @selector(openWithFinder:)
			|| [menuItem action] == @selector(openWith:)) {
		return (kMaximumStreamsForContextMenuAction >= [[_streamController selectedObjects] count]);
	}

	return YES;
}

- (void) keyDown:(NSEvent *)event
{
	unichar			key		= [[event charactersIgnoringModifiers] characterAtIndex:0];    
	unsigned int	flags	= [event modifierFlags] & 0x00FF;
    
	if(0x0020 == key && 0 == flags) {
		[[AudioLibrary library] playPause:self];
	}
	else if(NSCarriageReturnCharacter == key && 0 == flags) {
		[self doubleClickAction:event];
	}
	else if(0xf702 == key && 0 == flags) {
		[[AudioLibrary library] skipBackward:self];
	}
	else if(0xf703 == key && 0 == flags) {
		[[AudioLibrary library] skipForward:self];
	}
	else if((NSDeleteCharacter == key || NSBackspaceCharacter == key) && 0 == flags) {
		[self remove:event];
	}
	else {
		[super keyDown:event]; // let somebody else handle the event 
	}
}

- (NSImage *) dragImageForRowsWithIndexes:(NSIndexSet *)dragRows tableColumns:(NSArray *)tableColumns event:(NSEvent*)dragEvent offset:(NSPointPointer)dragImageOffset
{
	if(1 < [dragRows count]) {
		NSImage		*badgeImage		= [[CTBadge systemBadge] smallBadgeForValue:[dragRows count]];
		NSSize		badgeSize		= [badgeImage size];
		NSImage		*dragImage		= [[NSImage alloc] initWithSize:NSMakeSize(48, 48)];
		NSImage		*genericIcon	= [NSImage imageNamed:@"Generic"];

		[genericIcon setSize:NSMakeSize(48, 48)];
		
		[dragImage lockFocus];
		[badgeImage compositeToPoint:NSMakePoint(48 - badgeSize.width, 48 - badgeSize.height) operation:NSCompositeSourceOver];  
		[genericIcon compositeToPoint:NSZeroPoint operation:NSCompositeDestinationOver fraction:0.75];
		[dragImage unlockFocus];
				
		return dragImage;
	}
	return [super dragImageForRowsWithIndexes:dragRows tableColumns:tableColumns event:dragEvent offset:dragImageOffset];
}

- (NSMenu *) menuForEvent:(NSEvent *)event
{
	NSPoint		location		= [event locationInWindow];
	NSPoint		localLocation	= [self convertPoint:location fromView:nil];
	int			row				= [self rowAtPoint:localLocation];
	BOOL		shiftPressed	= 0 != ([event modifierFlags] & NSShiftKeyMask);
//	BOOL		commandPressed	= 0 != ([event modifierFlags] & NSCommandKeyMask);

	if(-1 != row) {
		
		// If a row contained in the selection was right-clicked, don't change anything
		if(NO == [[self selectedRowIndexes] containsIndex:row]) {
			if([[self delegate] respondsToSelector:@selector(tableView:shouldSelectRow:)] && [[self delegate] tableView:self shouldSelectRow:row]) {
				[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:shiftPressed];
			}
			else {
				[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:shiftPressed];
			}			
		}
		
		return [self menu];
	}
	
	return nil;
}

- (void) drawRect:(NSRect)drawRect
{
	[super drawRect:drawRect];
	
	// Draw the empty message
	if(nil != [self emptyMessage] && 0 == [self numberOfRows]) {
		NSRect	rect	= [self frame];
		float	deltaY	= rect.size.height / 2;
		float	deltaX	= rect.size.width / 2;
		
		rect.origin.y		+= deltaY / 2;
		rect.origin.x		+= deltaX / 2;
		rect.size.height	-= deltaY;
		rect.size.width		-= deltaX;
		
		if(NO == NSIsEmptyRect(rect)) {
			NSDictionary	*attributes		= nil;
			NSString		*empty			= [self emptyMessage];
			NSRect			bounds			= NSZeroRect;
			float			fontSize		= 36;
			
			do {
				attributes = [NSDictionary dictionaryWithObjectsAndKeys:
					[NSFont systemFontOfSize:fontSize], NSFontAttributeName,
					[[NSColor blackColor] colorWithAlphaComponent:0.4], NSForegroundColorAttributeName,
					nil];
				
				bounds = [empty boundingRectWithSize:rect.size options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes];
				
				fontSize -= 2;
				
			} while(bounds.size.width > rect.size.width || bounds.size.height > rect.size.height);
			
			NSRect drawRect = NSInsetRect(rect, (rect.size.width - bounds.size.width) / 2, (rect.size.height - bounds.size.height) / 2);
			
			[empty drawWithRect:drawRect options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes];
		}
	}
}

- (IBAction) addToPlayQueue:(id)sender
{
	NSArray *streams = [_streamController selectedObjects];
	
	if(0 == [streams count]) {
		NSBeep();
		return;
	}

	[[AudioLibrary library] addStreamsToPlayQueue:streams];
}

- (IBAction) streamInformation:(id)sender
{
	NSArray *streams = [_streamController selectedObjects];

	if(1 != [streams count]) {
		NSBeep();
		return;
	}
	
	AudioStreamInformationSheet *streamInformationSheet = [[AudioStreamInformationSheet alloc] init];
	
	[streamInformationSheet setValue:[streams objectAtIndex:0] forKey:@"stream"];
	
	[[NSApplication sharedApplication] beginSheet:[streamInformationSheet sheet] 
								   modalForWindow:[self window] 
									modalDelegate:self 
								   didEndSelector:@selector(showStreamInformationSheetDidEnd:returnCode:contextInfo:) 
									  contextInfo:streamInformationSheet];
}

- (IBAction) resetPlayCount:(id)sender
{
	NSArray *streams = [_streamController selectedObjects];
	
	if(0 == [streams count]) {
		NSBeep();
		return;
	}

	[[CollectionManager manager] beginUpdate];
	[[_streamController selectedObjects] makeObjectsPerformSelector:@selector(resetPlayCount:) withObject:sender];
	[[CollectionManager manager] finishUpdate];
}

- (IBAction) resetSkipCount:(id)sender
{
	NSArray *streams = [_streamController selectedObjects];
	
	if(0 == [streams count]) {
		NSBeep();
		return;
	}
	
	[[CollectionManager manager] beginUpdate];
	[[_streamController selectedObjects] makeObjectsPerformSelector:@selector(resetSkipCount:) withObject:sender];
	[[CollectionManager manager] finishUpdate];
}

- (IBAction) editMetadata:(id)sender
{
	NSArray *streams = [_streamController selectedObjects];
	
	if(0 == [streams count]) {
		NSBeep();
		return;
	}
	
	// Sync with disk before updating
//	[self rescanMetadata:sender];
	
	AudioMetadataEditingSheet *metadataEditingSheet = [[AudioMetadataEditingSheet alloc] init];
	
	[metadataEditingSheet setValue:[_streamController selection] forKey:@"streams"];
	[metadataEditingSheet setValue:[[[CollectionManager manager] streamManager] streams] forKey:@"allStreams"];
	
	[[CollectionManager manager] beginUpdate];
	
	[[NSApplication sharedApplication] beginSheet:[metadataEditingSheet sheet] 
								   modalForWindow:[self window] 
									modalDelegate:self 
								   didEndSelector:@selector(showMetadataEditingSheetDidEnd:returnCode:contextInfo:) 
									  contextInfo:metadataEditingSheet];
}

- (IBAction) rescanMetadata:(id)sender
{
	if(0 == [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
	[[CollectionManager manager] beginUpdate];
	[[_streamController selectedObjects] makeObjectsPerformSelector:@selector(rescanMetadata:) withObject:sender];
	[[CollectionManager manager] finishUpdate];
}

- (IBAction) saveMetadata:(id)sender
{
	if(0 == [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
	[[_streamController selectedObjects] makeObjectsPerformSelector:@selector(saveMetadata:) withObject:sender];
}

- (IBAction) calculateTrackReplayGain:(id)sender
{
	if(0 == [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
	[self performReplayGainCalculationForStreams:[_streamController selectedObjects] calculateAlbumGain:NO];
}

- (IBAction) calculateTrackAndAlbumReplayGain:(id)sender
{
	if(0 == [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}

	[self performReplayGainCalculationForStreams:[_streamController selectedObjects] calculateAlbumGain:YES];
}

- (IBAction) clearReplayGain:(id)sender
{
	if(0 == [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
	[[CollectionManager manager] beginUpdate];
	[[_streamController selectedObjects] makeObjectsPerformSelector:@selector(clearReplayGain:) withObject:sender];
	[[CollectionManager manager] finishUpdate];
}

- (IBAction) remove:(id)sender
{
	if(NO == [_streamController canRemove] || 0 == [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
	[[CollectionManager manager] beginUpdate];
	[_streamController remove:sender];
	[[CollectionManager manager] finishUpdate];
}

- (IBAction) openWithFinder:(id)sender
{
	NSEnumerator	*enumerator		= [[_streamController selectedObjects] objectEnumerator];
	AudioStream		*stream			= nil;
	NSString		*path			= nil;
	
	while((stream = [enumerator nextObject])) {
		path = [[stream valueForKey:StreamURLKey] path];
		[[NSWorkspace sharedWorkspace] openFile:path];
	}
}

- (IBAction) revealInFinder:(id)sender
{
	NSEnumerator	*enumerator		= [[_streamController selectedObjects] objectEnumerator];
	AudioStream		*stream			= nil;
	NSString		*path			= nil;
	
	while((stream = [enumerator nextObject])) {
		path = [[stream valueForKey:StreamURLKey] path];
		[[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:nil];
	}
}

- (IBAction) convertWithMax:(id)sender
{
	NSEnumerator	*enumerator		= [[_streamController selectedObjects] objectEnumerator];
	AudioStream		*stream			= nil;
	NSString		*path			= nil;
	
	while((stream = [enumerator nextObject])) {
		path = [[stream valueForKey:StreamURLKey] path];
		[[NSWorkspace sharedWorkspace] openFile:path withApplication:@"Max"];
	}
}

- (IBAction) openWith:(id)sender
{
	NSOpenPanel		*panel				= [NSOpenPanel openPanel];
	NSArray			*paths				= NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES);
	NSString		*applicationFolder	= (0 == [paths count] ? nil : [paths objectAtIndex:0]);
	
	[panel beginSheetForDirectory:applicationFolder 
							 file:nil
							types:[NSArray arrayWithObject:@"app"] 
				   modalForWindow:[self window] 
					modalDelegate:self 
				   didEndSelector:@selector(openWithPanelDidEnd:returnCode:contextInfo:) 
					  contextInfo:NULL];	
}

- (IBAction) insertPlaylistWithSelection:(id)sender
{
	NSDictionary	*initialValues		= [NSDictionary dictionaryWithObject:NSLocalizedStringFromTable(@"Untitled Playlist", @"Library", @"") forKey:PlaylistNameKey];
	NSArray			*streamsToInsert	= [_streamController selectedObjects];
	Playlist		*playlist			= [Playlist insertPlaylistWithInitialValues:initialValues];
	
	if(nil != playlist) {
		[playlist addStreams:streamsToInsert];
		
//		[_browserDrawer open:self];
		/*
		 NSEnumerator *enumerator = [[_browserController arrangedObjects] objectEnumerator];
		 id opaqueNode;
		 while((opaqueNode = [enumerator nextObject])) {
			 id node = [opaqueNode observedObject];
			 if([node isKindOfClass:[PlaylistNode class]] && [node playlist] == playlist) {
				 NSLog(@"found node:%@",opaqueNode);
			 } 
		 }*/
		
		//		if([_browserController setSelectedObjects:[NSArray arrayWithObject:playlist]]) {
		//			// The playlist table has only one column for now
		//			[_browserOutlineView editColumn:0 row:[_browserOutlineView selectedRow] withEvent:nil select:YES];
		//		}
	}
	else {
		NSBeep();
		NSLog(@"Unable to create the playlist.");
	}
}

- (IBAction) doubleClickAction:(id)sender
{
	if(0 == [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
	if(0 == [[AudioLibrary library] countOfPlayQueue]) {
		[[AudioLibrary library] addStreamsToPlayQueue:[_streamController selectedObjects]];
		[[AudioLibrary library] playStreamAtIndex:0];
	}
	else {
		[[AudioLibrary library] addStreamsToPlayQueue:[_streamController selectedObjects]];
		
		// Alternate behavior
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"alwaysPlayStreamsWhenDoubleClicked"]) {
			[[AudioLibrary library] playStreamAtIndex:[[AudioLibrary library] countOfPlayQueue] - 1];
		}
	}
}

- (NSString *) emptyMessage
{
	if(0 == [[[[CollectionManager manager] streamManager] streams] count]) {
		return NSLocalizedStringFromTable(@"Library Empty", @"Library", @"");	
	}
	else {
		return NSLocalizedStringFromTable(@"Empty Selection", @"Library", @"");	
	}
}

@end

@implementation AudioStreamTableView (Private)

- (void) openWithPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{	
	if(NSOKButton == returnCode) {
		NSEnumerator	*enumerator			= nil;
		AudioStream		*stream				= nil;
		NSString		*path				= nil;
		NSArray			*applications		= [panel filenames];
		NSString		*applicationPath	= nil;
		unsigned		i;
		
		for(i = 0; i < [applications count]; ++i) {
			applicationPath		= [applications objectAtIndex:i];
			enumerator			= [[_streamController selectedObjects] objectEnumerator];
			
			while((stream = [enumerator nextObject])) {
				path = [[stream valueForKey:StreamURLKey] path];
				[[NSWorkspace sharedWorkspace] openFile:path withApplication:applicationPath];
			}
		}
	}
}

- (void) showStreamInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	AudioStreamInformationSheet *streamInformationSheet = (AudioStreamInformationSheet *)contextInfo;
	
	[sheet orderOut:self];
	[streamInformationSheet release];
}

- (void) showMetadataEditingSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	AudioMetadataEditingSheet *metadataEditingSheet = (AudioMetadataEditingSheet *)contextInfo;
	
	[sheet orderOut:self];
	
	if(NSOKButton == returnCode) {
		[[CollectionManager manager] finishUpdate];
		[_streamController rearrangeObjects];
	}
	else if(NSCancelButton == returnCode) {
		[[CollectionManager manager] cancelUpdate];
	}
	
	[metadataEditingSheet release];
}

- (void) performReplayGainCalculationForStreams:(NSArray *)streams calculateAlbumGain:(BOOL)calculateAlbumGain
{
	ReplayGainCalculationProgressSheet *progressSheet = [[ReplayGainCalculationProgressSheet alloc] init];
				
	[[NSApplication sharedApplication] beginSheet:[progressSheet sheet]
								   modalForWindow:[self window]
									modalDelegate:nil
								   didEndSelector:nil
									  contextInfo:nil];
	
	NSModalSession modalSession = [[NSApplication sharedApplication] beginModalSessionForWindow:[progressSheet sheet]];
	
	[progressSheet startProgressIndicator:self];
	[[CollectionManager manager] beginUpdate];
	calculateReplayGain(streams, calculateAlbumGain, modalSession);
	[[CollectionManager manager] finishUpdate];	
	[progressSheet stopProgressIndicator:self];
	
	[NSApp endModalSession:modalSession];
	
	[NSApp endSheet:[progressSheet sheet]];
	[[progressSheet sheet] close];
	[progressSheet release];
}

@end
