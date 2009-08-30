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
#import "AudioDecoder.h"

#import "AudioStreamInformationSheet.h"
#import "AudioMetadataEditingSheet.h"
#import "MusicBrainzMatchesSheet.h"
#import "MusicBrainzSearchSheet.h"
//#import "FileConversionSheet.h"

#import "CollectionManager.h"
#import "AudioStreamManager.h"

#import "SecondsFormatter.h"

#import "ReplayGainUtilities.h"
#import "CancelableProgressSheet.h"

#import "PUIDUtilities.h"
#import "MusicBrainzUtilities.h"

#import "CTBadge.h"

#import <AudioToolbox/AudioToolbox.h>
#import <QuickTime/QuickTime.h>

#define kMaximumStreamsForContextMenuAction 10
#define BUFFER_LENGTH 4096

#if DEBUG
static void 
dumpASBD(const AudioStreamBasicDescription *asbd)
{
	NSLog(@"mSampleRate         %f", asbd->mSampleRate);
	NSLog(@"mFormatID           %.4s", (const char *)(&asbd->mFormatID));
	NSLog(@"mFormatFlags        %u", asbd->mFormatFlags);
	NSLog(@"mBytesPerPacket     %u", asbd->mBytesPerPacket);
	NSLog(@"mFramesPerPacket    %u", asbd->mFramesPerPacket);
	NSLog(@"mBytesPerFrame      %u", asbd->mBytesPerFrame);
	NSLog(@"mChannelsPerFrame   %u", asbd->mChannelsPerFrame);
	NSLog(@"mBitsPerChannel     %u", asbd->mBitsPerChannel);
	NSLog(@"mReserved           %u", asbd->mReserved);
}
#endif

@interface AudioStreamTableView (Private)
- (void) openWithPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void) showStreamInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void) showMetadataEditingSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void) showMusicBrainzMatchesSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void) showMusicBrainzSearchSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void) performReplayGainCalculationForStreams:(NSArray *)streams calculateAlbumGain:(BOOL)calculateAlbumGain;
- (void) performPUIDCalculationForStreams:(NSArray *)streams;
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
	if([menuItem action] == @selector(addToPlayQueue:))
		return (0 != [[_streamController selectedObjects] count]);
	else if([menuItem action] == @selector(showInformationSheet:)) {
		if(1 == [[_streamController selectedObjects] count]) {
			[menuItem setTitle:NSLocalizedStringFromTable(@"Track Info", @"Menus", @"")];
			return YES;
		}
		else {
			[menuItem setTitle:NSLocalizedStringFromTable(@"No Selection", @"Menus", @"")];
			return NO;	
		}
	}
	else if([menuItem action] == @selector(resetPlayCount:))
		return (0 != [[_streamController selectedObjects] count]);
	else if([menuItem action] == @selector(resetSkipCount:))
		return (0 != [[_streamController selectedObjects] count]);
	else if([menuItem action] == @selector(editMetadata:))
		return (0 != [[_streamController selectedObjects] count]);
	else if([menuItem action] == @selector(rescanMetadata:))
		return (0 != [[_streamController selectedObjects] count]);
	else if([menuItem action] == @selector(saveMetadata:))
		return (0 != [[_streamController selectedObjects] count]);
	else if([menuItem action] == @selector(clearMetadata:))
		return (0 != [[_streamController selectedObjects] count]);
	else if([menuItem action] == @selector(calculateTrackReplayGain:))
		return (0 != [[_streamController selectedObjects] count]);
	else if([menuItem action] == @selector(calculateTrackAndAlbumReplayGain:))
		return (1 < [[_streamController selectedObjects] count]);
	else if([menuItem action] == @selector(clearReplayGain:))
		return (0 != [[_streamController selectedObjects] count]);
	else if([menuItem action] == @selector(determinePUIDs:)) {
		if(1 == [[_streamController selectedObjects] count])
			[menuItem setTitle:NSLocalizedStringFromTable(@"Determine PUID...", @"Menus", @"")];
		else
			[menuItem setTitle:NSLocalizedStringFromTable(@"Determine PUIDs...", @"Menus", @"")];
		return ((0 != [[_streamController selectedObjects] count]) && canConnectToMusicDNS());
	}
	else if([menuItem action] == @selector(lookupTrackInMusicBrainz:))
		return ((1 == [[_streamController selectedObjects] count]) && nil != [[_streamController selection] valueForKey:MetadataMusicDNSPUIDKey] && canConnectToMusicBrainz());
	else if([menuItem action] == @selector(searchMusicBrainzForMatchingTracks:))
		return ((1 == [[_streamController selectedObjects] count]) && canConnectToMusicBrainz());
	else if([menuItem action] == @selector(remove:))
		return [_streamController canRemove];
	else if([menuItem action] == @selector(browseTracksWithSameArtist:)) {
		if(1 == [[_streamController selectedObjects] count]) {
			NSString *artist = [[_streamController selection] valueForKey:MetadataArtistKey];
			if(nil == artist)
				[menuItem setTitle:NSLocalizedStringFromTable(@"No artist", @"Menus", @"")];
			else
				[menuItem setTitle:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Tracks by %@", @"Menus", @""), artist]];
			
			return (nil != artist);
		}
		else {
			[menuItem setTitle:NSLocalizedStringFromTable(@"Tracks by this artist", @"Menus", @"")];
			return NO;
		}
	}
	else if([menuItem action] == @selector(browseTracksWithSameAlbum:)) {
		if(1 == [[_streamController selectedObjects] count]) {
			NSString *albumTitle = [[_streamController selection] valueForKey:MetadataAlbumTitleKey];
			if(nil == albumTitle)
				[menuItem setTitle:NSLocalizedStringFromTable(@"No album", @"Menus", @"")];
			else
				[menuItem setTitle:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Tracks from \"%@\"", @"Menus", @""), albumTitle]];

			return (nil != albumTitle);
		}
		else {
			[menuItem setTitle:NSLocalizedStringFromTable(@"Tracks from this album", @"Menus", @"")];
			return NO;
		}
	}
	else if([menuItem action] == @selector(browseTracksWithSameComposer:)) {
		if(1 == [[_streamController selectedObjects] count]) {
			NSString *composer = [[_streamController selection] valueForKey:MetadataComposerKey];
			if(nil == composer)
				[menuItem setTitle:NSLocalizedStringFromTable(@"No composer", @"Menus", @"")];
			else
				[menuItem setTitle:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Tracks by %@", @"Menus", @""), composer]];
			
			return (nil != composer);
		}
		else {
			[menuItem setTitle:NSLocalizedStringFromTable(@"Tracks by this composer", @"Menus", @"")];
			return NO;
		}
	}
	else if([menuItem action] == @selector(browseTracksWithSameGenre:)) {
		if(1 == [[_streamController selectedObjects] count]) {
			NSString *genre = [[_streamController selection] valueForKey:MetadataGenreKey];
			if(nil == genre)
				[menuItem setTitle:NSLocalizedStringFromTable(@"No genre", @"Menus", @"")];
			else
				[menuItem setTitle:[NSString stringWithFormat:NSLocalizedStringFromTable(@"%@ tracks", @"Menus", @""), genre]];
				
			return (nil != genre);
		}
		else {
			[menuItem setTitle:NSLocalizedStringFromTable(@"Tracks of this genre", @"Menus", @"")];
			return NO;
		}
	}
	else if([menuItem action] == @selector(addTracksWithSameArtistToPlayQueue:)) {
		if(1 == [[_streamController selectedObjects] count]) {
			NSString *artist = [[_streamController selection] valueForKey:MetadataArtistKey];
			if(nil == artist)
				[menuItem setTitle:NSLocalizedStringFromTable(@"No artist", @"Menus", @"")];
			else
				[menuItem setTitle:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Tracks by %@", @"Menus", @""), artist]];
			
			return (nil != artist);
		}
		else {
			[menuItem setTitle:NSLocalizedStringFromTable(@"Tracks by this artist", @"Menus", @"")];
			return NO;
		}
	}
	else if([menuItem action] == @selector(addTracksWithSameAlbumToPlayQueue:)) {
		if(1 == [[_streamController selectedObjects] count]) {
			NSString *albumTitle = [[_streamController selection] valueForKey:MetadataAlbumTitleKey];
			if(nil == albumTitle)
				[menuItem setTitle:NSLocalizedStringFromTable(@"No album", @"Menus", @"")];
			else
				[menuItem setTitle:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Tracks from \"%@\"", @"Menus", @""), albumTitle]];
			
			return (nil != albumTitle);
		}
		else {
			[menuItem setTitle:NSLocalizedStringFromTable(@"Tracks from this album", @"Menus", @"")];
			return NO;
		}
	}
	else if([menuItem action] == @selector(addTracksWithSameComposerToPlayQueue:)) {
		if(1 == [[_streamController selectedObjects] count]) {
			NSString *composer = [[_streamController selection] valueForKey:MetadataComposerKey];
			if(nil == composer)
				[menuItem setTitle:NSLocalizedStringFromTable(@"No composer", @"Menus", @"")];
			else
				[menuItem setTitle:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Tracks by %@", @"Menus", @""), composer]];
			
			return (nil != composer);
		}
		else {
			[menuItem setTitle:NSLocalizedStringFromTable(@"Tracks by this composer", @"Menus", @"")];
			return NO;
		}
	}
	else if([menuItem action] == @selector(addTracksWithSameGenreToPlayQueue:)) {
		if(1 == [[_streamController selectedObjects] count]) {
			NSString *genre = [[_streamController selection] valueForKey:MetadataGenreKey];
			if(nil == genre)
				[menuItem setTitle:NSLocalizedStringFromTable(@"No genre", @"Menus", @"")];
			else
				[menuItem setTitle:[NSString stringWithFormat:NSLocalizedStringFromTable(@"%@ tracks", @"Menus", @""), genre]];
			
			return (nil != genre);
		}
		else {
			[menuItem setTitle:NSLocalizedStringFromTable(@"Tracks of this genre", @"Menus", @"")];
			return NO;
		}
	}
	else if([menuItem action] == @selector(insertPlaylistWithSelection:))
		return (/*[_browserController canInsert] && */0 != [[_streamController selectedObjects] count]);
	else if([menuItem action] == @selector(convert:))
		return (1 == [[_streamController selectedObjects] count]);
	else if([menuItem action] == @selector(convertWithMax:))
		return (nil != [[NSWorkspace sharedWorkspace] fullPathForApplication:@"Max"] && kMaximumStreamsForContextMenuAction >= [[_streamController selectedObjects] count]);
	else if([menuItem action] == @selector(editWithTag:))
		return (nil != [[NSWorkspace sharedWorkspace] fullPathForApplication:@"Tag"] && kMaximumStreamsForContextMenuAction >= [[_streamController selectedObjects] count]);
	else if([menuItem action] == @selector(revealInFinder:)
			|| [menuItem action] == @selector(openWithFinder:)
			|| [menuItem action] == @selector(openWith:))
		return (kMaximumStreamsForContextMenuAction >= [[_streamController selectedObjects] count]);

	return YES;
}

- (void) keyDown:(NSEvent *)event
{
	unichar			key		= [[event charactersIgnoringModifiers] characterAtIndex:0];    
	unsigned int	flags	= [event modifierFlags] & 0x00FF;

	if(0x0020 == key && 0 == flags)
		[[AudioLibrary library] playPause:self];
	else if(NSCarriageReturnCharacter == key && 0 == flags)
		[self doubleClickAction:event];
	else if(0xF702 == key && 0 == flags)
		[[AudioLibrary library] skipBackward:self];
	else if(0xF703 == key && 0 == flags)
		[[AudioLibrary library] skipForward:self];
	else if((NSDeleteCharacter == key || NSBackspaceCharacter == key || 0xF728 == key) && 0 == flags)
		[self remove:event];
	else
		[super keyDown:event]; // let somebody else handle the event 
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
				
		return [dragImage autorelease];
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
			if([[self delegate] respondsToSelector:@selector(tableView:shouldSelectRow:)] && [[self delegate] tableView:self shouldSelectRow:row])
				[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:shiftPressed];
			else
				[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:shiftPressed];
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

- (IBAction) showInformationSheet:(id)sender
{
	if(1 != [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
	AudioStreamInformationSheet *streamInformationSheet = [[AudioStreamInformationSheet alloc] init];
	NSArrayController *streamController = [streamInformationSheet valueForKey:@"streamController"];
	NSArray *streams = [[_streamController arrangedObjects] copy];
	[streamController setContent:[streams autorelease]];
	[streamController setSelectionIndex:[_streamController selectionIndex]];

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
	if(0 == [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
	// Sync with disk before updating
//	[self rescanMetadata:sender];
	
	AudioMetadataEditingSheet *metadataEditingSheet = [[AudioMetadataEditingSheet alloc] init];

	NSArrayController *allStreamsController = [metadataEditingSheet valueForKey:@"allStreamsController"];
	[allStreamsController setContent:[[[CollectionManager manager] streamManager] streams]];
	
	NSArrayController *streamController = [metadataEditingSheet valueForKey:@"streamController"];
	NSArray *streams = [[_streamController arrangedObjects] copy];
	[streamController setContent:[streams autorelease]];
	[streamController setSelectionIndexes:[_streamController selectionIndexes]];
		
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

- (IBAction) clearMetadata:(id)sender
{
	if(0 == [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
	[[_streamController selectedObjects] makeObjectsPerformSelector:@selector(clearMetadata:) withObject:sender];
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
	if(1 >= [[_streamController selectedObjects] count]) {
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

- (IBAction) determinePUIDs:(id)sender
{
	if(0 == [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
	if(NO == canConnectToMusicDNS()) {
		NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
		
		[errorDictionary setObject:NSLocalizedStringFromTable(@"You are not connected to the internet.", @"Errors", @"") forKey:NSLocalizedDescriptionKey];
		[errorDictionary setObject:NSLocalizedStringFromTable(@"Not connected to the internet", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
		[errorDictionary setObject:NSLocalizedStringFromTable(@"An internet connection is required to map OFA fingerprints to MusicDNS PUIDs.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
		
		NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain 
											 code:0 
										 userInfo:errorDictionary];

		NSAlert *alert = [NSAlert alertWithError:error];
		[alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];

		return;
	}
	
	NSArray *streams = [[_streamController selectedObjects] copy];
	[self performPUIDCalculationForStreams:[streams autorelease]];
}

- (IBAction) lookupTrackInMusicBrainz:(id)sender
{
	if(1 != [[_streamController selectedObjects] count] || nil == [[_streamController selection] valueForKey:MetadataMusicDNSPUIDKey]) {
		NSBeep();
		return;
	}
	
	if(NO == canConnectToMusicBrainz()) {
		NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
		
		[errorDictionary setObject:NSLocalizedStringFromTable(@"You are not connected to the internet.", @"Errors", @"") forKey:NSLocalizedDescriptionKey];
		[errorDictionary setObject:NSLocalizedStringFromTable(@"Not connected to the internet", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
		[errorDictionary setObject:NSLocalizedStringFromTable(@"An internet connection is required to use MusicBrainz.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
		
		NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain 
											 code:0 
										 userInfo:errorDictionary];
		
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
		
		return;
	}
	
	MusicBrainzMatchesSheet	*matchesSheet	= [[MusicBrainzMatchesSheet alloc] init];
	AudioStream				*stream			= [[_streamController selectedObjects] lastObject];
	
	[matchesSheet setPUID:[stream valueForKey:MetadataMusicDNSPUIDKey]];
	
	[[NSApplication sharedApplication] beginSheet:[matchesSheet sheet] 
								   modalForWindow:[self window] 
									modalDelegate:self 
								   didEndSelector:@selector(showMusicBrainzMatchesSheetDidEnd:returnCode:contextInfo:) 
									  contextInfo:matchesSheet];
	
	[matchesSheet search:sender];
}

- (IBAction) searchMusicBrainzForMatchingTracks:(id)sender
{
	if(1 != [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
	if(NO == canConnectToMusicBrainz()) {
		NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
		
		[errorDictionary setObject:NSLocalizedStringFromTable(@"You are not connected to the internet.", @"Errors", @"") forKey:NSLocalizedDescriptionKey];
		[errorDictionary setObject:NSLocalizedStringFromTable(@"Not connected to the internet", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
		[errorDictionary setObject:NSLocalizedStringFromTable(@"An internet connection is required to use MusicBrainz.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
		
		NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain 
											 code:0 
										 userInfo:errorDictionary];
		
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
		
		return;
	}
	
	MusicBrainzSearchSheet	*searchSheet	= [[MusicBrainzSearchSheet alloc] init];
	AudioStream				*stream			= [[_streamController selectedObjects] lastObject];

	[searchSheet setTitle:[stream valueForKey:MetadataTitleKey]];
	[searchSheet setArtist:[stream valueForKey:MetadataArtistKey]];
	[searchSheet setAlbumTitle:[stream valueForKey:MetadataAlbumTitleKey]];
	[searchSheet setDuration:[stream duration]];

	[[NSApplication sharedApplication] beginSheet:[searchSheet sheet] 
								   modalForWindow:[self window] 
									modalDelegate:self 
								   didEndSelector:@selector(showMusicBrainzSearchSheetDidEnd:returnCode:contextInfo:) 
									  contextInfo:searchSheet];

	[searchSheet search:sender];
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

- (IBAction) browseTracksWithSameArtist:(id)sender
{
	if(1 != [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}

	[[AudioLibrary library] browseTracksByArtist:[[_streamController selection] valueForKey:MetadataArtistKey]];
}

- (IBAction) browseTracksWithSameAlbum:(id)sender
{
	if(1 != [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}

	[[AudioLibrary library] browseTracksByAlbum:[[_streamController selection] valueForKey:MetadataAlbumTitleKey]];
}

- (IBAction) browseTracksWithSameComposer:(id)sender
{
	if(1 != [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
	[[AudioLibrary library] browseTracksByComposer:[[_streamController selection] valueForKey:MetadataComposerKey]];
}

- (IBAction) browseTracksWithSameGenre:(id)sender
{
	if(1 != [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
	[[AudioLibrary library] browseTracksByGenre:[[_streamController selection] valueForKey:MetadataGenreKey]];
}

- (IBAction) addTracksWithSameArtistToPlayQueue:(id)sender
{
	if(1 != [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
	[[AudioLibrary library] addTracksToPlayQueueByArtist:[[_streamController selection] valueForKey:MetadataArtistKey]];
}

- (IBAction) addTracksWithSameAlbumToPlayQueue:(id)sender
{
	if(1 != [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
	[[AudioLibrary library] addTracksToPlayQueueByAlbum:[[_streamController selection] valueForKey:MetadataAlbumTitleKey]];
}

- (IBAction) addTracksWithSameComposerToPlayQueue:(id)sender
{
	if(1 != [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
	[[AudioLibrary library] addTracksToPlayQueueByComposer:[[_streamController selection] valueForKey:MetadataComposerKey]];
}

- (IBAction) addTracksWithSameGenreToPlayQueue:(id)sender
{
	if(1 != [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
	[[AudioLibrary library] addTracksToPlayQueueByGenre:[[_streamController selection] valueForKey:MetadataGenreKey]];
}

- (IBAction) openWithFinder:(id)sender
{
	NSString		*path			= nil;
	
	for(AudioStream *stream in [_streamController selectedObjects]) {
		path = [[stream valueForKey:StreamURLKey] path];
		[[NSWorkspace sharedWorkspace] openFile:path];
	}
}

- (IBAction) revealInFinder:(id)sender
{
	NSString		*path			= nil;
	
	for(AudioStream *stream in [_streamController selectedObjects]) {
		path = [[stream valueForKey:StreamURLKey] path];
		[[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:nil];
	}
}

- (IBAction) convert:(id)sender
{
	if(1 != [[_streamController selectedObjects] count]) {
		NSBeep();
		return;
	}
	
#if 0
	FileConversionSheet *fileConversionSheet = [[FileConversionSheet alloc] init];

	[[NSApplication sharedApplication] beginSheet:[fileConversionSheet sheet] 
								   modalForWindow:[self window] 
									modalDelegate:self 
								   didEndSelector:@selector(showFileConversionSheetDidEnd:returnCode:contextInfo:) 
									  contextInfo:fileConversionSheet];
#endif
#if 0
	// Create a decoder for the desired stream
	NSError *error = nil;
	AudioDecoder *decoder = [AudioDecoder audioDecoderForStream:[_streamController selection] error:&error];

	if(nil == decoder) {
		if(nil != error)
			[self presentError:error modalForWindow:[self window] delegate:nil didPresentSelector:NULL contextInfo:NULL];
		return;
	}
	
	ComponentInstance	component				= 0;
	AudioConverterRef	myAudioConverter		= NULL;	
	CFArrayRef			codecSpecificSettings	= NULL;
	UInt32				magicCookieSize			= 0;
	void				*magicCookie			= NULL;	
	UInt32				flags;
	
	// open StdAudio (added in QuickTime 7.0)
	OSErr err = OpenADefaultComponent(StandardCompressionType, 
									  StandardCompressionSubTypeAudio, 
									  &component);
	if(noErr != err)
		goto bail;
	
	AudioStreamBasicDescription		format			= [decoder sourceFormat];
	AudioChannelLayout				channelLayout	= [decoder channelLayout];

	err = QTSetComponentProperty(component, 
								 kQTPropertyClass_SCAudio,
								 kQTSCAudioPropertyID_InputBasicDescription,
								 sizeof(format), 
								 &format);
	if(noErr != err)
		goto bail;

	err = QTSetComponentProperty(component, 
								 kQTPropertyClass_SCAudio,
								 kQTSCAudioPropertyID_InputChannelLayout,
								 sizeof(channelLayout), 
								 &channelLayout);
	if(noErr != err)
		goto bail;

	// Show the configuration dialog
	err = SCRequestImageSettings(component);
	if(noErr != err)
		goto bail;

	AudioStreamBasicDescription		outputFormat;
	AudioChannelLayout				*outputChannelLayout = NULL;

	// Get the configuration properties from the dialog
	err = QTGetComponentPropertyInfo(component,
									 kQTPropertyClass_SCAudio,
									 kQTSCAudioPropertyID_BasicDescription,
									 NULL, 
									 NULL, 
									 &flags);
	   
   if(noErr == err && (kComponentPropertyFlagCanGetNow & flags)) {	
	   err = QTGetComponentProperty(component, 
									kQTPropertyClass_SCAudio,
									kQTSCAudioPropertyID_BasicDescription,
									sizeof(outputFormat), 
									&outputFormat, 
									NULL);
	   
	   if(noErr != err)
		   goto bail;
	}

/*   UInt32 propValueSize = 0;
   err = QTGetComponentPropertyInfo(component,
									kQTPropertyClass_SCAudio,
									kQTSCAudioPropertyID_ChannelLayout,
									NULL, 
									&propValueSize, 
									&flags);
   
   if(noErr == err && (kComponentPropertyFlagCanGetNow & flags)) {
	   outputChannelLayout = malloc(propValueSize);
	   
	   err = QTGetComponentProperty(component, 
									kQTPropertyClass_SCAudio,
									kQTSCAudioPropertyID_ChannelLayout,
									sizeof(outputChannelLayout), 
									&outputChannelLayout, 
									NULL);
	   
	   if(noErr != err)
		   goto bail;
   }*/
   
	// Get the codec specific settings (if available)
	err = QTGetComponentPropertyInfo(component,
									 kQTPropertyClass_SCAudio,
									 kQTSCAudioPropertyID_CodecSpecificSettingsArray,
									 NULL, 
									 NULL, 
									 &flags);
   
   if(noErr == err && (kComponentPropertyFlagCanGetNow & flags)) {	
	   err = QTGetComponentProperty(component,
									kQTPropertyClass_SCAudio,
									kQTSCAudioPropertyID_CodecSpecificSettingsArray,
									sizeof(CFArrayRef), 
									&codecSpecificSettings, 
									NULL);
	   if(noErr != err)
		   goto bail;
	}
	
	// Get the magic cookie (if available)
	err = QTGetComponentPropertyInfo(component,
									 kQTPropertyClass_SCAudio,
									 kQTSCAudioPropertyID_MagicCookie,
									 NULL, 
									 &magicCookieSize, 
									 NULL);

	if(noErr == err && 0 != magicCookieSize) {

		magicCookie = calloc(1, magicCookieSize);
		if(NULL == magicCookie) {
			err = memFullErr; 
			goto bail;
		}

		err = QTGetComponentProperty(component,
									 kQTPropertyClass_SCAudio,
									 kQTSCAudioPropertyID_MagicCookie,
									 magicCookieSize, 
									 magicCookie, 
									 &magicCookieSize);
		if(noErr != err)
			goto bail;
	}

	// Once we have all the required properties close StdAudio
	CloseComponent(component), component = 0;
	
	// Determine the allowed file types for this ASBD
	
	// First, get the writable types
	UInt32 writableTypeSize;
	err = AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_WritableTypes, 0, NULL, &writableTypeSize);
	
	UInt32 *writableTypes = malloc(writableTypeSize);
	
	UInt32 numWritableTypes = writableTypeSize / sizeof(UInt32);
	err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_WritableTypes, 0, NULL, &writableTypeSize, writableTypes);

	if(noErr != err)
		goto bail;
	
	AudioFileTypeID outputTypeID;
	
	// Iterate through them and determine which support this format
	unsigned i;
	for(i = 0; i < numWritableTypes; ++i) {
		AudioFileTypeAndFormatID typeAndFormatID;
		
		typeAndFormatID.mFileType = writableTypes[i];
		typeAndFormatID.mFormatID = outputFormat.mFormatID;
		
		UInt32 availableStreamDescriptionsSize;
		err = AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat, sizeof(typeAndFormatID), &typeAndFormatID, &availableStreamDescriptionsSize);
		if(noErr != err)
			continue;
		
		AudioStreamBasicDescription *availableStreamDescriptions = malloc(availableStreamDescriptionsSize);
		
		UInt32 numAvailableStreamDescriptions = availableStreamDescriptionsSize / sizeof(AudioStreamBasicDescription);
		err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat, sizeof(typeAndFormatID), &typeAndFormatID, &availableStreamDescriptionsSize, availableStreamDescriptions);
		
		unsigned j;
		for(j = 0; j < numAvailableStreamDescriptions; ++j) {
			AudioFileTypeID		typeID				= typeAndFormatID.mFileType;
			CFStringRef			fileTypeName		= nil;
			UInt32				fileTypeNameSize	= sizeof(fileTypeName);
			
			err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_FileTypeName, sizeof(typeID), &typeID, &fileTypeNameSize, &fileTypeName);

			NSLog(@"Match: %@",fileTypeName);
						
			CFArrayRef			fileTypeExtensions		= nil;
			UInt32				fileTypeExtensionsSize	= sizeof(fileTypeExtensions);
			
			err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_ExtensionsForType, sizeof(typeID), &typeID, &fileTypeExtensionsSize, &fileTypeExtensions);
			
			NSLog(@"Extensions: %@", fileTypeExtensions);
			
			outputTypeID = typeID;
				
		}
		
		free(availableStreamDescriptions), availableStreamDescriptions = NULL;
	}
	
	free(writableTypes), writableTypes = NULL;
	
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	
	NSPopUpButton *view = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,0,100,50)];
	
	[view addItemWithTitle:@"foo"];
	[view addItemWithTitle:@"bar"];
	[view addItemWithTitle:@"fnord"];
	
	[savePanel setAccessoryView:[view autorelease]];
	
	if(NSOKButton == [savePanel runModal]) {
		
		ExtAudioFileRef outputExtAudioFile;
		
		NSURL		*fileURL		= [savePanel URL];
		NSString	*filePath		= [fileURL path];
		NSString	*fileDirectory	= [filePath stringByDeletingLastPathComponent];
		NSString	*fileName		= [filePath lastPathComponent];
		
		FSRef fileDirectoryFSRef;
		err = FSPathMakeRef([fileDirectory UTF8String], &fileDirectoryFSRef, NULL);
		if(noErr != err)
			goto bail;
		
		err = ExtAudioFileCreateNew(&fileDirectoryFSRef, fileName, outputTypeID, &outputFormat, NULL, &outputExtAudioFile);
		if(noErr != err)
			goto bail;
		
		AudioStreamBasicDescription clientFormat = [decoder format];
		err = ExtAudioFileSetProperty(outputExtAudioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(clientFormat), &clientFormat);
		if(noErr != err)
			goto bail;

//		AudioConverterRef audioConverter;
//		UInt32 dataSize = sizeof(audioConverter);
//		err = ExtAudioFileGetProperty(outputExtAudioFile, kExtAudioFileProperty_AudioConverter, &dataSize, &audioConverter);
//		if(noErr != err)
//			goto bail;
		
		if(NULL != codecSpecificSettings) {
			err = ExtAudioFileSetProperty(outputExtAudioFile, kExtAudioFileProperty_ConverterConfig, sizeof(codecSpecificSettings), &codecSpecificSettings);
			if(noErr != err)
				goto bail;
			
			CFRelease(codecSpecificSettings);
		}
		
		// Allocate the AudioBufferList for the decoder
		AudioBufferList *bufferList = calloc(sizeof(AudioBufferList) + (sizeof(AudioBuffer) * (clientFormat.mChannelsPerFrame - 1)), 1);
		NSAssert(NULL != bufferList, @"Unable to allocate memory");
		
		bufferList->mNumberBuffers = clientFormat.mChannelsPerFrame;
		
		for(i = 0; i < bufferList->mNumberBuffers; ++i) {
			bufferList->mBuffers[i].mData = calloc(BUFFER_LENGTH, sizeof(float));
			NSCAssert(NULL != bufferList->mBuffers[i].mData, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
			bufferList->mBuffers[i].mDataByteSize = BUFFER_LENGTH * sizeof(float);
			bufferList->mBuffers[i].mNumberChannels = 1;
		}
				
		// Process the file
		for(;;) {
			// Reset read parameters
			for(i = 0; i < bufferList->mNumberBuffers; ++i)
				bufferList->mBuffers[i].mDataByteSize = BUFFER_LENGTH * sizeof(float);
			
			// Read some audio
			UInt32 framesRead = [decoder readAudio:bufferList frameCount:BUFFER_LENGTH];
			if(0 == framesRead)
				break;

			// Write it out
			err = ExtAudioFileWrite(outputExtAudioFile, framesRead, bufferList);
			if(noErr != err)
				goto bail;
		}			
		
		for(i = 0; i < bufferList->mNumberBuffers; ++i)
			free(bufferList->mBuffers[i].mData);
		free(bufferList);
		
		err = ExtAudioFileDispose(outputExtAudioFile);
		if(noErr != err)
			goto bail;
	}
	
	// create an AudioConverter
	//		err = AudioConverterNew(&myInputASBD, &myOutputASBD, &myAudioConverter);
	//		if (err) goto bail;
	
	// set other Audio Converter properties such as channel layout and so on
	//		...
	
	// a codec that has CodecSpecificSettings may have a MagicCookie
	// prefer the CodecSpecificSettingsArray if you have both
	/*			if (NULL != codecSpecificSettings) {
		
		err = AudioConverterSetProperty(myAudioConverter,
										kAudioConverterPropertySettings,
										sizeof(CFArray),
										codecSpecificSettings);
				if (err) goto bail;
				
				CFRelease(codecSpecificSettings);
				
	} else if (NULL != magicCookie) {
		err = AudioConverterSetProperty(myAudioConverter,
										kAudioConverterCompressionMagicCookie,
										magicCookieSize,
										magicCookie);
		if (err) goto bail;
		
		// we may need the magic cookie later if we're going to write the data to a file
		// but make sure and remember to free it when we're done!
	}
	*/
	// continue with any other required setup
	//		...
	
bail:
	if(noErr != err) {
		if(codecSpecificSettings) 
			CFRelease(codecSpecificSettings);
		if(magicCookie) 
			free(magicCookie);
		if(component) 
			CloseComponent(component);
		if(myAudioConverter) 
			AudioConverterDispose(myAudioConverter);
	}
#endif
}

- (IBAction) convertWithMax:(id)sender
{
	NSString		*path			= nil;
	
	for(AudioStream *stream in [_streamController selectedObjects]) {
		path = [[stream valueForKey:StreamURLKey] path];
		[[NSWorkspace sharedWorkspace] openFile:path withApplication:@"Max"];
	}
}

- (IBAction) editWithTag:(id)sender
{
	NSString		*path			= nil;
	
	for(AudioStream *stream in [_streamController selectedObjects]) {
		path = [[stream valueForKey:StreamURLKey] path];
		[[NSWorkspace sharedWorkspace] openFile:path withApplication:@"Tag"];
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
	if(0 == [[[[CollectionManager manager] streamManager] streams] count])
		return NSLocalizedStringFromTable(@"Library Empty", @"Library", @"");	
	else
		return NSLocalizedStringFromTable(@"Empty Selection", @"Library", @"");	
}

@end

@implementation AudioStreamTableView (Private)

- (void) openWithPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{	
	if(NSOKButton == returnCode) {
		NSString		*path				= nil;
		NSArray			*applications		= [panel filenames];
		NSString		*applicationPath	= nil;
		unsigned		i;
		
		for(i = 0; i < [applications count]; ++i) {
			applicationPath		= [applications objectAtIndex:i];
			
			for(AudioStream *stream in [_streamController selectedObjects]) {
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
		// Once finishUpdate is called changedStreams will be empty, so determine which streams
		// were edited beforehand
		NSArray *changedStreams = [metadataEditingSheet changedStreams];
		[[CollectionManager manager] finishUpdate];

		[changedStreams makeObjectsPerformSelector:@selector(saveMetadata:) withObject:self];
		
		[_streamController rearrangeObjects];
	}
	else if(NSCancelButton == returnCode)
		[[CollectionManager manager] cancelUpdate];
	
	[metadataEditingSheet release];
}

- (void) showMusicBrainzMatchesSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	MusicBrainzMatchesSheet *matchesSheet = (MusicBrainzMatchesSheet *)contextInfo;
	
	[sheet orderOut:self];
	
	AudioStream *stream = [[_streamController selectedObjects] lastObject];

	if(NSOKButton == returnCode) {
		if(nil == [matchesSheet selectedMatch]) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The track was not found.", @"Errors", @"") forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"No matching tracks in MusicBrainz", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"This track was not found in MusicBrainz.  Please consider submitting it!", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain 
												 code:0 
											 userInfo:errorDictionary];
			
			NSAlert *alert = [NSAlert alertWithError:error];
			[alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
		}
		else {
			[[CollectionManager manager] beginUpdate];
			[stream setValuesForKeysWithDictionary:[matchesSheet selectedMatch]];
			[[CollectionManager manager] finishUpdate];
			
			[stream saveMetadata:self];
			
			[_streamController rearrangeObjects];
		}
	}
	
	[matchesSheet release];
}

- (void) showMusicBrainzSearchSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	MusicBrainzSearchSheet *searchSheet = (MusicBrainzSearchSheet *)contextInfo;
	
	[sheet orderOut:self];
	
	AudioStream *stream = [[_streamController selectedObjects] lastObject];

	if(NSOKButton == returnCode) {
		[[CollectionManager manager] beginUpdate];
		[stream setValuesForKeysWithDictionary:[searchSheet selectedMatch]];
		[[CollectionManager manager] finishUpdate];
		
		[stream saveMetadata:self];
		
		[_streamController rearrangeObjects];
	}
	
	[searchSheet release];
}

#if 0
- (void) showFileConversionSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	FileConversionSheet *fileConversionSheet = (FileConversionSheet *)contextInfo;
	
	[sheet orderOut:self];
	[fileConversionSheet release];
}
#endif

- (void) performReplayGainCalculationForStreams:(NSArray *)streams calculateAlbumGain:(BOOL)calculateAlbumGain
{
	CancelableProgressSheet *progressSheet = [[CancelableProgressSheet alloc] init];
	[progressSheet setLegend:NSLocalizedStringFromTable(@"Calculating Replay Gain...", @"Library", @"")];

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
	
	[streams makeObjectsPerformSelector:@selector(saveMetadata:) withObject:self];

	[NSApp endModalSession:modalSession];
	
	[NSApp endSheet:[progressSheet sheet]];
	[[progressSheet sheet] close];
	[progressSheet release];
}

- (void) performPUIDCalculationForStreams:(NSArray *)streams
{
	CancelableProgressSheet *progressSheet = [[CancelableProgressSheet alloc] init];
	[progressSheet setLegend:NSLocalizedStringFromTable(@"Determining PUID...", @"Library", @"")];
	
	[[NSApplication sharedApplication] beginSheet:[progressSheet sheet]
								   modalForWindow:[self window]
									modalDelegate:nil
								   didEndSelector:nil
									  contextInfo:nil];
	
	NSModalSession modalSession = [[NSApplication sharedApplication] beginModalSessionForWindow:[progressSheet sheet]];
	
	[progressSheet startProgressIndicator:self];
	[[CollectionManager manager] beginUpdate];
	calculateFingerprintsAndRequestPUIDs(streams, modalSession);
	[[CollectionManager manager] finishUpdate];
	[progressSheet stopProgressIndicator:self];
	
	[streams makeObjectsPerformSelector:@selector(saveMetadata:) withObject:self];
	
	[NSApp endModalSession:modalSession];
	
	[NSApp endSheet:[progressSheet sheet]];
	[[progressSheet sheet] close];
	[progressSheet release];
}

@end
