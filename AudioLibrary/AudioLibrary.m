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
#import "SmartPlaylist.h"
#import "WatchFolder.h"

#import "AudioPropertiesReader.h"
#import "AudioMetadataReader.h"
#import "AudioMetadataWriter.h"

#import "PlaylistInformationSheet.h"
#import "SmartPlaylistInformationSheet.h"
#import "NewWatchFolderSheet.h"
#import "FileAdditionProgressSheet.h"

#import "AudioStreamArrayController.h"
#import "BrowserTreeController.h"
#import "AudioStreamTableView.h"
#import "PlayQueueTableView.h"
#import "BrowserOutlineView.h"
#import "RBSplitView.h"

#import "BrowserNode.h"
#import "AudioStreamCollectionNode.h"
#import "LibraryNode.h"
#import "ArtistsNode.h"
#import "AlbumsNode.h"
#import "GenresNode.h"
#import "PlaylistsNode.h"
#import "PlaylistNode.h"
#import "SmartPlaylistsNode.h"
#import "SmartPlaylistNode.h"
#import "WatchFoldersNode.h"
#import "WatchFolderNode.h"
#import "MostPopularNode.h"
#import "RecentlyAddedNode.h"
#import "RecentlyPlayedNode.h"

#import "IconFamily.h"
#import "ImageAndTextCell.h"

#import "CTGradient.h"

#import "NSTreeController_Extensions.h"

#include "sfmt19937.h"

// ========================================
// The global instance
// ========================================
static AudioLibrary *libraryInstance = nil;

// ========================================
// Notification names
// ========================================
NSString * const	AudioStreamsAddedToLibraryNotification		= @"org.sbooth.Play.AudioLibrary.AudioStreamsAddedToLibraryNotification";
NSString * const	AudioStreamAddedToLibraryNotification		= @"org.sbooth.Play.AudioLibrary.AudioStreamAddedToLibraryNotification";

NSString * const	AudioStreamRemovedFromLibraryNotification	= @"org.sbooth.Play.AudioLibrary.AudioStreamRemovedFromLibraryNotification";
NSString * const	AudioStreamsRemovedFromLibraryNotification	= @"org.sbooth.Play.AudioLibrary.AudioStreamsRemovedFromLibraryNotification";

NSString * const	AudioStreamDidChangeNotification			= @"org.sbooth.Play.AudioLibrary.AudioStreamDidChangeNotification";
NSString * const	AudioStreamsDidChangeNotification			= @"org.sbooth.Play.AudioLibrary.AudioStreamsDidChangeNotification";

NSString * const	AudioStreamPlaybackDidStartNotification		= @"org.sbooth.Play.AudioLibrary.AudioStreamPlaybackDidStartNotification";
NSString * const	AudioStreamPlaybackDidStopNotification		= @"org.sbooth.Play.AudioLibrary.AudioStreamPlaybackDidStopNotification";
NSString * const	AudioStreamPlaybackDidPauseNotification		= @"org.sbooth.Play.AudioLibrary.AudioStreamPlaybackDidPauseNotification";
NSString * const	AudioStreamPlaybackDidResumeNotification	= @"org.sbooth.Play.AudioLibrary.AudioStreamPlaybackDidResumeNotification";
NSString * const	AudioStreamPlaybackDidCompleteNotification	= @"org.sbooth.Play.AudioLibrary.AudioStreamPlaybackDidCompleteNotification";

NSString * const	PlaylistAddedToLibraryNotification			= @"org.sbooth.Play.AudioLibrary.PlaylistAddedToLibraryNotification";
NSString * const	PlaylistRemovedFromLibraryNotification		= @"org.sbooth.Play.AudioLibrary.PlaylistRemovedFromLibraryNotification";
NSString * const	PlaylistDidChangeNotification				= @"org.sbooth.Play.PlaylistDidChangeNotification";

NSString * const	SmartPlaylistAddedToLibraryNotification		= @"org.sbooth.Play.AudioLibrary.SmartPlaylistAddedToLibraryNotification";
NSString * const	SmartPlaylistRemovedFromLibraryNotification	= @"org.sbooth.Play.AudioLibrary.SmartPlaylistRemovedFromLibraryNotification";
NSString * const	SmartPlaylistDidChangeNotification			= @"org.sbooth.Play.SmartPlaylistDidChangeNotification";

NSString * const	WatchFolderAddedToLibraryNotification		= @"org.sbooth.Play.AudioLibrary.WatchFolderAddedToLibraryNotification";
NSString * const	WatchFolderRemovedFromLibraryNotification	= @"org.sbooth.Play.AudioLibrary.WatchFolderRemovedFromLibraryNotification";
NSString * const	WatchFolderDidChangeNotification			= @"org.sbooth.Play.WatchFolderDidChangeNotification";

// ========================================
// Notification keys
// ========================================
NSString * const	AudioStreamObjectKey						= @"org.sbooth.Play.AudioStream";
NSString * const	AudioStreamsObjectKey						= @"org.sbooth.Play.AudioStreams";
NSString * const	PlaylistObjectKey							= @"org.sbooth.Play.Playlist";
NSString * const	SmartPlaylistObjectKey						= @"org.sbooth.Play.SmartPlaylist";
NSString * const	WatchFolderObjectKey						= @"org.sbooth.Play.WatchFolder";

// ========================================
// KVC key names
// ========================================
NSString * const	PlayQueueKey								= @"playQueue";

// ========================================
// Completely bogus NSTreeController bindings hack
// ========================================
@interface NSObject (NSTreeControllerBogosity)
- (id) observedObject;
@end

// ========================================
// AudioPlayer callbacks
// ========================================
@interface AudioLibrary (AudioPlayerCallbackMethods)
- (void)	streamPlaybackDidStart;
- (void)	streamPlaybackDidComplete;

- (void)	requestNextStream;
@end

// ========================================
// Callback Methods (for sheets, etc.)
// ========================================
@interface AudioLibrary (CallbackMethods)
- (void) openDocumentSheetDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void *)contextInfo;
- (void) showNewWatchFolderSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end

// ========================================
// Private Methods
// ========================================
@interface AudioLibrary (Private)
- (AudioPlayer *) player;

- (void) scrollNowPlayingToVisible;

- (void) setPlayButtonEnabled:(BOOL)playButtonEnabled;

- (unsigned) playbackIndex;
- (void) setPlaybackIndex:(unsigned)playbackIndex;

- (unsigned) nextPlaybackIndex;
- (void) setNextPlaybackIndex:(unsigned)nextPlaybackIndex;

- (void) setPlayQueueFromArray:(NSArray *)streams;

- (void) addRandomStreamsFromLibraryToPlayQueue:(unsigned)count;

- (void) updatePlayQueueHistory;

- (void) updatePlayButtonState;

- (void) setupBrowser;

- (void) setupStreamTableColumns;
- (void) setupPlayQueueTableColumns;

- (void) saveStreamTableColumnOrder;
- (IBAction) streamTableHeaderContextMenuSelected:(id)sender;

- (void) savePlayQueueTableColumnOrder;
- (IBAction) playQueueTableHeaderContextMenuSelected:(id)sender;

- (IBAction) toggleRandomPlayback:(id)sender;
- (IBAction) toggleLoopPlayback:(id)sender;

- (void) streamAdded:(NSNotification *)aNotification;
- (void) streamsAdded:(NSNotification *)aNotification;
- (void) streamRemoved:(NSNotification *)aNotification;
- (void) streamsRemoved:(NSNotification *)aNotification;

@end

@implementation AudioLibrary

+ (void)initialize
{
	[self exposeBinding:@"randomPlayback"];
	[self exposeBinding:@"loopPlayback"];
	[self exposeBinding:PlayQueueKey];
	[self exposeBinding:@"canPlayNextStream"];
	[self exposeBinding:@"canPlayPreviousStream"];
	[self exposeBinding:@"nowPlaying"];
	
	[self setKeys:[NSArray arrayWithObjects:PlayQueueKey, @"playbackIndex", @"randomPlayback", @"loopPlayback", nil] triggerChangeNotificationsForDependentKey:@"canPlayNextStream"];
	[self setKeys:[NSArray arrayWithObjects:PlayQueueKey, @"playbackIndex", @"randomPlayback", @"loopPlayback", nil] triggerChangeNotificationsForDependentKey:@"canPlayPreviousStream"];
	[self setKeys:[NSArray arrayWithObjects:@"playbackIndex", nil] triggerChangeNotificationsForDependentKey:@"nowPlaying"];
	
	// Setup stream table column defaults
	NSDictionary *streamTableVisibleColumnsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
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
	
	NSDictionary *streamTableColumnSizesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
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
	
	NSDictionary *streamTableColumnOrderArray = [NSArray arrayWithObjects:
		@"title", @"artist", @"albumTitle", @"genre", @"track", @"formatType", nil];

	// Setup play queue column defaults
	NSDictionary *playQueueVisibleColumnsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:YES], @"nowPlaying",
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
	
	NSDictionary *playQueueColumnSizesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithFloat:18], @"nowPlaying",
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
	
	NSDictionary *playQueueColumnOrderArray = [NSArray arrayWithObjects:
		@"nowPlaying", @"title", @"artist", @"albumTitle", @"genre", @"track", @"formatType", nil];
	
	NSDictionary *tableDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
		streamTableVisibleColumnsDictionary, @"streamTableColumnVisibility",
		streamTableColumnSizesDictionary, @"streamTableColumnSizes",
		streamTableColumnOrderArray, @"streamTableColumnOrder",
		playQueueVisibleColumnsDictionary, @"playQueueTableColumnVisibility",
		playQueueColumnSizesDictionary, @"playQueueTableColumnSizes",
		playQueueColumnOrderArray, @"playQueueTableColumnOrder",
		nil];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:tableDefaults];
	
	NSDictionary *defaultsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:NO], @"alwaysPlayStreamsWhenDoubleClicked",
		[NSNumber numberWithBool:NO], @"rescanMetadataBeforePlayback",
		[NSNumber numberWithBool:NO], @"limitPlayQueueHistorySize",
		[NSNumber numberWithInt:5], @"playQueueHistorySize",
		nil];

	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDictionary];
}	

+ (AudioLibrary *) library
{
	@synchronized(self) {
		if(nil == libraryInstance) {
			// assignment not done here
			[[self alloc] init];
		}
	}
	return libraryInstance;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == libraryInstance) {
			// assignment and return on first allocation
            libraryInstance = [super allocWithZone:zone];
			return libraryInstance;
        }
    }
    return nil;
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
		
		_playQueue			= [[NSMutableArray alloc] init];
		_playbackIndex		= NSNotFound;
		_nextPlaybackIndex	= NSNotFound;
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(streamAdded:) 
													 name:AudioStreamAddedToLibraryNotification
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(streamsAdded:) 
													 name:AudioStreamsAddedToLibraryNotification
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(streamRemoved:) 
													 name:AudioStreamRemovedFromLibraryNotification
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(streamsRemoved:) 
													 name:AudioStreamsRemovedFromLibraryNotification
												   object:nil];
	}
	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[[CollectionManager manager] disconnectFromDatabase];

	[_player release], _player = nil;

	[_streamTableVisibleColumns release], _streamTableVisibleColumns = nil;
	[_streamTableHiddenColumns release], _streamTableHiddenColumns = nil;
	[_streamTableHeaderContextMenu release], _streamTableHeaderContextMenu = nil;
	[_streamTableSavedSortDescriptors release], _streamTableSavedSortDescriptors = nil;
	[_playQueueTableVisibleColumns release], _playQueueTableVisibleColumns = nil;
	[_playQueueTableHiddenColumns release], _playQueueTableHiddenColumns = nil;
	[_playQueueTableHeaderContextMenu release], _playQueueTableHeaderContextMenu = nil;
	
	[_playQueue release], _playQueue = nil;
	
	[_libraryNode release], _libraryNode = nil;
	
	[super dealloc];
}

- (id) 			copyWithZone:(NSZone *)zone			{ return self; }
- (id) 			retain								{ return self; }
- (unsigned) 	retainCount							{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void) 		release								{ /* do nothing */ }
- (id) 			autorelease							{ return self; }

- (void) awakeFromNib
{
	// Setup streams table
//	[_streamTable setSearchColumnIdentifiers:[NSSet setWithObjects:@"title", @"albumTitle", @"artist", @"albumArtist", @"genre", @"composer", nil]];

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
	
	[self setupStreamTableColumns];
	[self setupPlayQueueTableColumns];
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

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if([menuItem action] == @selector(playPause:)) {
		[menuItem setTitle:([[self player] isPlaying] ? NSLocalizedStringFromTable(@"Pause", @"Menus", @"") : NSLocalizedStringFromTable(@"Play", @"Menus", @""))];
		return [self playButtonEnabled];
	}
	else if([menuItem action] == @selector(addFiles:)) {
		return [_streamController canAdd];
	}
	else if([menuItem action] == @selector(skipForward:) 
			|| [menuItem action] == @selector(skipBackward:) 
			|| [menuItem action] == @selector(skipToEnd:) 
			|| [menuItem action] == @selector(skipToBeginning:)) {
		return [[self player] hasValidStream];
	}
	else if([menuItem action] == @selector(playNextStream:)) {
		return [self canPlayNextStream];
	}
	else if([menuItem action] == @selector(playPreviousStream:)) {
		return [self canPlayPreviousStream];
	}
	else if([menuItem action] == @selector(insertPlaylist:)) {
		return [_browserController canInsert];
	}
	else if([menuItem action] == @selector(jumpToNowPlaying:)) {
		return (nil != [self nowPlaying] && 0 != [self countOfPlayQueue]);
	}
	else if([menuItem action] == @selector(undo:)) {
		return [[self undoManager] canUndo];
	}
	else if([menuItem action] == @selector(redo:)) {
		return [[self undoManager] canRedo];
	}
	else if([menuItem action] == @selector(add10RandomStreamsToPlayQueue:)
			|| [menuItem action] == @selector(add25RandomStreamsToPlayQueue:)) {
		return (0 != [[[[CollectionManager manager] streamManager] streams] count]);
	}
	else if([menuItem action] == @selector(toggleRandomPlayback:)) {
		return (0 != [self countOfPlayQueue] && NO == [self loopPlayback]);
	}
	else if([menuItem action] == @selector(toggleLoopPlayback:)) {
		return (0 != [self countOfPlayQueue] && NO == [self randomPlayback]);
	}
	else if([menuItem action] == @selector(toggleBrowser:)) {
		int state = [_browserDrawer state];
		if(NSDrawerClosingState == state || NSDrawerClosedState == state) {
			[menuItem setTitle:NSLocalizedStringFromTable(@"Show Browser", @"Menus", @"")];
		}
		else {
			[menuItem setTitle:NSLocalizedStringFromTable(@"Hide Browser", @"Menus", @"")];
		}
		return YES;
	}
	else if([menuItem action] == @selector(togglePlayQueue:)) {
		if([[_splitView subviewWithIdentifier:@"playQueue"] isCollapsed]) {
			[menuItem setTitle:NSLocalizedStringFromTable(@"Show Play Queue", @"Menus", @"")];
		}
		else {
			[menuItem setTitle:NSLocalizedStringFromTable(@"Hide Play Queue", @"Menus", @"")];
		}
		return YES;
	}

	return YES;
}

#pragma mark Action Methods

- (IBAction) toggleBrowser:(id)sender
{
	[_browserDrawer toggle:sender];
}

- (IBAction) togglePlayQueue:(id)sender
{
	RBSplitSubview *subView = [_splitView subviewWithIdentifier:@"playQueue"];
	if([subView isCollapsed]) {
		[subView expand];
	}
	else {
		[subView collapse];
	}
}

- (IBAction) add10RandomStreamsToPlayQueue:(id)sender
{
	[self addRandomStreamsFromLibraryToPlayQueue:10];
}

- (IBAction) add25RandomStreamsToPlayQueue:(id)sender
{
	[self addRandomStreamsFromLibraryToPlayQueue:25];
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

- (IBAction) jumpToLibrary:(id)sender
{
	/*BOOL success =*/ [self selectLibraryNode];
}

- (IBAction) jumpToNowPlaying:(id)sender
{
	if(nil != [self nowPlaying] && 0 != [self countOfPlayQueue]) {
		RBSplitSubview *subView = [_splitView subviewWithIdentifier:@"playQueue"];
		if([subView isCollapsed]) {
			[subView expandWithAnimation];
		}
		[self scrollNowPlayingToVisible];
		[_playQueueController setSelectionIndex:[self playbackIndex]];
	}
}

#pragma mark File Addition and Removal

- (BOOL) addFile:(NSString *)filename
{
	NSParameterAssert(nil != filename);
	
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
	
/*	if(nil != stream) {
		if([_browserController selectedNodeIsPlaylist]) {
			[[(PlaylistNode *)[_browserController selectedNode] playlist] addStream:stream];
		}
	}*/
		
	return (nil != stream);
}

- (BOOL) addFiles:(NSArray *)filenames
{
	return [self addFiles:filenames inModalSession:NULL];
}

- (BOOL) addFiles:(NSArray *)filenames inModalSession:(NSModalSession)modalSession
{
	NSParameterAssert(nil != filenames);
	
	NSString				*filename				= nil;
	NSString				*path					= nil;
	NSFileManager			*fileManager			= [NSFileManager defaultManager];
	NSEnumerator			*filesEnumerator		= [filenames objectEnumerator];
	NSDirectoryEnumerator	*directoryEnumerator	= nil;
	BOOL					isDirectory				= NO;
	BOOL					openSuccessful			= YES;
	
	[[CollectionManager manager] beginUpdate];
	
	while((filename = [filesEnumerator nextObject])) {
		
		// Perform a deep search for directories
		if([fileManager fileExistsAtPath:filename isDirectory:&isDirectory] && isDirectory) {
			directoryEnumerator	= [fileManager enumeratorAtPath:filename];
			
			while((path = [directoryEnumerator nextObject])) {
				openSuccessful &= [self addFile:[filename stringByAppendingPathComponent:path]];
				
				if(NULL != modalSession && NSRunContinuesResponse != [[NSApplication sharedApplication] runModalSession:modalSession]) {
					break;
				}				
			}
		}
		else {
			openSuccessful = [self addFile:filename];
			
			if(NULL != modalSession && NSRunContinuesResponse != [[NSApplication sharedApplication] runModalSession:modalSession]) {
				break;
			}				
		}
	}
	
	[[CollectionManager manager] finishUpdate];
	
	return openSuccessful;
}

- (BOOL) removeFile:(NSString *)filename
{
	NSParameterAssert(nil != filename);
	
	// If the stream doesn't exist in the library, do nothing
	AudioStream *stream = [[[CollectionManager manager] streamManager] streamForURL:[NSURL fileURLWithPath:filename]];
	if(nil == stream) {
		return YES;
	}
	
	// Otherwise, remove it
	if([stream isPlaying]) {
		[self stop:self];
	}
	
	[[[CollectionManager manager] streamManager] deleteStream:stream];
	
	return YES;
}

- (BOOL) removeFiles:(NSArray *)filenames
{
	NSParameterAssert(nil != filenames);
	
	NSString				*filename				= nil;
	NSString				*path					= nil;
	NSFileManager			*fileManager			= [NSFileManager defaultManager];
	NSEnumerator			*filesEnumerator		= [filenames objectEnumerator];
	NSDirectoryEnumerator	*directoryEnumerator	= nil;
	BOOL					isDirectory				= NO;
	BOOL					removeSuccessful		= YES;
	
	[[CollectionManager manager] beginUpdate];
	
	while((filename = [filesEnumerator nextObject])) {
		
		// Perform a deep search for directories
		if([fileManager fileExistsAtPath:filename isDirectory:&isDirectory] && isDirectory) {
			directoryEnumerator	= [fileManager enumeratorAtPath:filename];
			
			while((path = [directoryEnumerator nextObject])) {
				removeSuccessful &= [self removeFile:[filename stringByAppendingPathComponent:path]];
			}
		}
		else {
			removeSuccessful = [self removeFile:filename];
		}
	}
	
	[[CollectionManager manager] finishUpdate];
	
	return removeSuccessful;
}

#pragma mark Playlist manipulation

- (IBAction) insertPlaylist:(id)sender
{
	NSDictionary *initialValues = [NSDictionary dictionaryWithObject:NSLocalizedStringFromTable(@"Untitled Playlist", @"General", @"") forKey:PlaylistNameKey];
	Playlist *playlist = [Playlist insertPlaylistWithInitialValues:initialValues];
	if(nil != playlist) {
		[_browserDrawer open:self];
		
//		NSIndexPath *path = [_browserController selectionIndexPath];
//		NSLog(@"path=%@",path);
		
//		if(nil != path && [_browserController setSelectionIndexPath:path]) {
//			[_browserOutlineView editColumn:0 row:[_playlistTable selectedRow] withEvent:nil select:YES];	
//		}
	}
	else {
		NSBeep();
		NSLog(@"Unable to create the playlist.");
	}
}

- (IBAction) insertSmartPlaylist:(id)sender
{
	NSDictionary *initialValues = [NSDictionary dictionaryWithObject:NSLocalizedStringFromTable(@"Untitled Smart Playlist", @"General", @"") forKey:PlaylistNameKey];
	SmartPlaylist *playlist = [SmartPlaylist insertSmartPlaylistWithInitialValues:initialValues];
	if(nil != playlist) {
		[_browserDrawer open:self];
		
//		NSIndexPath *path = [_browserController selectionIndexPath];
//		NSLog(@"path=%@",path);
		
		//		if(nil != path && [_browserController setSelectionIndexPath:path]) {
		//			[_browserOutlineView editColumn:0 row:[_playlistTable selectedRow] withEvent:nil select:YES];	
		//		}
	}
	else {
		NSBeep();
		NSLog(@"Unable to create the smart playlist.");
	}
}

- (IBAction) insertWatchFolder:(id)sender
{
	NewWatchFolderSheet *newWatchFolderSheet = [[NewWatchFolderSheet alloc] init];

	[newWatchFolderSheet setValue:self forKey:@"owner"];
	
	[[NSApplication sharedApplication] beginSheet:[newWatchFolderSheet sheet] 
								   modalForWindow:[self window] 
									modalDelegate:self 
								   didEndSelector:@selector(showNewWatchFolderSheetDidEnd:returnCode:contextInfo:) 
									  contextInfo:newWatchFolderSheet];
}

#pragma mark Playback Control

- (BOOL) playFile:(NSString *)filename
{
	NSParameterAssert(nil != filename);
	
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
		if([[self player] isPlaying]) {
			[self stop:self];
		}
		[self setPlayQueueFromArray:[NSArray arrayWithObject:stream]];
		[self playStreamAtIndex:0];
	}
	
	return success;
}

- (BOOL) playFiles:(NSArray *)filenames
{
	NSParameterAssert(nil != filenames);

	BOOL			success			= YES;
	NSEnumerator	*enumerator		= [filenames objectEnumerator];
	NSString		*filename		= nil;
	AudioStream		*stream			= nil;
	NSMutableArray	*streams		= [NSMutableArray array];
	
	// First try to find these files in our library
	while(success && (filename = [enumerator nextObject])) {
		stream = [[[CollectionManager manager] streamManager] streamForURL:[NSURL fileURLWithPath:filename]];
		
		// If it wasn't found, try and add it
		if(nil == stream) {
			success &= [self addFile:filename];
			if(success) {
				stream = [[[CollectionManager manager] streamManager] streamForURL:[NSURL fileURLWithPath:filename]];
			}
		}

		if(nil != stream) {
			[streams addObject:stream];
		}
	}

	// Replace current streams with the files, and play the first one
	if(nil != stream) {
		if([[self player] isPlaying]) {
			[self stop:self];
		}
		[self setPlayQueueFromArray:streams];
		[self playStreamAtIndex:0];

		[self scrollNowPlayingToVisible];		
	}
	
	return success;
}

- (IBAction) play:(id)sender
{
	if(NO == [self playButtonEnabled]) {
		NSBeep();
		return;
	}
	
	if(NO == [[self player] hasValidStream]) {
		if([self randomPlayback]) {
			NSArray		*streams			= (1 < [[_streamController selectedObjects] count] ? [_streamController selectedObjects] : [_streamController arrangedObjects]);
			double		randomNumber		= genrand_real2();
			unsigned	randomIndex			= (unsigned)(randomNumber * [streams count]);
			
			[self setPlayQueueFromArray:streams];
			[self playStreamAtIndex:randomIndex];
		}
		else if(0 != [self countOfPlayQueue]) {
			[self playStreamAtIndex:0];
		}
		else {
			[_streamTable addToPlayQueue:sender];
			[self playStreamAtIndex:0];
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
	if(NO == [self playButtonEnabled]) {
		NSBeep();
		return;
	}
	
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

- (IBAction) stop:(id)sender
{
	AudioStream *stream = [self nowPlaying];

	[self setPlaybackIndex:NSNotFound];
	[self setNextPlaybackIndex:NSNotFound];

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
	
	[stream setPlaying:NO];
	
	NSArray *streams = _playQueue;
	
	if(nil == stream || 0 == [streams count]) {
		[[self player] reset];
		[self setPlaybackIndex:NSNotFound];
		[self updatePlayButtonState];
	}
	else if([self randomPlayback]) {
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
			[self setPlaybackIndex:NSNotFound];
			[self setPlayQueueFromArray:nil];
			[self updatePlayButtonState];
		}
	}
}

- (IBAction) playPreviousStream:(id)sender
{
	AudioStream		*stream			= [self nowPlaying];
	unsigned		streamIndex;
	
	[stream setPlaying:NO];
	
	NSArray *streams = _playQueue;
	
	if(nil == stream || 0 == [streams count]) {
		[[self player] reset];	
		[self setPlaybackIndex:NSNotFound];
	}
	else if([self randomPlayback]) {
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
			[self setPlaybackIndex:NSNotFound];
		}
	}
}

- (void) playStreamAtIndex:(unsigned)index
{
	NSParameterAssert([self countOfPlayQueue] > index);
	
	AudioStream *currentStream = [self nowPlaying];
	
	[[self player] stop];
	
	if(nil != currentStream) {
		[currentStream setPlaying:NO];
	}
	
	[_playQueueTable setNeedsDisplayInRect:[_playQueueTable rectOfRow:[self playbackIndex]]];
	
	[self setPlaybackIndex:index];
	[self setNextPlaybackIndex:NSNotFound];
	
	[_playQueueTable setNeedsDisplayInRect:[_playQueueTable rectOfRow:[self playbackIndex]]];
	
	AudioStream		*stream		= [self objectInPlayQueueAtIndex:[self playbackIndex]];
	NSError			*error		= nil;
	BOOL			result		= [[self player] setStream:stream error:&error];
	
	if(NO == result) {
		/*BOOL errorRecoveryDone =*/ [self presentError:error];
		return;
	}
	
	[self updatePlayQueueHistory];
	
	// Rescan metadata, if desired
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"rescanMetadataBeforePlayback"]) {
		[[CollectionManager manager] beginUpdate];
		[stream rescanMetadata:self];
		[[CollectionManager manager] finishUpdate];
	}
	
	[stream setPlaying:YES];
	
	/*	if(nil == [stream valueForKey:@"albumArt"]) {
		[_albumArtImageView setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
	}*/
	
	[[self player] play];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidStartNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
	
	[self updatePlayButtonState];
}

#pragma mark Play Queue management

- (unsigned) countOfPlayQueue
{
	return [_playQueue count];
}

- (AudioStream *) objectInPlayQueueAtIndex:(unsigned)index
{
	return [_playQueue objectAtIndex:index];
}

- (void) getPlayQueue:(id *)buffer range:(NSRange)aRange
{
	return [_playQueue getObjects:buffer range:aRange];
}

- (void) insertObject:(AudioStream *)stream inPlayQueueAtIndex:(unsigned)index
{
	[_playQueue insertObject:stream atIndex:index];	

	if(NSNotFound != [self playbackIndex] && index <= [self playbackIndex]) {
		[self setPlaybackIndex:[self playbackIndex] + 1];
	}
	
	[self updatePlayButtonState];
}

- (void) removeObjectFromPlayQueueAtIndex:(unsigned)index
{
	[_playQueue removeObjectAtIndex:index];	

	if(NSNotFound != [self playbackIndex] && index < [self playbackIndex]) {
		[self setPlaybackIndex:[self playbackIndex] - 1];
	}

	[self updatePlayButtonState];
}

- (void) addStreamsToPlayQueue:(NSArray *)streams
{
	NSParameterAssert(nil != streams);
	
	NSEnumerator	*enumerator		= [streams objectEnumerator];
	AudioStream		*stream			= nil;
	
	[self willChangeValueForKey:PlayQueueKey];
	while((stream = [enumerator nextObject])) {
		[_playQueue addObject:stream];
	}
	[self didChangeValueForKey:PlayQueueKey];
	
	[self updatePlayButtonState];
}

#pragma mark Browser support

- (BOOL) selectLibraryNode
{
	return [_browserController setSelectionIndexPath:[_browserController arrangedIndexPathForObject:_libraryNode]];
}

#pragma mark Properties

- (BOOL)		randomPlayback										{ return _randomPlayback; }
- (void)		setRandomPlayback:(BOOL)randomPlayback				{ _randomPlayback = randomPlayback; }

- (BOOL)		loopPlayback										{ return _loopPlayback; }
- (void)		setLoopPlayback:(BOOL)loopPlayback					{ _loopPlayback = loopPlayback; }

- (BOOL)		playButtonEnabled									{ return _playButtonEnabled; }

- (BOOL) canPlayNextStream
{
	NSArray		*streams	= _playQueue;
	BOOL		result		= NO;
	
	if(NSNotFound == [self playbackIndex] || 0 == [streams count]) {
		result = NO;
	}
	else if([self randomPlayback]) {
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
	NSArray		*streams	= _playQueue;
	BOOL		result		= NO;
	
	if(NSNotFound == [self playbackIndex] || 0 == [streams count]) {
		result = NO;
	}
	else if([self randomPlayback]) {
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
	unsigned index = [self playbackIndex];
	return (NSNotFound == index ? nil : [self objectInPlayQueueAtIndex:index]);
}

- (NSUndoManager *) undoManager
{
	return [[CollectionManager manager] undoManager];
}

- (BOOL) streamsAreOrdered
{
	return _streamsAreOrdered;
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

- (void) tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if(tableView == _playQueueTable) {
		NSDictionary *infoForBinding = [tableView infoForBinding:NSContentBinding];
		
		if(nil != infoForBinding) {
			NSArrayController	*arrayController	= [infoForBinding objectForKey:NSObservedObjectKey];
			AudioStream			*stream				= [[arrayController arrangedObjects] objectAtIndex:rowIndex];
			BOOL				highlight			= ([stream isPlaying] && rowIndex == (int)[self playbackIndex]);
			
			// Icon for now playing
			if([[aTableColumn identifier] isEqual:@"nowPlaying"]) {
				[cell setImage:(highlight ? [NSImage imageNamed:@"artsenvironment"] : nil)];
			}
			
			// Bold/unbold cell font as required
			NSFont *font = [cell font];
			font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:(highlight ? NSBoldFontMask : NSUnboldFontMask)];
			[cell setFont:font];
		}
	}
}

- (void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
	if([aNotification object] == _streamTable) {
		[self updatePlayButtonState];
	}
}

- (void) tableViewColumnDidMove:(NSNotification *)aNotification
{
	if([aNotification object] == _streamTable) {
		[self saveStreamTableColumnOrder];
	}
	else if([aNotification object] == _playQueueTable) {
		[self savePlayQueueTableColumnOrder];
	}
}

- (void) tableViewColumnDidResize:(NSNotification *)aNotification
{
	if([aNotification object] == _streamTable) {
		NSMutableDictionary		*sizes			= [NSMutableDictionary dictionary];
		NSEnumerator			*enumerator		= [[_streamTable tableColumns] objectEnumerator];
		id						column;
		
		while((column = [enumerator nextObject])) {
			[sizes setObject:[NSNumber numberWithFloat:[column width]] forKey:[column identifier]];
		}
		
		[[NSUserDefaults standardUserDefaults] setObject:sizes forKey:@"streamTableColumnSizes"];
	}
	else if([aNotification object] == _playQueueTable) {
		NSMutableDictionary		*sizes			= [NSMutableDictionary dictionary];
		NSEnumerator			*enumerator		= [[_playQueueTable tableColumns] objectEnumerator];
		id						column;
		
		while((column = [enumerator nextObject])) {
			[sizes setObject:[NSNumber numberWithFloat:[column width]] forKey:[column identifier]];
		}
		
		[[NSUserDefaults standardUserDefaults] setObject:sizes forKey:@"playQueueTableColumnSizes"];
	}
}

/*- (void) configureTypeSelectTableView:(KFTypeSelectTableView *)tableView
{
    [tableView setSearchWraps:YES];
}

- (int) typeSelectTableViewInitialSearchRow:(id)tableView
{
	return [tableView selectedRow];
}

- (NSString *) typeSelectTableView:(id)tableView stringValueForTableColumn:(NSTableColumn *)column row:(int)row
{
	return [[[_streamController arrangedObjects] objectAtIndex:row] valueForKey:[column identifier]];
}*/

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

	// If the row is selected but isn't being edited and the current drawing isn't being used to create a drag image,
	// colour the text white; otherwise, colour it black
	int rowIndex = [outlineView rowForItem:item];
	NSColor *fontColor = ([[outlineView selectedRowIndexes] containsIndex:rowIndex] && [outlineView editedRow] != rowIndex) ? [NSColor whiteColor] : [NSColor blackColor];
	[cell setTextColor:fontColor];
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
	[_streamController setFilterPredicate:nil];
	
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
				if([newStreamsNode streamsAreOrdered]) {
					[_streamTableSavedSortDescriptors release], _streamTableSavedSortDescriptors = nil;
					_streamTableSavedSortDescriptors = [[_streamController sortDescriptors] retain];
					[_streamController setSortDescriptors:nil];
				}
			}
			
			[_streamController bind:@"contentArray" toObject:newStreamsNode withKeyPath:@"streams" options:nil];
			[_streamController setSelectedObjects:selected];

			// Save stream ordering for drag validation
			_streamsAreOrdered = [newStreamsNode streamsAreOrdered];
		}
	}
	else if([[oldStreamsNode exposedBindings] containsObject:@"streams"] && NO == [oldStreamsNode streamsAreOrdered]) {
		[_streamTableSavedSortDescriptors release], _streamTableSavedSortDescriptors = nil;
		_streamTableSavedSortDescriptors = [[_streamController sortDescriptors] retain];
		[_streamController setSortDescriptors:nil];
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
		
		[panel close];

		FileAdditionProgressSheet *progressSheet = [[FileAdditionProgressSheet alloc] init];
				
		[[NSApplication sharedApplication] beginSheet:[progressSheet sheet]
									   modalForWindow:[self window]
										modalDelegate:nil
									   didEndSelector:nil
										  contextInfo:nil];
		
		NSModalSession modalSession = [[NSApplication sharedApplication] beginModalSessionForWindow:[progressSheet sheet]];
		
		[progressSheet startProgressIndicator:self];
		[self addFiles:[panel filenames] inModalSession:modalSession];
		[progressSheet stopProgressIndicator:self];
		
		[NSApp endModalSession:modalSession];

		[NSApp endSheet:[progressSheet sheet]];
		[[progressSheet sheet] close];
		[progressSheet release];

#if SQL_DEBUG
		clock_t end = clock();
		unsigned endCount = [[_streamController arrangedObjects] count];
		unsigned filesAdded = endCount - startCount;
		double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
		NSLog(@"Added %i files in %f seconds (%f files per second)", filesAdded, elapsed, (double)filesAdded / elapsed);
#endif
		
		[_streamController rearrangeObjects];
	}
}

- (void) showNewWatchFolderSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NewWatchFolderSheet *newWatchFolderSheet = (NewWatchFolderSheet *)contextInfo;
	
	[sheet orderOut:self];
	
	if(NSOKButton == returnCode) {
		NSDictionary *initialValues = [NSDictionary dictionaryWithObjectsAndKeys:
								 [newWatchFolderSheet valueForKey:@"url"], WatchFolderURLKey,
								 [newWatchFolderSheet valueForKey:@"name"], WatchFolderNameKey,
			nil];
		
		WatchFolder *watchFolder = [WatchFolder insertWatchFolderWithInitialValues:initialValues];

		if(nil != watchFolder) {
		}
		else {
			NSBeep();
			NSLog(@"Unable to create the watch folder.");
		}
	}
	
	[newWatchFolderSheet release];
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

@implementation AudioLibrary (AudioPlayerCallbackMethods)

- (void) streamPlaybackDidStart
{
	[self setPlaybackIndex:[self nextPlaybackIndex]];
	[self setNextPlaybackIndex:NSNotFound];
	
	[_playQueueTable setNeedsDisplayInRect:[_playQueueTable rectOfRow:[self playbackIndex]]];
	
	[self updatePlayQueueHistory];
	
	AudioStream *stream = [self objectInPlayQueueAtIndex:[self playbackIndex]];
	NSAssert(nil != stream, @"Playback started for stream index not in playback context.");
	
	[stream setPlaying:YES];
	
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
	
	[_playQueueTable setNeedsDisplayInRect:[_playQueueTable rectOfRow:[self playbackIndex]]];
	
	[self setPlaybackIndex:NSNotFound];
	
	// If the player isn't playing, it could be because the streams have different PCM formats
	if(NO == [[self player] isPlaying]) {
		
		// Next stream was requested by player, but the PCM format differs so gapless playback was impossible
		if(NSNotFound != [self nextPlaybackIndex]) {
			[self playStreamAtIndex:[self nextPlaybackIndex]];
		}
		// Otherwise stop
		else {
			[[self player] reset];
			[self updatePlayButtonState];
		}
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidCompleteNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
}

- (void) requestNextStream
{
	AudioStream		*stream			= [self nowPlaying];
	unsigned		streamIndex;
	
	NSArray *streams = _playQueue;
	
	if(nil == stream || 0 == [streams count]) {
		[self setNextPlaybackIndex:NSNotFound];
	}
	else if([self randomPlayback]) {
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
	NSLog(@"requestNextStream:%@", [self objectInPlayQueueAtIndex:[self nextPlaybackIndex]]);
#endif
	
	if(NSNotFound != [self nextPlaybackIndex]) {
		NSError		*error		= nil;
		BOOL		result		= [[self player] setNextStream:[self objectInPlayQueueAtIndex:[self nextPlaybackIndex]] error:&error];
		
		if(NO == result) {
			if(nil != error) {
				[self presentError:error];
			}
		}
	}
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
	[_playQueueTable scrollRowToVisible:[self playbackIndex]];
}

- (void)		setPlayButtonEnabled:(BOOL)playButtonEnabled		{ _playButtonEnabled = playButtonEnabled; }

- (unsigned)	playbackIndex										{ return _playbackIndex; }

- (void) setPlaybackIndex:(unsigned)playbackIndex
{
	unsigned oldPlaybackIndex = _playbackIndex;
	
	_playbackIndex = playbackIndex;
	
	if(NSNotFound != [self playbackIndex]) {
		[_playQueueTable setHighlightedRow:_playbackIndex];
		[_playQueueTable setNeedsDisplayInRect:[_playQueueTable rectOfRow:[self playbackIndex]]];
	}
	else {
		[_playQueueTable setHighlightedRow:-1];
	}

	[_playQueueTable setNeedsDisplayInRect:[_playQueueTable rectOfRow:oldPlaybackIndex]];
}

- (unsigned)	nextPlaybackIndex									{ return _nextPlaybackIndex; }
- (void)		setNextPlaybackIndex:(unsigned)nextPlaybackIndex	{ _nextPlaybackIndex = nextPlaybackIndex; }

- (void) setPlayQueueFromArray:(NSArray *)streams
{
	[self willChangeValueForKey:PlayQueueKey];	
	[_playQueue removeAllObjects];
	[_playQueue addObjectsFromArray:streams];
	[self didChangeValueForKey:PlayQueueKey];
}

- (void) addRandomStreamsFromLibraryToPlayQueue:(unsigned)count
{
	NSArray			*streams		= [[[CollectionManager manager] streamManager] streams];
	double			randomNumber;
	unsigned		randomIndex;
	unsigned		i;
	
	[self willChangeValueForKey:PlayQueueKey];
	for(i = 0; i < count; ++i) {
		randomNumber	= genrand_real2();
		randomIndex		= (unsigned)(randomNumber * [streams count]);
		[_playQueue addObject:[streams objectAtIndex:randomIndex]];
	}
	[self didChangeValueForKey:PlayQueueKey];
	
	[self updatePlayButtonState];
}

- (void) updatePlayQueueHistory
{
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"limitPlayQueueHistorySize"] && NO == [self randomPlayback]) {
		unsigned playQueueHistorySize	= [[NSUserDefaults standardUserDefaults] integerForKey:@"playQueueHistorySize"];
		unsigned index					= [self playbackIndex];
		
		[self willChangeValueForKey:PlayQueueKey];
		while(index > playQueueHistorySize) {
			[_playQueue removeObjectAtIndex:0];
			--index;
		}
		[self didChangeValueForKey:PlayQueueKey];

		[self setPlaybackIndex:index];
	}
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
		
		[self setPlayButtonEnabled:(0 != [self countOfPlayQueue] || 0 != [[_streamController selectedObjects] count])];
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
	
/*	IconFamily	*cdIconFamily		= [IconFamily iconFamilyWithSystemIcon:kGenericCDROMIcon];
	NSImage		*cdIcon				= [cdIconFamily imageWithAllReps];

	[cdIcon setSize:NSMakeSize(16.0, 16.0)];*/

	BrowserNode *browserRoot = [[BrowserNode alloc] initWithName:NSLocalizedStringFromTable(@"Collection", @"General", @"")];
	[browserRoot setIcon:folderIcon];
	
	_libraryNode = [[LibraryNode alloc] init];
//	[_libraryNode setIcon:cdIcon];

	ArtistsNode *artistsNode = [[ArtistsNode alloc] init];
	[artistsNode setIcon:folderIcon];

	AlbumsNode *albumsNode = [[AlbumsNode alloc] init];
	[albumsNode setIcon:folderIcon];

	GenresNode *genresNode = [[GenresNode alloc] init];
	[genresNode setIcon:folderIcon];

	PlaylistsNode *playlistsNode = [[PlaylistsNode alloc] init];
	[playlistsNode setIcon:folderIcon];

	SmartPlaylistsNode *smartPlaylistsNode = [[SmartPlaylistsNode alloc] init];
	[smartPlaylistsNode setIcon:folderIcon];

	WatchFoldersNode *watchFoldersNode = [[WatchFoldersNode alloc] init];
	[watchFoldersNode setIcon:folderIcon];

	MostPopularNode *mostPopularNode = [[MostPopularNode alloc] init];
	RecentlyAddedNode *recentlyAddedNode = [[RecentlyAddedNode alloc] init];
	RecentlyPlayedNode *recentlyPlayedNode = [[RecentlyPlayedNode alloc] init];
	
	[browserRoot addChild:_libraryNode];
	[browserRoot addChild:[mostPopularNode autorelease]];
	[browserRoot addChild:[recentlyAddedNode autorelease]];
	[browserRoot addChild:[recentlyPlayedNode autorelease]];
	[browserRoot addChild:[artistsNode autorelease]];
	[browserRoot addChild:[albumsNode autorelease]];
	[browserRoot addChild:[genresNode autorelease]];
	[browserRoot addChild:[playlistsNode autorelease]];
	[browserRoot addChild:[smartPlaylistsNode autorelease]];
	[browserRoot addChild:[watchFoldersNode autorelease]];

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

- (void) setupStreamTableColumns
{
	NSMenuItem		*contextMenuItem;	
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

- (void) setupPlayQueueTableColumns
{
	NSMenuItem		*contextMenuItem;	
	id				obj;
	int				menuIndex, i;
	
	// Setup stream table columns
	NSDictionary	*visibleDictionary	= [[NSUserDefaults standardUserDefaults] objectForKey:@"playQueueTableColumnVisibility"];
	NSDictionary	*sizesDictionary	= [[NSUserDefaults standardUserDefaults] objectForKey:@"playQueueTableColumnSizes"];
	NSArray			*orderArray			= [[NSUserDefaults standardUserDefaults] objectForKey:@"playQueueTableColumnOrder"];
	
	NSArray			*tableColumns		= [_playQueueTable tableColumns];
	NSEnumerator	*enumerator			= [tableColumns objectEnumerator];
	
	_playQueueTableVisibleColumns		= [[NSMutableSet alloc] init];
	_playQueueTableHiddenColumns		= [[NSMutableSet alloc] init];
	_playQueueTableHeaderContextMenu	= [[NSMenu alloc] initWithTitle:@"Play Queue Table Header Context Menu"];
	
	[[_playQueueTable headerView] setMenu:_playQueueTableHeaderContextMenu];
	
	// Keep our changes from generating notifications to ourselves
	[_playQueueTable setDelegate:nil];
	
	while((obj = [enumerator nextObject])) {
		menuIndex = 0;
		
		while(menuIndex < [_playQueueTableHeaderContextMenu numberOfItems] 
			  && NSOrderedDescending == [[[obj headerCell] title] localizedCompare:[[_playQueueTableHeaderContextMenu itemAtIndex:menuIndex] title]]) {
			menuIndex++;
		}
		
		contextMenuItem = [_playQueueTableHeaderContextMenu insertItemWithTitle:[[obj headerCell] title] action:@selector(playQueueTableHeaderContextMenuSelected:) keyEquivalent:@"" atIndex:menuIndex];
		
		[contextMenuItem setTarget:self];
		[contextMenuItem setRepresentedObject:obj];
		[contextMenuItem setState:([[visibleDictionary objectForKey:[obj identifier]] boolValue] ? NSOnState : NSOffState)];
		
		//		NSLog(@"setting width of %@ to %f", [obj identifier], [[sizesDictionary objectForKey:[obj identifier]] floatValue]);
		[obj setWidth:[[sizesDictionary objectForKey:[obj identifier]] floatValue]];
		
		if([[visibleDictionary objectForKey:[obj identifier]] boolValue]) {
			[_playQueueTableVisibleColumns addObject:obj];
		}
		else {
			[_playQueueTableHiddenColumns addObject:obj];
			[_playQueueTable removeTableColumn:obj];
		}
	}
	
	i = 0;
	enumerator = [orderArray objectEnumerator];
	while((obj = [enumerator nextObject])) {
		[_playQueueTable moveColumn:[_playQueueTable columnWithIdentifier:obj] toColumn:i];
		++i;
	}
	
	[_playQueueTable setDelegate:self];
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

- (void) savePlayQueueTableColumnOrder
{
	NSMutableArray	*identifiers	= [NSMutableArray array];
	NSEnumerator	*enumerator		= [[_playQueueTable tableColumns] objectEnumerator];
	id				obj;
	
	while((obj = [enumerator nextObject])) {
		[identifiers addObject:[obj identifier]];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:identifiers forKey:@"playQueueTableColumnOrder"];
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

- (IBAction) playQueueTableHeaderContextMenuSelected:(id)sender
{
	if(NSOnState == [sender state]) {
		[sender setState:NSOffState];
		[_playQueueTableHiddenColumns addObject:[sender representedObject]];
		[_playQueueTableVisibleColumns removeObject:[sender representedObject]];
		[_playQueueTable removeTableColumn:[sender representedObject]];
	}
	else {
		[sender setState:NSOnState];
		[_playQueueTable addTableColumn:[sender representedObject]];
		[_playQueueTableVisibleColumns addObject:[sender representedObject]];
		[_playQueueTableHiddenColumns removeObject:[sender representedObject]];
	}
	
	NSMutableDictionary	*visibleDictionary	= [NSMutableDictionary dictionary];
	NSEnumerator		*enumerator			= [_playQueueTableVisibleColumns objectEnumerator];
	id					obj;
	
	while((obj = [enumerator nextObject])) {
		[visibleDictionary setObject:[NSNumber numberWithBool:YES] forKey:[obj identifier]];
	}
	
	enumerator = [_playQueueTableHiddenColumns objectEnumerator];
	while((obj = [enumerator nextObject])) {
		[visibleDictionary setObject:[NSNumber numberWithBool:NO] forKey:[obj identifier]];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:visibleDictionary forKey:@"playQueueTableColumnVisibility"];
	
	[self saveStreamTableColumnOrder];
}

#pragma mark Bogosity

// These methods do nothing- for some reason, they are necessary to get the menu items to auto enable
// (bindings won't work for some reason)
- (IBAction) toggleRandomPlayback:(id)sender
{}

- (IBAction) toggleLoopPlayback:(id)sender
{}

#pragma mark Notifications

- (void) streamAdded:(NSNotification *)aNotification
{
	[self updatePlayButtonState];
}

- (void) streamsAdded:(NSNotification *)aNotification
{
	[self updatePlayButtonState];
}

- (void) streamRemoved:(NSNotification *)aNotification
{
	AudioStream				*stream			= [[aNotification userInfo] objectForKey:AudioStreamObjectKey];

	[self willChangeValueForKey:PlayQueueKey];
	[_playQueue removeObject:stream];
	[self didChangeValueForKey:PlayQueueKey];

	[self updatePlayButtonState];
}

- (void) streamsRemoved:(NSNotification *)aNotification
{
	NSArray					*streams		= [[aNotification userInfo] objectForKey:AudioStreamsObjectKey];
	NSEnumerator			*enumerator		= [streams objectEnumerator];
	AudioStream				*stream			= nil;
	
	[self willChangeValueForKey:PlayQueueKey];
	while((stream = [enumerator nextObject])) {
		[_playQueue removeObject:stream];
	}
	[self didChangeValueForKey:PlayQueueKey];

	[self updatePlayButtonState];
}

@end
