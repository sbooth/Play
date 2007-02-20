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

/*
 * Special thanks to Michael Ash for the code to dynamically show and hide
 * table columns.  Some of the code in the windowControllerDidLoadNib: method,
 * and most of the code in the tableViewColumnDidMove:, tableViewColumnDidResize:, 
 * saveStreamTableColumnOrder:, and streamTableHeaderContextMenuSelected: methods come from his
 * Creatures source code.  The copyright for those portions is:
 *
 * Copyright (c) 2005, Michael Ash
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of the author nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "AudioLibrary.h"

#import "AudioPlayer.h"

#import "CollectionManager.h"
#import "AudioStreamManager.h"
#import "AudioStream.h"
#import "Playlist.h"

#import "AudioPropertiesReader.h"
#import "AudioMetadataReader.h"
#import "AudioMetadataWriter.h"

#import "AudioStreamInformationSheet.h"
#import "AudioMetadataEditingSheet.h"
#import "StaticPlaylistInformationSheet.h"

#import "AudioStreamArrayController.h"
#import "BrowserTreeController.h"
#import "AudioStreamTableView.h"
#import "BrowserOutlineView.h"

#import "BrowserNode.h"
#import "AudioStreamCollectionNode.h"
#import "LibraryNode.h"
#import "CurrentStreamsNode.h"
#import "ArtistsNode.h"
#import "AlbumsNode.h"
#import "PlaylistsNode.h"
#import "PlaylistNode.h"

#import "IconFamily.h"
#import "ImageAndTextCell.h"

#import "NSTreeController_Extensions.h"

#include "sfmt19937.h"

// ========================================
// The global instance
// ========================================
static AudioLibrary *libraryInstance = nil;

// ========================================
// Notification names
// ========================================
NSString * const	AudioStreamAddedToLibraryNotification		= @"org.sbooth.Play.AudioLibrary.AudioStreamAddedToLibraryNotification";
NSString * const	AudioStreamRemovedFromLibraryNotification	= @"org.sbooth.Play.AudioLibrary.AudioStreamRemovedFromLibraryNotification";
NSString * const	AudioStreamPlaybackDidStartNotification		= @"org.sbooth.Play.AudioLibrary.AudioStreamPlaybackDidStartNotification";
NSString * const	AudioStreamPlaybackDidStopNotification		= @"org.sbooth.Play.AudioLibrary.AudioStreamPlaybackDidStopNotification";
NSString * const	AudioStreamPlaybackDidPauseNotification		= @"org.sbooth.Play.AudioLibrary.AudioStreamPlaybackDidPauseNotification";
NSString * const	AudioStreamPlaybackDidResumeNotification	= @"org.sbooth.Play.AudioLibrary.AudioStreamPlaybackDidResumeNotification";

NSString * const	PlaylistAddedToLibraryNotification			= @"org.sbooth.Play.AudioLibrary.PlaylistAddedToLibraryNotification";
NSString * const	PlaylistRemovedFromLibraryNotification		= @"org.sbooth.Play.AudioLibrary.PlaylistRemovedFromLibraryNotification";

// ========================================
// Notification keys
// ========================================
NSString * const	AudioStreamObjectKey						= @"org.sbooth.Play.AudioStream";
NSString * const	PlaylistObjectKey							= @"org.sbooth.Play.Playlist";

// ========================================
// Completely bogus NSTreeController bindings hack
// ========================================
@interface NSObject (NSTreeControllerBogosity)
- (id) observedObject;
@end

// ========================================
// Callback Methods (for sheets, etc.)
// ========================================
@interface AudioLibrary (CallbackMethods)
- (void) openDocumentSheetDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void *)contextInfo;
- (void) showStreamInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void) showMetadataEditingSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void) showStaticPlaylistInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end

// ========================================
// Private Methods
// ========================================
@interface AudioLibrary (Private)
- (AudioPlayer *) player;

- (void) scrollNowPlayingToVisible;

- (unsigned) playbackIndex;
- (void) setPlaybackIndex:(unsigned)playbackIndex;

- (unsigned) nextPlaybackIndex;
- (void) setNextPlaybackIndex:(unsigned)nextPlaybackIndex;

- (void) playStreamAtIndex:(unsigned)index;

- (void) setCurrentStreamsFromArray:(NSArray *)streams;

- (void) updatePlayButtonState;

- (void) setupBrowser;

- (void) setupStreamButtons;
- (void) setupPlaylistButtons;

- (void) setupStreamTableColumns;

- (void) saveStreamTableColumnOrder;
- (IBAction) streamTableHeaderContextMenuSelected:(id)sender;
@end

@implementation AudioLibrary

+ (void)initialize
{
	// Setup table column defaults
	NSDictionary *visibleColumnsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:NO], @"id",
		[NSNumber numberWithBool:YES], @"title",
		[NSNumber numberWithBool:YES], @"albumTitle",
		[NSNumber numberWithBool:YES], @"artist",
		[NSNumber numberWithBool:NO], @"albumArtist",
		[NSNumber numberWithBool:YES], @"genre",
		[NSNumber numberWithBool:YES], @"track",
		[NSNumber numberWithBool:NO], @"disc",
		[NSNumber numberWithBool:NO], @"fileType",
		[NSNumber numberWithBool:YES], @"formatType",
		[NSNumber numberWithBool:NO], @"composer",
		[NSNumber numberWithBool:YES], @"duration",
		[NSNumber numberWithBool:NO], @"playCount",
		[NSNumber numberWithBool:NO], @"lastPlayed",
		[NSNumber numberWithBool:NO], @"date",
		[NSNumber numberWithBool:NO], @"compilation",
		[NSNumber numberWithBool:NO], @"filename",
		nil];
	
	NSDictionary *columnSizesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithFloat:50], @"id",
		[NSNumber numberWithFloat:186], @"title",
		[NSNumber numberWithFloat:128], @"albumTitle",
		[NSNumber numberWithFloat:129], @"artist",
		[NSNumber numberWithFloat:129], @"albumArtist",
		[NSNumber numberWithFloat:63], @"genre",
		[NSNumber numberWithFloat:54], @"track",
		[NSNumber numberWithFloat:54], @"disc",
		[NSNumber numberWithFloat:88], @"fileType",
		[NSNumber numberWithFloat:88], @"formatType",
		[NSNumber numberWithFloat:99], @"composer",
		[NSNumber numberWithFloat:74], @"duration",
		[NSNumber numberWithFloat:72], @"playCount",
		[NSNumber numberWithFloat:96], @"lastPlayed",
		[NSNumber numberWithFloat:50], @"date",
		[NSNumber numberWithFloat:70], @"compilation",
		[NSNumber numberWithFloat:55], @"filename",
		nil];
	
	NSDictionary *columnOrderArray = [NSArray arrayWithObjects:
		@"title", @"artist", @"albumTitle", @"genre", @"track", @"formatType", nil];
	
	NSDictionary *streamTableDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
		visibleColumnsDictionary, @"streamTableColumnVisibility",
		columnSizesDictionary, @"streamTableColumnSizes",
		columnOrderArray, @"streamTableColumnOrder",
		nil];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:streamTableDefaults];
}	

+ (AudioLibrary *) library
{
	@synchronized(self) {
		if(nil == libraryInstance) {
			libraryInstance = [[self alloc] init];
		}
	}
	return libraryInstance;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == libraryInstance) {
            return [super allocWithZone:zone];
        }
    }
    return libraryInstance;
}

- (id) init
{
	if((self = [super initWithWindowNibName:@"AudioLibrary"])) {
		// Seed random number generator
		init_gen_rand(time(NULL));

		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
		NSAssert(nil != paths, NSLocalizedStringFromTable(@"Unable to locate the \"Application Support\" folder.", @"Errors", @""));
		
		NSString *applicationName			= [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
		NSString *applicationSupportFolder	= [[paths objectAtIndex:0] stringByAppendingPathComponent:applicationName];
		
		if(NO == [[NSFileManager defaultManager] fileExistsAtPath:applicationSupportFolder]) {
			BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:applicationSupportFolder attributes:nil];
			NSAssert(YES == success, NSLocalizedStringFromTable(@"Unable to create the \"Application Support\" folder.", @"Errors", @""));
		}
		
		NSString *databasePath = [applicationSupportFolder stringByAppendingPathComponent:@"Library.sqlite3"];
		
		[[CollectionManager manager] connectToDatabase:databasePath];
		
		_currentStreams = [[NSMutableArray alloc] init];
		
		[[[CollectionManager manager] streamManager] addObserver:self 
													  forKeyPath:@"streams"
														 options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
														 context:NULL];
	}
	return self;
}

- (void) dealloc
{
	[[[CollectionManager manager] streamManager] removeObserver:self forKeyPath:@"streams"];

	[[CollectionManager manager] disconnectFromDatabase];

	[_player release], _player = nil;

	[_streamTableVisibleColumns release], _streamTableVisibleColumns = nil;
	[_streamTableHiddenColumns release], _streamTableHiddenColumns = nil;
	[_streamTableHeaderContextMenu release], _streamTableHeaderContextMenu = nil;
	[_streamTableSavedSortDescriptors release], _streamTableSavedSortDescriptors = nil;

	[_nowPlaying release], _nowPlaying = nil;

	[_currentStreams release], _currentStreams = nil;
	
	[_libraryNode release], _libraryNode = nil;
	[_currentStreamsNode release], _currentStreamsNode = nil;
	
	[super dealloc];
}

- (id) 			copyWithZone:(NSZone *)zone			{ return self; }
- (id) 			retain								{ return self; }
- (unsigned) 	retainCount							{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void) 		release								{ /* do nothing */ }
- (id) 			autorelease							{ return self; }

- (void) awakeFromNib
{	
	// Setup browser
	[self setupBrowser];
	
	// Set sort descriptors
	[_streamController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:MetadataAlbumTitleKey ascending:YES] autorelease],
		[[[NSSortDescriptor alloc] initWithKey:PropertiesFormatTypeKey ascending:YES] autorelease],
		[[[NSSortDescriptor alloc] initWithKey:MetadataDiscNumberKey ascending:YES] autorelease],
		[[[NSSortDescriptor alloc] initWithKey:MetadataTrackNumberKey ascending:YES] autorelease],
		[[[NSSortDescriptor alloc] initWithKey:MetadataArtistKey ascending:YES] autorelease],
		nil]];

/*	[_browserController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES] autorelease],
		nil]];*/
	
	// Default window state
	[self updatePlayButtonState];
	[_albumArtImageView setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
	
	[self setupStreamButtons];
	[self setupStreamTableColumns];

	[self setupPlaylistButtons];
}

- (void) windowDidLoad
{
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Library"];
	[[self window] setExcludedFromWindowsMenu:YES];
}

- (void) windowWillClose:(NSNotification *)aNotification
{
	[self stop:self];	
}

- (BOOL) validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
	if([anItem action] == @selector(playPause:)) {
		return [self playButtonEnabled];
	}
	else if([anItem action] == @selector(addFiles:)) {
		return [_streamController canAdd];
	}
	else if([anItem action] == @selector(showStreamInformationSheet:)) {
		return (0 != [[_streamController selectedObjects] count]);
	}
/*	else if([anItem action] == @selector(showPlaylistInformationSheet:)) {
		return (0 != [[_playlistController selectedObjects] count]);
	}*/
	else if([anItem action] == @selector(skipForward:) 
			|| [anItem action] == @selector(skipBackward:) 
			|| [anItem action] == @selector(skipToEnd:) 
			|| [anItem action] == @selector(skipToBeginning:)) {
		return [[self player] hasValidStream];
	}
	else if([anItem action] == @selector(playNextStream:)) {
		return [self canPlayNextStream];
	}
	else if([anItem action] == @selector(playPreviousStream:)) {
		return [self canPlayPreviousStream];
	}
/*	else if([anItem action] == @selector(nextPlaylist:)) {
		return [_playlistController canSelectNext];
	}
	else if([anItem action] == @selector(previousPlaylist:)) {
		return [_playlistController canSelectPrevious];
	}*/
	else if([anItem action] == @selector(insertPlaylist:)
/*			|| [anItem action] == @selector(insertDynamicPlaylist:)
			|| [anItem action] == @selector(insertFolderPlaylist:)*/) {
		return [_browserController canInsertPlaylist];
	}
	else if([anItem action] == @selector(insertPlaylistWithSelection:)) {
		return ([_browserController canInsertPlaylist] && 0 != [[_streamController selectedObjects] count]);
	}
	else if([anItem action] == @selector(jumpToNowPlaying:)) {
		return (nil != [self nowPlaying] && 0 != [self countOfCurrentStreams]);
	}
	else if([anItem action] == @selector(showCurrentStreams:)) {
		return (0 != [self countOfCurrentStreams]);
	}
	else if([anItem action] == @selector(undo:)) {
		return [[self undoManager] canUndo];
	}
	else if([anItem action] == @selector(redo:)) {
		return [[self undoManager] canRedo];
	}

	return YES;
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	int changeKind = [[change valueForKey:NSKeyValueChangeKindKey] intValue];

	if(NSKeyValueChangeRemoval == changeKind) {
		NSEnumerator	*removedStreams		= [[change valueForKey:NSKeyValueChangeOldKey] objectEnumerator];
		AudioStream		*stream				= nil;
		
		while((stream = [removedStreams nextObject])) {
			if([_currentStreams containsObject:stream]) {
				[self willChangeValueForKey:@"currentStreams"];
				[_currentStreams removeObject:stream];
				[self didChangeValueForKey:@"currentStreams"];
			}
		}
	}
	
	if(NSKeyValueChangeInsertion == changeKind || NSKeyValueChangeRemoval == changeKind) {
		[self updatePlayButtonState];
	}
}

#pragma mark Action Methods

- (IBAction) toggleBrowser:(id)sender
{
	[_browserDrawer toggle:sender];
}

- (IBAction) removeSelectedStreams:(id)sender
{
	[[CollectionManager manager] beginUpdate];
	[_streamController remove:sender];
	[[CollectionManager manager] finishUpdate];
}

- (IBAction) openDocument:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:YES];
	[panel setCanChooseDirectories:YES];
	
	[panel beginSheetForDirectory:nil 
							 file:nil 
							types:nil 
				   modalForWindow:[self window] 
					modalDelegate:self 
				   didEndSelector:@selector(openDocumentSheetDidEnd:returnCode:contextInfo:)
					  contextInfo:nil];
}

- (IBAction) jumpToNowPlaying:(id)sender
{
	if(nil != [self nowPlaying] && 0 != [self countOfCurrentStreams] && [self selectCurrentStreamsNode]) {
		[self scrollNowPlayingToVisible];
	}
}

- (IBAction) showCurrentStreams:(id)sender
{
	if(0 == [self countOfCurrentStreams]) {
		return;
	}

	/*BOOL success =*/ [self selectCurrentStreamsNode];
}

- (IBAction) showStreamInformationSheet:(id)sender
{
	NSArray *streams = [_streamController selectedObjects];
		
	if(0 == [streams count]) {
		return;
	}
	else if(1 == [streams count]) {
		AudioStreamInformationSheet *streamInformationSheet = [[AudioStreamInformationSheet alloc] init];
		
		[streamInformationSheet setValue:[streams objectAtIndex:0] forKey:@"stream"];
		[streamInformationSheet setValue:[[[CollectionManager manager] streamManager] streams] forKey:@"allStreams"];
		
		[[CollectionManager manager] beginUpdate];
		
		[[NSApplication sharedApplication] beginSheet:[streamInformationSheet sheet] 
									   modalForWindow:[self window] 
										modalDelegate:self 
									   didEndSelector:@selector(showStreamInformationSheetDidEnd:returnCode:contextInfo:) 
										  contextInfo:streamInformationSheet];
	}
	else {
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
}

- (IBAction) showPlaylistInformationSheet:(id)sender
{
/*	NSArray *playlists = [_playlistController selectedObjects];
	
	if(0 == [playlists count]) {
		return;
	}

	id playlist = [playlists objectAtIndex:0];
	
	if([playlist isKindOfClass:[Playlist class]]) {
		[self showStaticPlaylistInformationSheet];
	}*/
}

- (void) showStaticPlaylistInformationSheet
{
/*	StaticPlaylistInformationSheet *playlistInformationSheet = [[StaticPlaylistInformationSheet alloc] init];
	
	[playlistInformationSheet setValue:[[_playlistController selectedObjects] objectAtIndex:0] forKey:@"playlist"];
	[playlistInformationSheet setValue:self forKey:@"owner"];
	
	//		[self beginUpdate];
	
	[[NSApplication sharedApplication] beginSheet:[playlistInformationSheet sheet] 
								   modalForWindow:[self window] 
									modalDelegate:self 
								   didEndSelector:@selector(showStaticPlaylistInformationSheetDidEnd:returnCode:contextInfo:) 
									  contextInfo:playlistInformationSheet];*/
}

#pragma mark File Addition

- (BOOL) addFile:(NSString *)filename
{
	NSError *error = nil;
	
	// If the stream already exists in the library, do nothing
	AudioStream *stream = [[[CollectionManager manager] streamManager] streamForURL:[NSURL fileURLWithPath:filename]];
	if(nil != stream) {
		return YES;
	}

	// First read the properties
	AudioPropertiesReader *propertiesReader = [AudioPropertiesReader propertiesReaderForURL:[NSURL fileURLWithPath:filename] error:&error];
	if(nil == propertiesReader) {
		return NO;
	}
	
	BOOL result = [propertiesReader readProperties:&error];
	if(NO == result) {
		return NO;
	}
	
	// Now read the metadata
	AudioMetadataReader *metadataReader	= [AudioMetadataReader metadataReaderForURL:[NSURL fileURLWithPath:filename] error:&error];
	if(nil == metadataReader) {		
		return NO;
	}
	
	result = [metadataReader readMetadata:&error];
	if(NO == result) {
		return NO;
	}

	NSMutableDictionary *values = [NSMutableDictionary dictionaryWithDictionary:[propertiesReader valueForKey:@"properties"]];
	[values addEntriesFromDictionary:[metadataReader valueForKey:@"metadata"]];
	
	// Insert the object in the database
	stream = [AudioStream insertStreamForURL:[NSURL fileURLWithPath:filename] withInitialValues:values];
	
	if(nil != stream) {
		[_streamController addObject:stream];
		// TODO: Add stream to playlist
	}
		
	return (nil != stream);
}

- (BOOL) addFiles:(NSArray *)filenames
{
	NSString				*filename				= nil;
	NSString				*path					= nil;
	NSFileManager			*fileManager			= [NSFileManager defaultManager];
	NSEnumerator			*filesEnumerator		= [filenames objectEnumerator];
	NSDirectoryEnumerator	*directoryEnumerator	= nil;
	BOOL					isDirectory				= NO;
	BOOL					openSuccessful			= NO;
	
	[[CollectionManager manager] beginUpdate];
	
	while((filename = [filesEnumerator nextObject])) {
		
		// Perform a deep search for directories
		if([fileManager fileExistsAtPath:filename isDirectory:&isDirectory] && isDirectory) {
			directoryEnumerator	= [fileManager enumeratorAtPath:filename];
			
			while((path = [directoryEnumerator nextObject])) {
				openSuccessful &= [self addFile:[filename stringByAppendingPathComponent:path]];
			}
		}
		else {
			openSuccessful = [self addFile:filename];
		}
	}

	[[CollectionManager manager] finishUpdate];
	
	return openSuccessful;
}

#pragma mark Playlist manipulation

- (IBAction) insertPlaylist:(id)sender;
{
	NSDictionary *initialValues = [NSDictionary dictionaryWithObject:NSLocalizedStringFromTable(@"Untitled Playlist", @"General", @"") forKey:PlaylistNameKey];
	Playlist *playlist = [Playlist insertPlaylistWithInitialValues:initialValues];
	if(nil != playlist) {
		[_browserDrawer open:self];
		
		NSIndexPath *path = [_browserController selectionIndexPath];
		NSLog(@"path=%@",path);
		
//		if(nil != path && [_browserController setSelectionIndexPath:path]) {
//			[_browserOutlineView editColumn:0 row:[_playlistTable selectedRow] withEvent:nil select:YES];	
//		}
	}
	else {
/*		NSAlert *alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:NSLocalizedStringFromTable(@"Unable to create the playlist.", @"Errors", @"")];
		[alert setInformativeText:@"Playlists must have a unique name."];
		[alert setAlertStyle:NSInformationalAlertStyle];
		
		if(NSAlertFirstButtonReturn == [alert runModal]) {
		} 
		
		[alert release];*/
		NSBeep();
		NSLog(@"Unable to create the playlist.");
	}
}

- (IBAction) insertPlaylistWithSelection:(id)sender;
{
	// For some reason the call to insertPlaylistWithInitialValues: causes the _streamController selectedObjects to become nil
	// ?? !!
	NSDictionary	*initialValues		= [NSDictionary dictionaryWithObject:NSLocalizedStringFromTable(@"Untitled Playlist", @"General", @"") forKey:PlaylistNameKey];
	NSArray			*streamsToInsert	= [_streamController selectedObjects];
	Playlist		*playlist			= [Playlist insertPlaylistWithInitialValues:initialValues];

	NSLog(@"streams = %@",streamsToInsert);
	
	if(nil != playlist) {
		[playlist addStreams:streamsToInsert];

/*		[_browserDrawer open:self];

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
		NSLog(@"Unable to insert playlist.");
	}
}

- (IBAction) nextPlaylist:(id)sender
{
//	[_playlistController selectNext:self];
}

- (IBAction) previousPlaylist:(id)sender
{
//	[_playlistController selectPrevious:self];
}

#pragma mark Playback Control

- (BOOL) playFile:(NSString *)filename
{
	// First try to find this file in our library
	BOOL			success			= YES;
	AudioStream		*stream			= [[[CollectionManager manager] streamManager] streamForURL:[NSURL fileURLWithPath:filename]];

	// If it wasn't found, try and add it
	if(nil == stream) {
		success = [self addFile:filename];
		if(success) {
			stream = [[[CollectionManager manager] streamManager] streamForURL:[NSURL fileURLWithPath:filename]];
		}
	}
		
	// Play the file, if everything worked
	if(nil != stream) {
		[self setCurrentStreamsFromArray:[NSArray arrayWithObject:stream]];
		[self playStreamAtIndex:0];
	}
	
	return success;
}

- (IBAction) play:(id)sender
{
	if(NO == [[self player] hasValidStream]) {
		if([self randomizePlayback]) {
			NSArray		*streams			= (1 < [[_streamController selectedObjects] count] ? [_streamController selectedObjects] : [_streamController arrangedObjects]);
			double		randomNumber		= genrand_real2();
			unsigned	randomIndex			= (unsigned)(randomNumber * [streams count]);
			
			[self setCurrentStreamsFromArray:streams];
			[self playStreamAtIndex:randomIndex];
		}
		else {
			[self playSelection:sender];
		}
	}
	else {
		[[self player] play];
		[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidResumeNotification 
															object:self 
														  userInfo:[NSDictionary dictionaryWithObject:[self nowPlaying] forKey:AudioStreamObjectKey]];
	}
	
	[self updatePlayButtonState];
}

- (IBAction) playPause:(id)sender
{
	if(NO == [[self player] hasValidStream]) {
		[self play:sender];
	}
	else {
		[[self player] playPause];
		
		if([[self player] isPlaying]) {
			[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidResumeNotification 
																object:self
															  userInfo:[NSDictionary dictionaryWithObject:[self nowPlaying] forKey:AudioStreamObjectKey]];
		}
		else {
			[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidPauseNotification
																object:self
															  userInfo:[NSDictionary dictionaryWithObject:[self nowPlaying] forKey:AudioStreamObjectKey]];
		}
	}
	
	[self updatePlayButtonState];
}

- (IBAction) playSelection:(id)sender
{
	if(0 == [[_streamController arrangedObjects] count]) {
		return;
	}
	
	// Don't set the current streams if they are already in there
	int				selectedRow			= [_browserOutlineView selectedRow];
	id				opaqueNode			= [_browserOutlineView itemAtRow:selectedRow];
	BrowserNode		*node				= [opaqueNode observedObject];

	if(NO == [node isKindOfClass:[CurrentStreamsNode class]]) {
		unsigned selectedObjectsCount = [[_streamController selectedObjects] count];
		NSArray *streams = (1 < selectedObjectsCount ? [_streamController selectedObjects] : [_streamController arrangedObjects]);
		NSIndexSet *savedSelectionIndexes = [_streamController selectionIndexes];
		[self setCurrentStreamsFromArray:streams];
		[self playStreamAtIndex:(1 != selectedObjectsCount ? 0 : [_streamController selectionIndex])];
		if(1 < selectedObjectsCount) {			
			[_streamController setSelectionIndexes:savedSelectionIndexes];
		}
	}
	else {		
		[self playStreamAtIndex:[_streamController selectionIndex]];
	}
	
	[self updatePlayButtonState];
}

- (IBAction) stop:(id)sender
{
	AudioStream *stream = [self nowPlaying];

	[self setPlaybackIndex:NSNotFound];
	[self setNowPlaying:nil];

	if([[self player] hasValidStream]) {
		
		if([[self player] isPlaying]) {
			[[self player] stop];
		}
		
		[[self player] reset];

		[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidStopNotification 
															object:self
														  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
	}
	
	[self updatePlayButtonState];
}

- (IBAction) skipForward:(id)sender
{
	[[self player] skipForward];
}

- (IBAction) skipBackward:(id)sender
{
	[[self player] skipBackward];
}

- (IBAction) skipToEnd:(id)sender
{
	[[self player] skipToEnd];
}

- (IBAction) skipToBeginning:(id)sender
{
	[[self player] skipToBeginning];
}

- (IBAction) playNextStream:(id)sender
{
	AudioStream		*stream			= [self nowPlaying];
	unsigned		streamIndex;
	
	[self setNowPlaying:nil];
	[stream setPlaying:NO];
	
	NSArray *streams = _currentStreams;
	
	if(nil == stream || 0 == [streams count]) {
		[[self player] reset];
		[self updatePlayButtonState];
	}
	else if([self randomizePlayback]) {
		double			randomNumber;
		unsigned		randomIndex;
		
		randomNumber	= genrand_real2();
		randomIndex		= (unsigned)(randomNumber * [streams count]);
		
		[self playStreamAtIndex:randomIndex];
	}
	else if([self loopPlayback]) {
		streamIndex = [self playbackIndex];
		[self playStreamAtIndex:(streamIndex + 1 < [streams count] ? streamIndex + 1 : 0)];
	}
	else {
		streamIndex = [self playbackIndex];
		
		if(streamIndex + 1 < [streams count]) {
			[self playStreamAtIndex:streamIndex + 1];
		}
		else {
			[[self player] reset];
			[self setCurrentStreamsFromArray:nil];
			[self updatePlayButtonState];
		}
	}
}

- (IBAction) playPreviousStream:(id)sender
{
	AudioStream		*stream			= [self nowPlaying];
	unsigned		streamIndex;
	
	[self setNowPlaying:nil];
	[stream setPlaying:NO];
	
	NSArray *streams = _currentStreams;
	
	if(nil == stream || 0 == [streams count]) {
		[[self player] reset];	
	}
	else if([self randomizePlayback]) {
		double			randomNumber;
		unsigned		randomIndex;
		
		randomNumber	= genrand_real2();
		randomIndex		= (unsigned)(randomNumber * [streams count]);
		
		[self playStreamAtIndex:randomIndex];
	}
	else if([self loopPlayback]) {
		streamIndex = [self playbackIndex];		
		[self playStreamAtIndex:(1 <= streamIndex ? streamIndex - 1 : [streams count] - 1)];
	}
	else {
		streamIndex = [self playbackIndex];		
		
		if(1 <= streamIndex) {
			[self playStreamAtIndex:streamIndex - 1];
		}
		else {
			[[self player] reset];	
		}
	}
}

#pragma mark Currently Playing Streams

- (unsigned) countOfCurrentStreams
{
	return [_currentStreams count];
}

- (AudioStream *) objectInCurrentStreamsAtIndex:(unsigned)index
{
	return [_currentStreams objectAtIndex:index];
}

- (void) getCurrentStreams:(id *)buffer range:(NSRange)aRange
{
	return [_currentStreams getObjects:buffer range:aRange];
}

- (void) insertObject:(AudioStream *)stream inCurrentStreamsAtIndex:(unsigned)index
{
	if(index <= [self playbackIndex]) {
		[self setPlaybackIndex:[self playbackIndex] + 1];
	}

	[_currentStreams insertObject:stream atIndex:index];	
}

- (void) removeObjectFromCurrentStreamsAtIndex:(unsigned)index
{
	// Disallow removal of the currently playing stream
	if(index == [self playbackIndex]) {
		[self stop:self];
	}
	else if(index < [self playbackIndex]) {
		[self setPlaybackIndex:[self playbackIndex] - 1];
	}
	
	[_currentStreams removeObjectAtIndex:index];	
}

#pragma mark Browser support

- (BOOL) selectLibraryNode
{
	return [_browserController setSelectionIndexPath:[_browserController arrangedIndexPathForObject:_libraryNode]];
}

- (BOOL) selectCurrentStreamsNode
{
	return [_browserController setSelectionIndexPath:[_browserController arrangedIndexPathForObject:_currentStreamsNode]];
}

#pragma mark Properties

- (BOOL)		randomizePlayback									{ return _randomizePlayback; }
- (void)		setRandomizePlayback:(BOOL)randomizePlayback		{ _randomizePlayback = randomizePlayback; }

- (BOOL)		loopPlayback										{ return _loopPlayback; }
- (void)		setLoopPlayback:(BOOL)loopPlayback					{ _loopPlayback = loopPlayback; }

- (BOOL)		playButtonEnabled									{ return _playButtonEnabled; }
- (void)		setPlayButtonEnabled:(BOOL)playButtonEnabled		{ _playButtonEnabled = playButtonEnabled; }

- (BOOL) canPlayNextStream
{
	NSArray		*streams	= _currentStreams;
	BOOL		result		= NO;
	
	if(NSNotFound == [self playbackIndex] || 0 == [streams count]) {
		result = NO;
	}
	else if([self randomizePlayback]) {
		result = YES;
	}
	else if([self loopPlayback]) {
		result = YES;
	}
	else {
		result = ([self playbackIndex] + 1 < [streams count]);
	}
	
	return result;
}

- (BOOL) canPlayPreviousStream
{
	NSArray		*streams	= _currentStreams;
	BOOL		result		= NO;
	
	if(NSNotFound == [self playbackIndex] || 0 == [streams count]) {
		result = NO;
	}
	else if([self randomizePlayback]) {
		result = YES;
	}
	else if([self loopPlayback]) {
		result = YES;
	}
	else {
		result = (1 <= [self playbackIndex]);
	}
	
	return result;
}

- (AudioStream *) nowPlaying
{
	return _nowPlaying;
}

- (void) setNowPlaying:(AudioStream *)nowPlaying
{
	[_streamTable setNeedsDisplayInRect:[_streamTable rectOfRow:[[_streamController arrangedObjects] indexOfObject:_nowPlaying]]];

	[_nowPlaying release];
	_nowPlaying = [nowPlaying retain];
	
	// Update window title
	NSString *title			= [[self nowPlaying] valueForKey:MetadataTitleKey];
	NSString *artist		= [[self nowPlaying] valueForKey:MetadataArtistKey];
	NSString *windowTitle	= [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	
	if(nil != title && nil != artist) {
		windowTitle = [NSString stringWithFormat:@"%@ - %@", artist, title];
	}
	else if(nil != title) {
		windowTitle = title;
	}
	else if(nil != artist) {
		windowTitle = artist;
	}
			
	[[self window] setTitle:windowTitle];

	[_streamTable setNeedsDisplayInRect:[_streamTable rectOfRow:[[_streamController arrangedObjects] indexOfObject:_nowPlaying]]];
}

- (NSUndoManager *) undoManager
{
	return [[CollectionManager manager] undoManager];
}

- (BOOL) streamsAreOrdered
{
	return _streamsAreOrdered;
}

#pragma mark AudioPlayer Callbacks

- (void) streamPlaybackDidStart
{
	AudioStream		*stream			= [self nowPlaying];
	NSNumber		*playCount;
	NSNumber		*newPlayCount;

	playCount		= [stream valueForKey:StatisticsPlayCountKey];
	newPlayCount	= [NSNumber numberWithUnsignedInt:[playCount unsignedIntValue] + 1];
	
	[stream setPlaying:NO];

	[[CollectionManager manager] beginUpdate];
	
	[stream setValue:[NSDate date] forKey:StatisticsLastPlayedDateKey];
	[stream setValue:newPlayCount forKey:StatisticsPlayCountKey];
	
	if(nil == [stream valueForKey:StatisticsFirstPlayedDateKey]) {
		[stream setValue:[NSDate date] forKey:StatisticsFirstPlayedDateKey];
	}
	
	[[CollectionManager manager] finishUpdate];

	[_streamTable setNeedsDisplayInRect:[_streamTable rectOfRow:[self playbackIndex]]];

	[self setPlaybackIndex:[self nextPlaybackIndex]];
	[self setNextPlaybackIndex:NSNotFound];
	
	[_streamTable setNeedsDisplayInRect:[_streamTable rectOfRow:[self playbackIndex]]];

	stream = [self objectInCurrentStreamsAtIndex:[self playbackIndex]];
	NSAssert(nil != stream, @"Playback started for stream index not in playback context.");
	
	[stream setPlaying:YES];
	[self setNowPlaying:stream];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidStartNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
}

- (void) streamPlaybackDidComplete
{
	AudioStream		*stream			= [self nowPlaying];
	NSNumber		*playCount;
	NSNumber		*newPlayCount;
	
	playCount		= [stream valueForKey:StatisticsPlayCountKey];
	newPlayCount	= [NSNumber numberWithUnsignedInt:[playCount unsignedIntValue] + 1];
	
	[stream setPlaying:NO];

	[[CollectionManager manager] beginUpdate];
	
	[stream setValue:[NSDate date] forKey:StatisticsLastPlayedDateKey];
	[stream setValue:newPlayCount forKey:StatisticsPlayCountKey];
	
	if(nil == [stream valueForKey:StatisticsFirstPlayedDateKey]) {
		[stream setValue:[NSDate date] forKey:StatisticsFirstPlayedDateKey];
	}
	
	[[CollectionManager manager] finishUpdate];

	[_streamTable setNeedsDisplayInRect:[_streamTable rectOfRow:[self playbackIndex]]];
	[self setPlaybackIndex:NSNotFound];
	
	// If the player isn't playing, it's the end of the road for now
	if(NO == [[self player] isPlaying]) {
		[self setNowPlaying:nil];
		[[self player] reset];
		[self updatePlayButtonState];
	}
}

- (void) requestNextStream
{
	AudioStream		*stream			= [self nowPlaying];
	unsigned		streamIndex;
	
	NSArray *streams = _currentStreams;
	
	if(nil == stream || 0 == [streams count]) {
		[self setNextPlaybackIndex:NSNotFound];
	}
	else if([self randomizePlayback]) {
		double randomNumber = genrand_real2();
		[self setNextPlaybackIndex:(unsigned)(randomNumber * [streams count])];
	}
	else if([self loopPlayback]) {
		streamIndex = [self playbackIndex];		
		[self setNextPlaybackIndex:(streamIndex + 1 < [streams count] ? streamIndex + 1 : 0)];
	}
	else {
		streamIndex = [self playbackIndex];
		[self setNextPlaybackIndex:(streamIndex + 1 < [streams count] ? streamIndex + 1 : NSNotFound)];
	}

#if DEBUG
	NSLog(@"requestNextStream:%@",[self objectInCurrentStreamsAtIndex:[self nextPlaybackIndex]]);
#endif
	
	if(NSNotFound != [self nextPlaybackIndex]) {
		NSError		*error		= nil;
		BOOL		result		= [[self player] setNextStream:[self objectInCurrentStreamsAtIndex:[self nextPlaybackIndex]] error:&error];

		if(NO == result) {
			if(nil != error) {
				[self presentError:error];
			}
		}
	}
}

@end

@implementation AudioLibrary (NSTableViewDelegateMethods)

- (NSString *) tableView:(NSTableView *)tableView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(int)row mouseLocation:(NSPoint)mouseLocation
{
    if([cell isKindOfClass:[NSTextFieldCell class]]) {
        if([[cell attributedStringValue] size].width > rect->size.width) {
            return [cell stringValue];
        }
    }
	
    return nil;
}

/*- (float) tableView:(NSTableView *)tableView heightOfRow:(int)row
{
	NSDictionary	*infoForBinding		= [tableView infoForBinding:NSContentBinding];
	BOOL			highlight			= NO;
	
	if(nil != infoForBinding) {
		NSArrayController	*arrayController	= [infoForBinding objectForKey:NSObservedObjectKey];
		AudioStream			*stream				= [[arrayController arrangedObjects] objectAtIndex:row];
		
		highlight = ([stream isPlaying] && row == (int)[self playbackIndex]);
	}
	
	return (highlight ? 18.0 : 16.0);
}*/

- (void) tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	NSDictionary *infoForBinding = [tableView infoForBinding:NSContentBinding];

	if(nil != infoForBinding) {
		NSArrayController	*arrayController	= [infoForBinding objectForKey:NSObservedObjectKey];
		AudioStream			*stream				= [[arrayController arrangedObjects] objectAtIndex:rowIndex];
		BOOL				highlight			= ([stream isPlaying] && rowIndex == (int)[self playbackIndex]);
		
		// Highlight the currently playing stream (doesn't work for NSButtonCell)
		if([cell respondsToSelector:@selector(setDrawsBackground:)]) {
			if(highlight) {
				[cell setDrawsBackground:YES];	
				// Emacs "NavajoWhite" -> 255, 222, 173
	//			[cell setBackgroundColor:[NSColor colorWithCalibratedRed:(255/255.f) green:(222/255.f) blue:(173/255.f) alpha:1.0]];
				// Emacs "LightSteelBlue" -> 176, 196, 222
				[cell setBackgroundColor:[NSColor colorWithCalibratedRed:(176/255.f) green:(196/255.f) blue:(222/255.f) alpha:1.0]];
			}
			else {
				[cell setDrawsBackground:NO];
			}
		}

		// Bold/unbold cell font as required
		NSFont *font = [cell font];
		if(highlight) {
			font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSBoldFontMask];
		}
		else {
			font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSUnboldFontMask];			
		}
		[cell setFont:font];
	}
}

- (void) tableViewColumnDidMove:(NSNotification *)aNotification
{
	[self saveStreamTableColumnOrder];
}

- (void) tableViewColumnDidResize:(NSNotification *)aNotification
{
	NSMutableDictionary		*sizes			= [NSMutableDictionary dictionary];
	NSEnumerator			*enumerator		= [[_streamTable tableColumns] objectEnumerator];
	id						column;
	
	while((column = [enumerator nextObject])) {
		[sizes setObject:[NSNumber numberWithFloat:[column width]] forKey:[column identifier]];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:sizes forKey:@"streamTableColumnSizes"];
}

@end

@implementation AudioLibrary (NSOutlineViewDelegateMethods)

- (BOOL) outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	BrowserNode *node = [item observedObject];
	return [node nameIsEditable];
}

- (NSString *) outlineView:(NSOutlineView *)ov toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tc item:(id)item mouseLocation:(NSPoint)mouseLocation
{
    if([cell isKindOfClass:[NSTextFieldCell class]]) {
        if([[cell attributedStringValue] size].width > rect->size.width) {
            return [cell stringValue];
        }
    }
	
    return nil;
}

- (void) outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	BrowserNode *node = [item observedObject];
	[(ImageAndTextCell *)cell setImage:[node icon]];
}

- (void) outlineViewSelectionDidChange:(NSNotification *)notification
{
	NSOutlineView				*outlineView		= [notification object];
	int							selectedRow			= [outlineView selectedRow];
	id							opaqueNode			= [outlineView itemAtRow:selectedRow];
	BrowserNode					*node				= [opaqueNode observedObject];
	NSArray						*selected			= [_streamController selectedObjects];
	NSDictionary				*bindingInfo		= [_streamController infoForBinding:@"contentArray"];
	AudioStreamCollectionNode	*oldStreamsNode		= [bindingInfo valueForKey:NSObservedObjectKey];

	// Unbind the current stream source
	[_streamController unbind:@"contentArray"];
	[_streamController setContent:nil];
	
	// Don't do anything except possibly save the sort descriptors if the user selected nothing
	if(nil == node) {
		if(NO == [oldStreamsNode streamsAreOrdered]) {
			[_streamTableSavedSortDescriptors release], _streamTableSavedSortDescriptors = nil;
			_streamTableSavedSortDescriptors = [[_streamController sortDescriptors] retain];
			[_streamController setSortDescriptors:nil];
		}
		return;
	}
	
	// Bind to a new stream source if one was selected
	if([[node exposedBindings] containsObject:@"streams"]) {
		AudioStreamCollectionNode *newStreamsNode = (AudioStreamCollectionNode *)node;
		
		// Don't re-bind to the same data source
		if(NO == [oldStreamsNode isEqual:newStreamsNode]) {

			// For unordered streeams (such as the library, album, and artist nodes) use whatever sort descriptors
			// the user has configured.  For ordered streams (such as playlists) default to no sort descriptors
			// so the streams show up in the order the user might expect
			// When switching between ordered and unordered sources, save the source descriptors to restore later
			if(nil == oldStreamsNode) {
				if(NO == [newStreamsNode streamsAreOrdered]) {
					[_streamController setSortDescriptors:_streamTableSavedSortDescriptors];
				}
			}
			else if([oldStreamsNode streamsAreOrdered]) {
				if(NO == [newStreamsNode streamsAreOrdered]) {
					[_streamController setSortDescriptors:_streamTableSavedSortDescriptors];
				}
			}
			else if(NO == [oldStreamsNode streamsAreOrdered]) {
				[_streamTableSavedSortDescriptors release], _streamTableSavedSortDescriptors = nil;
				_streamTableSavedSortDescriptors = [[_streamController sortDescriptors] retain];
				[_streamController setSortDescriptors:nil];
			}
			
			[_streamController bind:@"contentArray" toObject:newStreamsNode withKeyPath:@"streams" options:nil];
			[_streamController setSelectedObjects:selected];

			// Save stream ordering for drag validation
			_streamsAreOrdered = [newStreamsNode streamsAreOrdered];
		}
	}
}

@end

@implementation AudioLibrary (CallbackMethods)

- (void) openDocumentSheetDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void *)contextInfo
{
	if(NSOKButton == returnCode) {
#if SQL_DEBUG
		unsigned startCount = [[_streamController arrangedObjects] count];
		clock_t start = clock();
#endif
		
		[self addFiles:[panel filenames]];

#if SQL_DEBUG
		clock_t end = clock();
		unsigned endCount = [[_streamController arrangedObjects] count];
		unsigned filesAdded = endCount - startCount;
		double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
		NSLog(@"Added %i files in %f seconds (%i files per second)", filesAdded, elapsed, (double)filesAdded / elapsed);
#endif
		
		[_streamController rearrangeObjects];
	}
}

- (void) showStreamInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	AudioStreamInformationSheet *streamInformationSheet = (AudioStreamInformationSheet *)contextInfo;
	
	[sheet orderOut:self];
	
	if(NSOKButton == returnCode) {
		[[CollectionManager manager] finishUpdate];
		[_streamController rearrangeObjects];
	}
	else if(NSCancelButton == returnCode) {
		[[CollectionManager manager] cancelUpdate];
	}
	
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

- (void) showStaticPlaylistInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	StaticPlaylistInformationSheet *playlistInformationSheet = (StaticPlaylistInformationSheet *)contextInfo;
	
	[sheet orderOut:self];
	
	if(NSOKButton == returnCode) {
		//		[self finishUpdate];
		[_streamController rearrangeObjects];
	}
	else if(NSCancelButton == returnCode) {
		//		[self cancelUpdate];
		// TODO: refresh affected objects
	}
	
	[playlistInformationSheet release];
}

@end

@implementation AudioLibrary (NSWindowDelegateMethods)

- (void) windowWillClose:(NSNotification *)aNotification
{
	[self stop:self];
	[[self player] reset];
}

- (NSUndoManager *) windowWillReturnUndoManager:(NSWindow *)sender
{
	return [self undoManager];
}

@end

@implementation AudioLibrary (Private)

- (AudioPlayer *) player
{
	if(nil == _player) {
		_player = [[AudioPlayer alloc] init];
		[_player setOwner:self];
	}
	return _player;
}

- (void) scrollNowPlayingToVisible
{
	[_streamTable scrollRowToVisible:[self playbackIndex]];
}

- (unsigned) playbackIndex
{
	return _playbackIndex;
}

- (void) setPlaybackIndex:(unsigned)playbackIndex
{
	_playbackIndex = playbackIndex;
}

- (unsigned) nextPlaybackIndex
{
	return _nextPlaybackIndex;
}

- (void) setNextPlaybackIndex:(unsigned)nextPlaybackIndex
{
	_nextPlaybackIndex = nextPlaybackIndex;
}

- (void) playStreamAtIndex:(unsigned)index
{
	NSParameterAssert([self countOfCurrentStreams] > index);

	AudioStream *currentStream = [self nowPlaying];
	
	[[self player] stop];
	
	if(nil != currentStream) {
		[currentStream setPlaying:NO];
		[self setNowPlaying:nil];
	}
	
	[_streamTable setNeedsDisplayInRect:[_streamTable rectOfRow:[self playbackIndex]]];
	
	[self setPlaybackIndex:index];
	[self setNextPlaybackIndex:NSNotFound];
	
	[_streamTable setNeedsDisplayInRect:[_streamTable rectOfRow:[self playbackIndex]]];
	
	AudioStream		*stream		= [self objectInCurrentStreamsAtIndex:[self playbackIndex]];
	NSError			*error		= nil;
	BOOL			result		= [[self player] setStream:stream error:&error];
	
	if(NO == result) {
		/*BOOL errorRecoveryDone =*/ [self presentError:error];
		return;
	}
	
	[stream setPlaying:YES];
	[self setNowPlaying:stream];

	if(nil == [stream valueForKey:@"albumArt"]) {
		[_albumArtImageView setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
	}
	
	[[self player] play];
	
	[self selectCurrentStreamsNode];
	// TODO: Is this the desired behavior?
	[self scrollNowPlayingToVisible];

	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidStartNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
	
	[self updatePlayButtonState];
}

- (void) setCurrentStreamsFromArray:(NSArray *)streams
{
	[self willChangeValueForKey:@"currentStreams"];	
	[_currentStreams removeAllObjects];
	[_currentStreams addObjectsFromArray:streams];
	[self didChangeValueForKey:@"currentStreams"];
}

- (void) updatePlayButtonState
{
	NSString						*buttonImagePath, *buttonAlternateImagePath;
	NSImage							*buttonImage, *buttonAlternateImage;
	
	if([[self player] isPlaying]) {		
		buttonImagePath				= [[NSBundle mainBundle] pathForResource:@"player_pause" ofType:@"png"];
		buttonAlternateImagePath	= [[NSBundle mainBundle] pathForResource:@"player_play" ofType:@"png"];
		buttonImage					= [[NSImage alloc] initWithContentsOfFile:buttonImagePath];
		buttonAlternateImage		= [[NSImage alloc] initWithContentsOfFile:buttonAlternateImagePath];
		
		[_playPauseButton setState:NSOnState];
		[_playPauseButton setImage:buttonImage];
		[_playPauseButton setAlternateImage:buttonAlternateImage];
		[_playPauseButton setToolTip:NSLocalizedStringFromTable(@"Pause playback", @"Player", @"")];
		
		[self setPlayButtonEnabled:YES];
	}
	else if(NO == [[self player] hasValidStream]) {
		buttonImagePath				= [[NSBundle mainBundle] pathForResource:@"player_play" ofType:@"png"];
		buttonImage					= [[NSImage alloc] initWithContentsOfFile:buttonImagePath];
		
		[_playPauseButton setState:NSOffState];
		[_playPauseButton setImage:buttonImage];
		[_playPauseButton setAlternateImage:nil];		
		[_playPauseButton setToolTip:NSLocalizedStringFromTable(@"Play", @"Player", @"")];
		
		[self setPlayButtonEnabled:(0 != [self countOfCurrentStreams])];
	}
	else {
		buttonImagePath				= [[NSBundle mainBundle] pathForResource:@"player_play" ofType:@"png"];
		buttonAlternateImagePath	= [[NSBundle mainBundle] pathForResource:@"player_pause" ofType:@"png"];		
		buttonImage					= [[NSImage alloc] initWithContentsOfFile:buttonImagePath];
		buttonAlternateImage		= [[NSImage alloc] initWithContentsOfFile:buttonAlternateImagePath];
		
		[_playPauseButton setState:NSOffState];
		[_playPauseButton setImage:buttonImage];
		[_playPauseButton setAlternateImage:buttonAlternateImage];
		[_playPauseButton setToolTip:NSLocalizedStringFromTable(@"Resume playback", @"Player", @"")];
		
		[self setPlayButtonEnabled:YES];
	}
}

- (void) setupBrowser
{	
	// Grab the icons we'll be using
	IconFamily	*folderIconFamily	= [IconFamily iconFamilyWithSystemIcon:kGenericFolderIcon];
	NSImage		*folderIcon			= [folderIconFamily imageWithAllReps];
	
	[folderIcon setSize:NSMakeSize(16.0, 16.0)];
	
	IconFamily	*cdIconFamily		= [IconFamily iconFamilyWithSystemIcon:kGenericCDROMIcon];
	NSImage		*cdIcon				= [cdIconFamily imageWithAllReps];

	[cdIcon setSize:NSMakeSize(16.0, 16.0)];

	BrowserNode *browserRoot = [[BrowserNode alloc] initWithName:NSLocalizedStringFromTable(@"Collection", @"General", @"")];
	[browserRoot setIcon:folderIcon];
	
	_currentStreamsNode = [[CurrentStreamsNode alloc] init];
	//	[_currentStreamsNode setIcon:cdIcon];
	
	_libraryNode = [[LibraryNode alloc] init];
	[_libraryNode setIcon:cdIcon];

	ArtistsNode *artistsNode = [[ArtistsNode alloc] init];
	[artistsNode setIcon:folderIcon];

	AlbumsNode *albumsNode = [[AlbumsNode alloc] init];
	[albumsNode setIcon:folderIcon];

	PlaylistsNode *playlistsNode = [[PlaylistsNode alloc] init];
	[playlistsNode setIcon:folderIcon];

	BrowserNode *watchedFoldersNode = [[BrowserNode alloc] initWithName:NSLocalizedStringFromTable(@"Watch Folders", @"General", @"")];
	[watchedFoldersNode setIcon:folderIcon];

	[browserRoot addChild:_currentStreamsNode];
	[browserRoot addChild:_libraryNode];
	[browserRoot addChild:[artistsNode autorelease]];
	[browserRoot addChild:[albumsNode autorelease]];
	[browserRoot addChild:[playlistsNode autorelease]];
	[browserRoot addChild:[watchedFoldersNode autorelease]];

	[_browserController setContent:[browserRoot autorelease]];

	// Select the LibraryNode
	BOOL success = [self selectLibraryNode];
	NSAssert(YES == success, @"Unable to set browser selection to LibraryNode");
	
	// Setup the custom data cell
	NSTableColumn		*tableColumn		= [_browserOutlineView tableColumnWithIdentifier:@"name"];
	ImageAndTextCell	*imageAndTextCell	= [[ImageAndTextCell alloc] init];
	
	[imageAndTextCell setLineBreakMode:NSLineBreakByTruncatingTail];
	[tableColumn setDataCell:[imageAndTextCell autorelease]];
}

- (void) setupStreamButtons
{
	// Bind stream addition/removal button actions and state
	[_addStreamsButton setToolTip:NSLocalizedStringFromTable(@"Add audio streams to the library", @"Player", @"")];
	[_addStreamsButton bind:@"enabled"
				   toObject:_streamController
				withKeyPath:@"canInsert"
					options:nil];
	[_addStreamsButton bind:@"enabled2"
				   toObject:_streamController
				withKeyPath:@"content"
					options:[NSDictionary dictionaryWithObject:@"NSIsNotNil" forKey:NSValueTransformerNameBindingOption]];
	[_addStreamsButton setAction:@selector(openDocument:)];
	[_addStreamsButton setTarget:self];
	
	[_removeStreamsButton setToolTip:NSLocalizedStringFromTable(@"Remove the selected audio streams", @"Player", @"")];
	[_removeStreamsButton bind:@"enabled"
					  toObject:_streamController
				   withKeyPath:@"canRemove"
					   options:nil];
	[_removeStreamsButton setAction:@selector(removeSelectedStreams:)];
	[_removeStreamsButton setTarget:self];
	
	[_streamInfoButton setToolTip:NSLocalizedStringFromTable(@"Show information on the selected streams", @"Player", @"")];
	[_streamInfoButton bind:@"enabled"
				   toObject:_streamController
				withKeyPath:@"selectedObjects.@count"
					options:nil];
	[_streamInfoButton setAction:@selector(showStreamInformationSheet:)];
	[_streamInfoButton setTarget:self];
}

 - (void) setupPlaylistButtons
{
	NSMenu			*buttonMenu;
	NSMenuItem		*buttonMenuItem;
	
	// Bind playlist addition/removal button actions and state
	[_addPlaylistButton setToolTip:NSLocalizedStringFromTable(@"Add a new playlist to the library", @"Player", @"")];
	[_addPlaylistButton bind:@"enabled"
					toObject:_browserController
				 withKeyPath:@"canInsert"
					 options:nil];
	
	buttonMenu			= [[NSMenu alloc] init];
	
	buttonMenuItem		= [[NSMenuItem alloc] init];
	[buttonMenuItem setTitle:NSLocalizedStringFromTable(@"New Playlist", @"Player", @"")];
	//	[buttonMenuItem setImage:[NSImage imageNamed:@"StaticPlaylist.png"]];
	[buttonMenuItem setTarget:self];
	[buttonMenuItem setAction:@selector(insertPlaylist:)];
	[buttonMenu addItem:buttonMenuItem];
	[buttonMenuItem bind:@"enabled"
				toObject:_browserController
			 withKeyPath:@"canInsertPlaylist"
				 options:nil];
	[buttonMenuItem release];
	
	buttonMenuItem		= [[NSMenuItem alloc] init];
	[buttonMenuItem setTitle:NSLocalizedStringFromTable(@"New Playlist with Selection", @"Player", @"")];
	//	[buttonMenuItem setImage:[NSImage imageNamed:@"StaticPlaylist.png"]];
	[buttonMenuItem setTarget:self];
	[buttonMenuItem setAction:@selector(insertPlaylistWithSelection:)];
	[buttonMenu addItem:buttonMenuItem];
	[buttonMenuItem bind:@"enabled"
				toObject:_browserController
			 withKeyPath:@"canInsertPlaylist"
				 options:nil];
	[buttonMenuItem bind:@"enabled2"
				toObject:_streamController
			 withKeyPath:@"selectedObjects.@count"
				 options:nil];
	[buttonMenuItem release];
	
/*	buttonMenuItem		= [[NSMenuItem alloc] init];
	[buttonMenuItem setTitle:NSLocalizedStringFromTable(@"New Dynamic Playlist", @"Player", @"")];
	//	[buttonMenuItem setImage:[NSImage imageNamed:@"DynamicPlaylist.png"]];
	[buttonMenuItem setTarget:self];
	[buttonMenuItem setAction:@selector(insertDynamicPlaylist:)];
	[buttonMenu addItem:buttonMenuItem];
	[buttonMenuItem release];
	
	buttonMenuItem		= [[NSMenuItem alloc] init];
	[buttonMenuItem setTitle:NSLocalizedStringFromTable(@"New Folder Playlist", @"Player", @"")];
	//	[buttonMenuItem setImage:[NSImage imageNamed:@"FolderPlaylist.png"]];
	[buttonMenuItem setTarget:self];
	[buttonMenuItem setAction:@selector(insertFolderPlaylist:)];
	[buttonMenu addItem:buttonMenuItem];
	[buttonMenuItem release];
	*/
	[_addPlaylistButton setMenu:buttonMenu];
	[buttonMenu release];
	
	[_removePlaylistsButton setToolTip:NSLocalizedStringFromTable(@"Remove the selected playlists from the library", @"Player", @"")];
	[_removePlaylistsButton bind:@"enabled"
						toObject:_browserController
					 withKeyPath:@"canRemove"
						 options:nil];
	[_removePlaylistsButton setAction:@selector(remove:)];
	[_removePlaylistsButton setTarget:_browserController];
	
	[_playlistInfoButton setToolTip:NSLocalizedStringFromTable(@"Show information on the selected playlist", @"Player", @"")];
	[_playlistInfoButton bind:@"enabled"
					 toObject:_browserController
				  withKeyPath:@"selectedObjects.@count"
					  options:nil];
	[_playlistInfoButton setAction:@selector(showPlaylistInformationSheet:)];
	[_playlistInfoButton setTarget:self];
}

- (void) setupStreamTableColumns
{
	id <NSMenuItem> contextMenuItem;	
	id				obj;
	int				menuIndex, i;
	
	// Setup stream table columns
	NSDictionary	*visibleDictionary	= [[NSUserDefaults standardUserDefaults] objectForKey:@"streamTableColumnVisibility"];
	NSDictionary	*sizesDictionary	= [[NSUserDefaults standardUserDefaults] objectForKey:@"streamTableColumnSizes"];
	NSArray			*orderArray			= [[NSUserDefaults standardUserDefaults] objectForKey:@"streamTableColumnOrder"];
	
	NSArray			*tableColumns		= [_streamTable tableColumns];
	NSEnumerator	*enumerator			= [tableColumns objectEnumerator];
	
	_streamTableVisibleColumns			= [[NSMutableSet alloc] init];
	_streamTableHiddenColumns			= [[NSMutableSet alloc] init];
	_streamTableHeaderContextMenu		= [[NSMenu alloc] initWithTitle:@"Stream Table Header Context Menu"];
	
	[[_streamTable headerView] setMenu:_streamTableHeaderContextMenu];
	
	// Keep our changes from generating notifications to ourselves
	[_streamTable setDelegate:nil];
	
	while((obj = [enumerator nextObject])) {
		menuIndex = 0;
		
		while(menuIndex < [_streamTableHeaderContextMenu numberOfItems] 
			  && NSOrderedDescending == [[[obj headerCell] title] localizedCompare:[[_streamTableHeaderContextMenu itemAtIndex:menuIndex] title]]) {
			menuIndex++;
		}
		
		contextMenuItem = [_streamTableHeaderContextMenu insertItemWithTitle:[[obj headerCell] title] action:@selector(streamTableHeaderContextMenuSelected:) keyEquivalent:@"" atIndex:menuIndex];
		
		[contextMenuItem setTarget:self];
		[contextMenuItem setRepresentedObject:obj];
		[contextMenuItem setState:([[visibleDictionary objectForKey:[obj identifier]] boolValue] ? NSOnState : NSOffState)];
		
		//		NSLog(@"setting width of %@ to %f", [obj identifier], [[sizesDictionary objectForKey:[obj identifier]] floatValue]);
		[obj setWidth:[[sizesDictionary objectForKey:[obj identifier]] floatValue]];
		
		if([[visibleDictionary objectForKey:[obj identifier]] boolValue]) {
			[_streamTableVisibleColumns addObject:obj];
		}
		else {
			[_streamTableHiddenColumns addObject:obj];
			[_streamTable removeTableColumn:obj];
		}
	}
	
	i = 0;
	enumerator = [orderArray objectEnumerator];
	while((obj = [enumerator nextObject])) {
		[_streamTable moveColumn:[_streamTable columnWithIdentifier:obj] toColumn:i];
		++i;
	}
	
	[_streamTable setDelegate:self];
}

#pragma mark Stream Table Management

- (void) saveStreamTableColumnOrder
{
	NSMutableArray	*identifiers	= [NSMutableArray array];
	NSEnumerator	*enumerator		= [[_streamTable tableColumns] objectEnumerator];
	id				obj;
	
	while((obj = [enumerator nextObject])) {
		[identifiers addObject:[obj identifier]];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:identifiers forKey:@"streamTableColumnOrder"];
	//	[[NSUserDefaults standardUserDefaults] synchronize];
}	

- (IBAction) streamTableHeaderContextMenuSelected:(id)sender
{
	if(NSOnState == [sender state]) {
		[sender setState:NSOffState];
		[_streamTableHiddenColumns addObject:[sender representedObject]];
		[_streamTableVisibleColumns removeObject:[sender representedObject]];
		[_streamTable removeTableColumn:[sender representedObject]];
	}
	else {
		[sender setState:NSOnState];
		[_streamTable addTableColumn:[sender representedObject]];
		[_streamTableVisibleColumns addObject:[sender representedObject]];
		[_streamTableHiddenColumns removeObject:[sender representedObject]];
	}
	
	NSMutableDictionary	*visibleDictionary	= [NSMutableDictionary dictionary];
	NSEnumerator		*enumerator			= [_streamTableVisibleColumns objectEnumerator];
	id					obj;
	
	while((obj = [enumerator nextObject])) {
		[visibleDictionary setObject:[NSNumber numberWithBool:YES] forKey:[obj identifier]];
	}
	
	enumerator = [_streamTableHiddenColumns objectEnumerator];
	while((obj = [enumerator nextObject])) {
		[visibleDictionary setObject:[NSNumber numberWithBool:NO] forKey:[obj identifier]];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:visibleDictionary forKey:@"streamTableColumnVisibility"];
	
	[self saveStreamTableColumnOrder];
}

@end
