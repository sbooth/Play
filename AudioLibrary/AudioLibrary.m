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

#import "BrowserNode.h"
#import "AudioStreamCollectionNode.h"
#import "LibraryNode.h"
#import "ArtistsNode.h"
#import "AlbumsNode.h"

#import "IconFamily.h"
#import "ImageAndTextCell.h"

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

- (void) playStream:(AudioStream *)stream;

- (void) updatePlayButtonState;

- (void) setupBrowser;

- (void) setupStreamButtons;
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
	}
	return self;
}

- (void) dealloc
{
	[[CollectionManager manager] disconnectFromDatabase];

	[_player release], _player = nil;

	[_streamTableVisibleColumns release], _streamTableVisibleColumns = nil;
	[_streamTableHiddenColumns release], _streamTableHiddenColumns = nil;
	[_streamTableHeaderContextMenu release], _streamTableHeaderContextMenu = nil;

	[_nowPlaying release], _nowPlaying = nil;

	[_playbackContext release], _playbackContext = nil;
	
	[_browserRoot release], _browserRoot = nil;
	
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
	
	// Setup drag and drop
	[_streamTable registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, NSURLPboardType, nil]];
//	[_playlistTable registerForDraggedTypes:[NSArray arrayWithObject:@"AudioStreamPboardType"]];
	
	// Set sort descriptors
	[_streamController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:MetadataAlbumTitleKey ascending:YES] autorelease],
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
	}
	else if([anItem action] == @selector(insertPlaylist:)
			|| [anItem action] == @selector(insertDynamicPlaylist:)
			|| [anItem action] == @selector(insertFolderPlaylist:)) {
		return [_playlistController canInsert];
	}
	else if([anItem action] == @selector(insertPlaylistWithSelection:)) {
		return ([_playlistController canInsert] && 0 != [[_streamController selectedObjects] count]);
	}*/
	else if([anItem action] == @selector(scrollNowPlayingToVisible:)) {
		return (nil != [self nowPlaying] && [[_streamController arrangedObjects] containsObject:[self nowPlaying]]);
	}
	else if([anItem action] == @selector(showPlaybackContext:)) {
		return (nil != [self playbackContext]);
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
	NSLog(@"AudioLibrary observeValueForKeyPath:%@ object:%@",keyPath,object);
	[_browserOutlineView reloadItem:object reloadChildren:YES];
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

- (IBAction) scrollNowPlayingToVisible:(id)sender
{
	AudioStream *stream = [self nowPlaying];
	if(nil != stream && [[_streamController arrangedObjects] containsObject:stream]) {
		[_streamTable scrollRowToVisible:[[_streamController arrangedObjects] indexOfObject:stream]];
	}
}

- (IBAction) showPlaybackContext:(id)sender
{
	if(nil == [self playbackContext]) {
		return;
	}
	
//	[self willChangeValueForKey:@"streams"];
//	[_streams removeAllObjects];
//	[_streams addObjectsFromArray:[self playbackContext]];
//	[self didChangeValueForKey:@"streams"];
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
	AudioStream				*stream				= nil;
	NSError					*error				= nil;
//	NSArray					*selectedPlaylists	= [_playlistController selectedObjects];
	
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
		
//		if(0 < [selectedPlaylists count]) {
//			[playlist addStream:stream];
//		}
	}
	else {
		// If we couldn't add the file, cheeck if it exists in the library
		// Perform this check here, not at the beginning, to avoid hitting the database twice
		// for every file addition
		stream = [[[CollectionManager manager] streamManager] streamForURL:[NSURL fileURLWithPath:filename]];
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
/*	NSDictionary *initialValues = [NSDictionary dictionaryWithObject:NSLocalizedStringFromTable(@"Untitled Playlist", @"General", @"") forKey:PlaylistNameKey];
	Playlist *playlist = [Playlist insertPlaylistWithInitialValues:initialValues];
	if(nil != playlist) {
		[_playlistController addObject:playlist];

		[_browserDrawer open:self];
		
		if([_playlistController setSelectedObjects:[NSArray arrayWithObject:playlist]]) {
			// The playlist table has only one column for now
			[_playlistTable editColumn:0 row:[_playlistTable selectedRow] withEvent:nil select:YES];	
		}

		[[NSNotificationCenter defaultCenter] postNotificationName:PlaylistAddedToLibraryNotification 
															object:self 
														  userInfo:[NSDictionary dictionaryWithObject:playlist forKey:PlaylistObjectKey]];
	}*/
}

- (IBAction) insertPlaylistWithSelection:(id)sender;
{
/*	NSDictionary *initialValues = [NSDictionary dictionaryWithObject:NSLocalizedStringFromTable(@"Untitled Playlist", @"General", @"") forKey:PlaylistNameKey];
	Playlist *playlist = [Playlist insertPlaylistWithInitialValues:initialValues];
	if(nil != playlist) {
		[playlist addStreams:[_streamController selectedObjects]];
		[_playlistController addObject:playlist];
		
		[_browserDrawer open:self];
		
		if([_playlistController setSelectedObjects:[NSArray arrayWithObject:playlist]]) {
			// The playlist table has only one column for now
			[_playlistTable editColumn:0 row:[_playlistTable selectedRow] withEvent:nil select:YES];	
		}
		
		[[NSNotificationCenter defaultCenter] postNotificationName:PlaylistAddedToLibraryNotification 
															object:self 
														  userInfo:[NSDictionary dictionaryWithObject:playlist forKey:PlaylistObjectKey]];
	}*/
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
	BOOL			success		= YES;
	AudioStream		*stream		= [[[CollectionManager manager] streamManager] streamForURL:[NSURL fileURLWithPath:filename]];

	// If it wasn't found, try and add it
	if(nil == stream) {
		success = [self addFile:filename];
		if(success) {
			stream = [[[CollectionManager manager] streamManager] streamForURL:[NSURL fileURLWithPath:filename]];
		}
	}
	
	// Play the file, if everything worked
	if(nil != stream) {
		[self playStream:stream];
	}
	
	return success;
}

- (IBAction) play:(id)sender
{
	if(NO == [[self player] hasValidStream]) {
		if([self randomizePlayback]) {
			NSArray				*streams;
			AudioStream			*stream;	
			double				randomNumber;
			unsigned			randomIndex;
			
			streams				= [_streamController arrangedObjects];
			randomNumber		= genrand_real2();
			randomIndex			= (unsigned)(randomNumber * [streams count]);
			stream				= [streams objectAtIndex:randomIndex];
			
			[self setPlaybackContext:[_streamController arrangedObjects]];			
			[self playStream:stream];
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
	
	if(0 == [[_streamController selectedObjects] count]) {
		[self setPlaybackContext:[_streamController arrangedObjects]];		
		[self playStream:[[_streamController arrangedObjects] objectAtIndex:0]];
	}
	else {
		[self setPlaybackContext:[_streamController arrangedObjects]];		
		[self playStream:[[_streamController selectedObjects] objectAtIndex:0]];
	}
	
	[self updatePlayButtonState];
}

- (IBAction) stop:(id)sender
{
	AudioStream *stream = [self nowPlaying];
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
	
	NSArray *streams = [self playbackContext];
	
	if(nil == stream || 0 == [streams count]) {
		[[self player] reset];
		[self updatePlayButtonState];
	}
	else if([self randomizePlayback]) {
		double			randomNumber;
		unsigned		randomIndex;
		
		randomNumber	= genrand_real2();
		randomIndex		= (unsigned)(randomNumber * [streams count]);
		stream			= [streams objectAtIndex:randomIndex];
		
		[self playStream:stream];
	}
	else if([self loopPlayback]) {
		streamIndex = [streams indexOfObject:stream];
		
		if(streamIndex + 1 < [streams count]) {
			stream = [streams objectAtIndex:streamIndex + 1];			
		}
		else {
			stream = [streams objectAtIndex:0];
		}
		
		[self playStream:stream];
	}
	else {
		streamIndex = [streams indexOfObject:stream];
		
		if(streamIndex + 1 < [streams count]) {
			stream = [streams objectAtIndex:streamIndex + 1];
			[self playStream:stream];
		}
		else {
			[[self player] reset];
			[self setPlaybackContext:nil];
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
	
	NSArray *streams = [self playbackContext];
	
	if(nil == stream || 0 == [streams count]) {
		[[self player] reset];	
	}
	else if([self randomizePlayback]) {
		double			randomNumber;
		unsigned		randomIndex;
		
		randomNumber	= genrand_real2();
		randomIndex		= (unsigned)(randomNumber * [streams count]);
		stream			= [streams objectAtIndex:randomIndex];
		
		[self playStream:stream];
	}
	else if([self loopPlayback]) {
		streamIndex = [streams indexOfObject:stream];
		
		if(1 <= streamIndex) {
			stream = [streams objectAtIndex:streamIndex - 1];
		}
		else {
			stream = [streams objectAtIndex:[streams count] - 1];
		}
		
		[self playStream:stream];
	}
	else {
		streamIndex = [streams indexOfObject:stream];
		
		if(1 <= streamIndex) {
			stream = [streams objectAtIndex:streamIndex - 1];
			[self playStream:stream];
		}
		else {
			[[self player] reset];	
		}
	}
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
	AudioStream		*stream		= [self nowPlaying];
	NSArray			*streams	= [self playbackContext];
	BOOL			result;
	
	if(nil == stream || 0 == [streams count]) {
		result = NO;
	}
	else if([self randomizePlayback]) {
		result = YES;
	}
	else if([self loopPlayback]) {
		result = YES;
	}
	else {
		unsigned streamIndex = [streams indexOfObject:stream];
		result = (streamIndex + 1 < [streams count]);
	}
	
	return result;
}

- (BOOL) canPlayPreviousStream
{
	AudioStream		*stream		= [self nowPlaying];
	NSArray			*streams	= [self playbackContext];
	BOOL			result;
	
	if(nil == stream || 0 == [streams count]) {
		result = NO;
	}
	else if([self randomizePlayback]) {
		result = YES;
	}
	else if([self loopPlayback]) {
		result = YES;
	}
	else {
		unsigned streamIndex = [streams indexOfObject:stream];
		result = (1 <= streamIndex);
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

- (NSArray *)	playbackContext
{
	return _playbackContext;
}

- (void) setPlaybackContext:(NSArray *)playbackContext
{
	[_playbackContext release];
	_playbackContext = [playbackContext copy];
}

/*#pragma mark Playlist KVC Accessor Methods

- (unsigned int) countOfPlaylists
{
	return [_playlists count];
}

- (id) objectInPlaylistsAtIndex:(unsigned int)index
{
	// The playlist in question already exists in the database if it is in the array
	return [_playlists objectAtIndex:index];
}

- (void) getPlaylists:(id *)buffer range:(NSRange)aRange
{
	// The playlists in question already exist in the database if they are in the array
	return [_playlists getObjects:buffer range:aRange];
}

#pragma mark Playlist KVC Mutator Methods

- (void) insertObject:(id)playlist inPlaylistsAtIndex:(unsigned int)index
{
	// The playlist represented must already be added to the database	
	[_playlists insertObject:playlist atIndex:index];

	[[NSNotificationCenter defaultCenter] postNotificationName:PlaylistAddedToLibraryNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:playlist forKey:AudioStreamObjectKey]];
}

- (void) removeObjectFromPlaylistsAtIndex:(unsigned int)index
{
	Playlist *playlist = [_playlists objectAtIndex:index];
		
	// Just in case the notification's receiver mucks with the object
//	[playlist setNotificationsEnabled:NO];

	// To keep the database and in-memory representation in sync, remove the 
	// playlist from the database first and then from the array if the removal
	// was successful
	[playlist delete];		
	[_playlists removeObjectAtIndex:index];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:PlaylistRemovedFromLibraryNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:playlist forKey:PlaylistObjectKey]];	
}
*/
#pragma mark AudioPlayer Callbacks

- (void) streamPlaybackDidStart:(AudioStream *)startedStream
{
	NSParameterAssert(nil != startedStream);
	
	AudioStream		*stream		= [self nowPlaying];
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
	
//	stream = [[[CollectionManager manager] streamManager] streamForURL:url];
//	NSAssert(nil != stream, @"Playback started for stream not in library!");
	
	[startedStream setPlaying:YES];
	[self setNowPlaying:startedStream];
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidStartNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:startedStream forKey:AudioStreamObjectKey]];
}

- (void) streamPlaybackDidComplete:(AudioStream *)unused
{
	AudioStream		*stream		= [self nowPlaying];
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
	
	[self playNextStream:self];
}

- (void) requestNextStream
{
	AudioStream		*stream			= [self nowPlaying];
	unsigned		streamIndex;
	
	NSArray *streams = [self playbackContext];
	
	if(nil == stream || 0 == [streams count]) {
		stream = nil;
	}
	else if([self randomizePlayback]) {
		double			randomNumber;
		unsigned		randomIndex;
		
		randomNumber	= genrand_real2();
		randomIndex		= (unsigned)(randomNumber * [streams count]);
		stream			= [streams objectAtIndex:randomIndex];
	}
	else if([self loopPlayback]) {
		streamIndex = [streams indexOfObject:stream];
		
		if(streamIndex + 1 < [streams count]) {
			stream = [streams objectAtIndex:streamIndex + 1];			
		}
		else {
			stream = [streams objectAtIndex:0];
		}
	}
	else {
		streamIndex = [streams indexOfObject:stream];
		
		if(streamIndex + 1 < [streams count]) {
			stream = [streams objectAtIndex:streamIndex + 1];
		}
		else {
			stream = nil;
		}
	}
	
	if(nil != stream) {
		NSError		*error		= nil;
		BOOL		result		= [[self player] setNextStream:stream error:&error];

		if(NO == result) {
			if(nil != error) {
				
			}
		}
	}
}

@end

@implementation AudioLibrary (NSTableViewDelegateMethods)

- (void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
/*	if([[aNotification object] isEqual:_playlistTable]) {
		
		unsigned count = [[_playlistController selectedObjects] count];
		
		if(0 == count) {
			[self willChangeValueForKey:@"streams"];
			[_streams removeAllObjects];
			[_streams addObjectsFromArray:[[[CollectionManager manager] streamManager] streams]];
			[self didChangeValueForKey:@"streams"];
		}
		else if(1 == count) {
			Playlist *playlist = [[_playlistController selectedObjects] objectAtIndex:0];
			[self willChangeValueForKey:@"streams"];
			[_streams removeAllObjects];
			[_streams addObjectsFromArray:[[playlist entries] valueForKey:@"stream"]];
			[self didChangeValueForKey:@"streams"];
		}
		else {
			// SELECT [...] FROM streams WHERE id IN (SELECT stream_id FROM _playlist_9) OR id IN (SELECT stream_id FROM _playlist_10)
		}		
	}*/
}

- (NSString *) tableView:(NSTableView *)aTableView toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(int)row mouseLocation:(NSPoint)mouseLocation
{
    if([aCell isKindOfClass:[NSTextFieldCell class]]) {
        if([[aCell attributedStringValue] size].width > rect->size.width) {
            return [aCell stringValue];
        }
    }
	
    return nil;
}

- (void) tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
/*	if([aTableView isEqual:_playlistTable] && [[aTableColumn identifier] isEqualToString:@"name"]) {
		NSDictionary *infoForBinding = [aTableView infoForBinding:NSContentBinding];

		if(nil != infoForBinding) {
			NSArrayController	*arrayController	= [infoForBinding objectForKey:NSObservedObjectKey];
			Playlist			*playlist			= [[arrayController arrangedObjects] objectAtIndex:rowIndex];
			
//			[aCell setImage:[playlistObject imageScaledToSize:NSMakeSize(16.0, 16.0)]];
		}
	}
	else*/ if([aTableView isEqual:_streamTable]) {
		NSDictionary *infoForBinding = [aTableView infoForBinding:NSContentBinding];

		if(nil != infoForBinding && [aCell respondsToSelector:@selector(setDrawsBackground:)]) {
			NSArrayController	*arrayController	= [infoForBinding objectForKey:NSObservedObjectKey];
			AudioStream			*stream				= [[arrayController arrangedObjects] objectAtIndex:rowIndex];
			
			// Highlight the currently playing stream (doesn't work for NSButtonCell)
			if([stream isPlaying]) {
				[aCell setDrawsBackground:YES];
				
				// Emacs "NavajoWhite" -> 255, 222, 173
				//				[aCell setBackgroundColor:[NSColor colorWithCalibratedRed:(255/255.f) green:(222/255.f) blue:(173/255.f) alpha:1.0]];
				// Emacs "LightSteelBlue" -> 176, 196, 222
				[aCell setBackgroundColor:[NSColor colorWithCalibratedRed:(176/255.f) green:(196/255.f) blue:(222/255.f) alpha:1.0]];
			}
			else {
				[aCell setDrawsBackground:NO];
			}
		}
	}
}

- (void) tableViewColumnDidMove:(NSNotification *)aNotification
{
	if([[aNotification object] isEqual:_streamTable]) {
		[self saveStreamTableColumnOrder];
	}
}

- (void) tableViewColumnDidResize:(NSNotification *)aNotification
{
	if([[aNotification object] isEqual:_streamTable]) {
		NSMutableDictionary		*sizes			= [NSMutableDictionary dictionary];
		NSEnumerator			*enumerator		= [[_streamTable tableColumns] objectEnumerator];
		id						column;
		
		while((column = [enumerator nextObject])) {
			[sizes setObject:[NSNumber numberWithFloat:[column width]] forKey:[column identifier]];
		}
		
		[[NSUserDefaults standardUserDefaults] setObject:sizes forKey:@"streamTableColumnSizes"];
	}
}

@end

@implementation AudioLibrary (NSOutlineViewDelegateMethods)

/*- (BOOL) outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	return [[(BrowserNode *)item representedObject] isSelectable];
}*/

/*- (BOOL) outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item
{
	int				selectedRow		= [outlineView selectedRow];
	BrowserNode		*selectedNode	= [outlineView itemAtRow:selectedRow];
	
	return (NO == [selectedNode isDescendantOfNode:item]);
}*/

/*- (BOOL) outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	return NO;
}*/

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
	NSOutlineView *outlineView = [notification object];
	
	if([[notification object] isEqual:_browserOutlineView]) {
		
		int					selectedRow		= [outlineView selectedRow];
		id					opaqueNode		= [outlineView itemAtRow:selectedRow];
		BrowserNode			*node			= [opaqueNode observedObject];

		if(nil == node) {
			return;
		}
		
		NSArray				*selected		= [_streamController selectedObjects];
		
		// Display the appropriate set of streams if the selected node supports it
		if([[node exposedBindings] containsObject:@"streams"]) {
			
			// Don't re-bind to the same data source
			NSDictionary *bindingInfo = [_streamController infoForBinding:@"contentArray"];
			if(NO == [[bindingInfo valueForKey:NSObservedObjectKey] isEqual:node]) {
				[_streamController unbind:@"contentArray"];
				[_streamController setContent:nil];
				
				[_streamController bind:@"contentArray" toObject:node withKeyPath:@"streams" options:nil];
				[_streamController setSelectedObjects:selected];
			}			
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

- (void) playStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);

	AudioStream *currentStream = [self nowPlaying];
	
	[[self player] stop];
	
	if(nil != currentStream) {
		[currentStream setPlaying:NO];
		[self setNowPlaying:nil];
	}
	
	NSError		*error		= nil;
	BOOL		result		= [[self player] setStream:stream error:&error];
	
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
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidStartNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
	
	[self updatePlayButtonState];
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
		
		[self setPlayButtonEnabled:(0 != [[_streamController arrangedObjects] count])];
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

	_browserRoot = [[BrowserNode alloc] initWithName:NSLocalizedStringFromTable(@"Collection", @"General", @"")];
	[_browserRoot setIcon:folderIcon];
	
	LibraryNode *libraryNode = [[LibraryNode alloc] init];
	[libraryNode setIcon:cdIcon];

	ArtistsNode *artistsNode = [[ArtistsNode alloc] init];
	[artistsNode setIcon:folderIcon];

	[artistsNode addObserver:self forKeyPath:@"children" options:nil context:nil];
	
	AlbumsNode *albumsNode = [[AlbumsNode alloc] init];
	[albumsNode setIcon:folderIcon];

	[albumsNode addObserver:self forKeyPath:@"children" options:nil context:nil];
	
	BrowserNode *playlistsNode = [[BrowserNode alloc] initWithName:NSLocalizedStringFromTable(@"Playlists", @"General", @"")];
	[playlistsNode setIcon:folderIcon];

	BrowserNode *watchedFoldersNode = [[BrowserNode alloc] initWithName:NSLocalizedStringFromTable(@"Watch Folders", @"General", @"")];
	[watchedFoldersNode setIcon:folderIcon];

	[_browserRoot addChild:[libraryNode autorelease]];
	[_browserRoot addChild:[artistsNode autorelease]];
	[_browserRoot addChild:[albumsNode autorelease]];
	[_browserRoot addChild:[playlistsNode autorelease]];
	[_browserRoot addChild:[watchedFoldersNode autorelease]];
	[_browserController setContent:_browserRoot];
	
	// Select the LibraryNode
	unsigned indexPathIndexes [] = {0, 0};
	BOOL success = [_browserController setSelectionIndexPath:[NSIndexPath indexPathWithIndexes:indexPathIndexes length:2]];
	NSAssert(YES == success, @"Unable to set selection in browser");
	
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

/* - (void) setupPlaylistButtons
{
	NSMenu			*buttonMenu;
	NSMenuItem		*buttonMenuItem;
	
	// Bind playlist addition/removal button actions and state
	[_addPlaylistButton setToolTip:NSLocalizedStringFromTable(@"Add a new playlist to the library", @"Player", @"")];
	[_addPlaylistButton bind:@"enabled"
					toObject:_playlistController
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
				toObject:_playlistController
			 withKeyPath:@"canInsert"
				 options:nil];
	[buttonMenuItem release];
	
	buttonMenuItem		= [[NSMenuItem alloc] init];
	[buttonMenuItem setTitle:NSLocalizedStringFromTable(@"New Playlist with Selection", @"Player", @"")];
	//	[buttonMenuItem setImage:[NSImage imageNamed:@"StaticPlaylist.png"]];
	[buttonMenuItem setTarget:self];
	[buttonMenuItem setAction:@selector(insertPlaylistWithSelection:)];
	[buttonMenu addItem:buttonMenuItem];
	[buttonMenuItem bind:@"enabled"
				toObject:_playlistController
			 withKeyPath:@"canInsert"
				 options:nil];
	[buttonMenuItem bind:@"enabled2"
				toObject:_streamController
			 withKeyPath:@"selectedObjects.@count"
				 options:nil];
	[buttonMenuItem release];
	
	buttonMenuItem		= [[NSMenuItem alloc] init];
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
	
	[_addPlaylistButton setMenu:buttonMenu];
	[buttonMenu release];
	
	[_removePlaylistsButton setToolTip:NSLocalizedStringFromTable(@"Remove the selected playlists from the library", @"Player", @"")];
	[_removePlaylistsButton bind:@"enabled"
						toObject:_playlistController
					 withKeyPath:@"canRemove"
						 options:nil];
	[_removePlaylistsButton setAction:@selector(remove:)];
	[_removePlaylistsButton setTarget:_playlistController];
	
	[_playlistInfoButton setToolTip:NSLocalizedStringFromTable(@"Show information on the selected playlist", @"Player", @"")];
	[_playlistInfoButton bind:@"enabled"
					 toObject:_playlistController
				  withKeyPath:@"selectedObjects.@count"
					  options:nil];
	[_playlistInfoButton setAction:@selector(showPlaylistInformationSheet:)];
	[_playlistInfoButton setTarget:self];
}*/

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
