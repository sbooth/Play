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
#import "PlaylistManager.h"
#import "SmartPlaylistManager.h"
#import "WatchFolderManager.h"
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

#import "BrowserNode.h"
#import "AudioStreamCollectionNode.h"
#import "LibraryNode.h"
#import "ArtistsNode.h"
#import "AlbumsNode.h"
#import "GenresNode.h"
#import "ComposersNode.h"
#import "PlaylistsNode.h"
#import "PlaylistNode.h"
#import "SmartPlaylistsNode.h"
#import "SmartPlaylistNode.h"
#import "WatchFoldersNode.h"
#import "WatchFolderNode.h"
#import "MostPopularNode.h"
#import "HighestRatedNode.h"
#import "RecentlyAddedNode.h"
#import "RecentlyPlayedNode.h"
#import "RecentlySkippedNode.h"

#import "UtilityFunctions.h"
#import "CueSheetParser.h"

#import "IconFamily.h"
#import "ImageAndTextCell.h"

#include "SFMT.h"

#import "RBSplitView/RBSplitView.h"

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
NSString * const	AudioStreamPlaybackWasSkippedNotification	= @"org.sbooth.Play.AudioLibrary.AudioStreamPlaybackWasSkippedNotification";

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
// Toolbar item identifiers
// ========================================
static NSString * const AudioLibraryToolbarIdentifier			= @"org.sbooth.Play.Library.Toolbar";
static NSString * const PlayerControlsToolbarItemIdentifier		= @"org.sbooth.Play.Library.Toolbar.PlayerControls";
static NSString * const PlaybackOrderControlsToolbarItemIdentifier = @"org.sbooth.Play.Library.Toolbar.PlaybackOrderControls";
static NSString * const VolumeControlToolbarItemIdentifier		= @"org.sbooth.Play.Library.Toolbar.VolumeControl";
static NSString * const SearchFieldToolbarItemIdentifier		= @"org.sbooth.Play.Library.Toolbar.SearchField";

// ========================================
// Definitions
// ========================================
#define VIEW_MENU_INDEX								5
#define PLAY_QUEUE_TABLE_COLUMNS_MENU_ITEM_INDEX	5
#define STREAM_TABLE_COLUMNS_MENU_ITEM_INDEX		6

//#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_4
// ========================================
// Completely bogus NSTreeController bindings hack (unnecessary on 10.5)
// ========================================
@interface NSObject (NSTreeControllerBogosity)
- (id) observedObject;
@end
//#endif

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
- (void) scrollNowPlayingToVisible;

- (void) setPlayButtonEnabled:(BOOL)playButtonEnabled;

- (unsigned) playbackIndex;
- (void) setPlaybackIndex:(unsigned)playbackIndex;

- (unsigned) nextPlaybackIndex;
- (void) setNextPlaybackIndex:(unsigned)nextPlaybackIndex;

- (void) setPlayQueueFromArray:(NSArray *)streams;

- (void) addRandomTracksFromLibraryToPlayQueue:(unsigned)count;

- (BOOL) addStreamsFromExternalCueSheet:(NSString *)filename;

- (void) updatePlayQueueHistory;

- (void) updatePlayButtonState;

- (void) setupToolbar;
- (void) setupBrowser;

- (void) saveBrowserStateToDefaults;
- (void) restoreBrowserStateFromDefaults;
- (BOOL) selectBrowserNode:(BrowserNode *)node;

- (void) setupStreamTableColumns;
- (void) setupPlayQueueTableColumns;

- (void) scanWatchFolders;
- (void) synchronizeWithWatchFolder:(WatchFolder *)watchFolder;

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

- (void) watchFolderAdded:(NSNotification *)aNotification;
- (void) watchFolderChanged:(NSNotification *)aNotification;

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
	//[self exposeBinding:@"isPlaying"];
	//[self exposeBinding:@"volume"];
	
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
		[NSNumber numberWithBool:YES], @"formatDescription",
		[NSNumber numberWithBool:NO], @"composer",
		[NSNumber numberWithBool:YES], @"duration",
		[NSNumber numberWithBool:NO], @"dateAdded",
		[NSNumber numberWithBool:NO], @"playCount",
		[NSNumber numberWithBool:NO], @"lastPlayed",
		[NSNumber numberWithBool:NO], @"skipCount",
		[NSNumber numberWithBool:NO], @"lastSkipped",
		[NSNumber numberWithBool:NO], @"date",
		[NSNumber numberWithBool:NO], @"compilation",
		[NSNumber numberWithBool:NO], @"filename",
		[NSNumber numberWithBool:NO], @"rating",
		[NSNumber numberWithBool:NO], @"bpm",
		[NSNumber numberWithBool:NO], @"bitrate",
		nil];
	
	NSDictionary *streamTableColumnSizesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithFloat:72], @"id",
		[NSNumber numberWithFloat:192], @"title",
		[NSNumber numberWithFloat:128], @"albumTitle",
		[NSNumber numberWithFloat:128], @"artist",
		[NSNumber numberWithFloat:128], @"albumArtist",
		[NSNumber numberWithFloat:64], @"genre",
		[NSNumber numberWithFloat:54], @"track",
		[NSNumber numberWithFloat:54], @"disc",
		[NSNumber numberWithFloat:76], @"formatDescription",
		[NSNumber numberWithFloat:128], @"composer",
		[NSNumber numberWithFloat:74], @"duration",
		[NSNumber numberWithFloat:96], @"dateAdded",
		[NSNumber numberWithFloat:72], @"playCount",
		[NSNumber numberWithFloat:96], @"lastPlayed",
		[NSNumber numberWithFloat:72], @"skipCount",
		[NSNumber numberWithFloat:96], @"lastSkipped",
		[NSNumber numberWithFloat:50], @"date",
		[NSNumber numberWithFloat:70], @"compilation",
		[NSNumber numberWithFloat:64], @"filename",
		[NSNumber numberWithFloat:68], @"rating",
		[NSNumber numberWithFloat:72], @"bpm",
		[NSNumber numberWithFloat:72], @"bitrate",
		nil];
	
	NSDictionary *streamTableColumnOrderArray = [NSArray arrayWithObjects:
		@"title", @"artist", @"albumTitle", @"genre", @"track", @"formatDescription", nil];

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
		[NSNumber numberWithBool:YES], @"formatDescription",
		[NSNumber numberWithBool:NO], @"composer",
		[NSNumber numberWithBool:YES], @"duration",
		[NSNumber numberWithBool:NO], @"dateAdded",
		[NSNumber numberWithBool:NO], @"playCount",
		[NSNumber numberWithBool:NO], @"lastPlayed",
		[NSNumber numberWithBool:NO], @"skipCount",
		[NSNumber numberWithBool:NO], @"lastSkipped",
		[NSNumber numberWithBool:NO], @"date",
		[NSNumber numberWithBool:NO], @"compilation",
		[NSNumber numberWithBool:NO], @"filename",
		[NSNumber numberWithBool:NO], @"rating",
		[NSNumber numberWithBool:NO], @"bpm",
		[NSNumber numberWithBool:NO], @"bitrate",
		nil];
	
	NSDictionary *playQueueColumnSizesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithFloat:18], @"nowPlaying",
		[NSNumber numberWithFloat:72], @"id",
		[NSNumber numberWithFloat:192], @"title",
		[NSNumber numberWithFloat:128], @"albumTitle",
		[NSNumber numberWithFloat:128], @"artist",
		[NSNumber numberWithFloat:128], @"albumArtist",
		[NSNumber numberWithFloat:64], @"genre",
		[NSNumber numberWithFloat:54], @"track",
		[NSNumber numberWithFloat:54], @"disc",
		[NSNumber numberWithFloat:76], @"formatDescription",
		[NSNumber numberWithFloat:128], @"composer",
		[NSNumber numberWithFloat:74], @"duration",
		[NSNumber numberWithFloat:96], @"dateAdded",
		[NSNumber numberWithFloat:72], @"playCount",
		[NSNumber numberWithFloat:96], @"lastPlayed",
		[NSNumber numberWithFloat:72], @"skipCount",
		[NSNumber numberWithFloat:96], @"lastSkipped",
		[NSNumber numberWithFloat:50], @"date",
		[NSNumber numberWithFloat:70], @"compilation",
		[NSNumber numberWithFloat:64], @"filename",
		[NSNumber numberWithFloat:68], @"rating",
		[NSNumber numberWithFloat:72], @"bpm",
		[NSNumber numberWithFloat:72], @"bitrate",
		nil];
	
	NSDictionary *playQueueColumnOrderArray = [NSArray arrayWithObjects:
		@"nowPlaying", @"title", @"artist", @"albumTitle", @"genre", @"track", @"formatDescription", nil];
	
	NSDictionary *tableDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
		streamTableVisibleColumnsDictionary, @"streamTableColumnVisibility",
		streamTableColumnSizesDictionary, @"streamTableColumnSizes",
		streamTableColumnOrderArray, @"streamTableColumnOrder",
		playQueueVisibleColumnsDictionary, @"playQueueTableColumnVisibility",
		playQueueColumnSizesDictionary, @"playQueueTableColumnSizes",
		playQueueColumnOrderArray, @"playQueueTableColumnOrder",
		nil];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:tableDefaults];
}	

+ (AudioLibrary *) library
{
	@synchronized(self) {
		if(nil == libraryInstance)
			// assignment not done here
			[[self alloc] init];
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
		
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"useInMemoryDatabase"])
			[[CollectionManager manager] connectToDatabase:@":memory:" error:nil];
		else {
			NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
			NSAssert(nil != paths, NSLocalizedStringFromTable(@"Unable to locate the \"Application Support\" folder.", @"Errors", @""));
			
			NSString *applicationName			= [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
			NSString *applicationSupportFolder	= [[paths objectAtIndex:0] stringByAppendingPathComponent:applicationName];
			
			if(NO == [[NSFileManager defaultManager] fileExistsAtPath:applicationSupportFolder]) {
				BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:applicationSupportFolder attributes:nil];
				NSAssert(YES == success, NSLocalizedStringFromTable(@"Unable to create the \"Application Support\" folder.", @"Errors", @""));
			}
			
			NSString *databasePath = [applicationSupportFolder stringByAppendingPathComponent:@"Library.sqlite3"];

			NSError *error = nil;
			
			// Check if the database is current (if it exists) and if it isn't update
			if([[NSFileManager defaultManager] fileExistsAtPath:databasePath] && NO == [[CollectionManager manager] updateDatabaseIfNeeded:databasePath error:&error]) {
				if(nil != error)
					[[NSApplication sharedApplication] presentError:error];

				[self release];
				return nil;
			}
			
			if(NO == [[CollectionManager manager] connectToDatabase:databasePath error:&error]) {
				if(nil != error)
					[[NSApplication sharedApplication] presentError:error];
				
				[self release];
				return nil;
			}
		}
		
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

		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(watchFolderAdded:) 
													 name:WatchFolderAddedToLibraryNotification
												   object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(watchFolderChanged:) 
													 name:WatchFolderDidChangeNotification
												   object:nil];
	}
	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[[CollectionManager manager] disconnectFromDatabase:nil];

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
	[_artistsNode release], _artistsNode = nil;
	[_albumsNode release], _albumsNode = nil;
	[_composersNode release], _composersNode = nil;
	[_genresNode release], _genresNode = nil;
	[_mostPopularNode release], _mostPopularNode = nil;
	[_highestRatedNode release], _highestRatedNode = nil;
	[_recentlyAddedNode release], _recentlyAddedNode = nil;
	[_recentlyPlayedNode release], _recentlyPlayedNode = nil;
	[_recentlySkippedNode release], _recentlySkippedNode = nil;
	[_playlistsNode release], _playlistsNode = nil;
	[_smartPlaylistsNode release], _smartPlaylistsNode = nil;
	
	[super dealloc];
}

- (id) 			copyWithZone:(NSZone *)zone			{ return self; }
- (id) 			retain								{ return self; }
- (unsigned) 	retainCount							{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void) 		release								{ /* do nothing */ }
- (id) 			autorelease							{ return self; }

- (AudioPlayer *) player
{
	if(nil == _player) {
		_player = [[AudioPlayer alloc] init];
		[_player setOwner:self];
	}
	return [[_player retain] autorelease];
}

- (void) awakeFromNib
{
	[self setupToolbar];
	[self setupBrowser];
	
	[self restoreStateFromDefaults];
	
	[self updatePlayButtonState];
	
	[self setupStreamTableColumns];
	[self setupPlayQueueTableColumns];
	
	[self scanWatchFolders];
}

- (void) windowDidLoad
{
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Library"];
//	[[self window] setExcludedFromWindowsMenu:YES];
}

- (void) windowWillClose:(NSNotification *)aNotification
{
	if([[self player] hasValidStream])
		[self stop:self];
}

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if([menuItem action] == @selector(playPause:)) {
		[menuItem setTitle:([[self player] isPlaying] ? NSLocalizedStringFromTable(@"Pause", @"Menus", @"") : NSLocalizedStringFromTable(@"Play", @"Menus", @""))];
		return [self playButtonEnabled];
	}
	else if([menuItem action] == @selector(addFiles:))
		return [_streamController canAdd];
	else if([menuItem action] == @selector(skipForward:) 
			|| [menuItem action] == @selector(skipBackward:) 
			|| [menuItem action] == @selector(skipToEnd:) 
			|| [menuItem action] == @selector(skipToBeginning:)) {
		return [[self player] hasValidStream];
	}
	else if([menuItem action] == @selector(playNextStream:))
		return [self canPlayNextStream];
	else if([menuItem action] == @selector(playPreviousStream:))
		return [self canPlayPreviousStream];
	else if([menuItem action] == @selector(insertPlaylist:))
		return [_browserController canInsert];
	else if([menuItem action] == @selector(jumpToNowPlaying:))
		return (nil != [self nowPlaying] && 0 != [self countOfPlayQueue]);
	else if([menuItem action] == @selector(undo:))
		return [[self undoManager] canUndo];
	else if([menuItem action] == @selector(redo:))
		return [[self undoManager] canRedo];
	else if([menuItem action] == @selector(add10RandomTracksToPlayQueue:) || [menuItem action] == @selector(add25RandomTracksToPlayQueue:))
		return (0 != [[[[CollectionManager manager] streamManager] streams] count]);
	else if([menuItem action] == @selector(toggleRandomPlayback:))
		return (0 != [self countOfPlayQueue] && NO == [self loopPlayback]);
	else if([menuItem action] == @selector(toggleLoopPlayback:))
		return (0 != [self countOfPlayQueue] && NO == [self randomPlayback]);
	else if([menuItem action] == @selector(toggleBrowser:)) {
		int state = [_browserDrawer state];
		if(NSDrawerClosingState == state || NSDrawerClosedState == state)
			[menuItem setTitle:NSLocalizedStringFromTable(@"Show Browser", @"Menus", @"")];
		else
			[menuItem setTitle:NSLocalizedStringFromTable(@"Hide Browser", @"Menus", @"")];
		return YES;
	}
	else if([menuItem action] == @selector(togglePlayQueue:)) {
		if([[_splitView subviewWithIdentifier:@"playQueue"] isCollapsed])
			[menuItem setTitle:NSLocalizedStringFromTable(@"Show Play Queue", @"Menus", @"")];
		else
			[menuItem setTitle:NSLocalizedStringFromTable(@"Hide Play Queue", @"Menus", @"")];
		return YES;
	}
	else if([menuItem action] == @selector(clearPlayQueue:))
		return (0 != [self countOfPlayQueue]);
	else if([menuItem action] == @selector(scramblePlayQueue:))
		return (1 < [self countOfPlayQueue]);
	else if([menuItem action] == @selector(prunePlayQueue:)) {
		unsigned count = [[_playQueueController selectionIndexes] count];
		return (0 < count && count < [self countOfPlayQueue]);
	}
	
	return YES;
}

#pragma mark Action Methods

- (IBAction) openBrowser:(id)sender
{
	[_browserDrawer open:sender];
}

- (IBAction) closeBrowser:(id)sender
{
	[_browserDrawer close:sender];
}

- (IBAction) toggleBrowser:(id)sender
{
	[_browserDrawer toggle:sender];
}

- (IBAction) togglePlayQueue:(id)sender
{
	RBSplitSubview *subView = [_splitView subviewWithIdentifier:@"playQueue"];
	if([subView isCollapsed])
		[subView expand];
	else
		[subView collapse];
}

- (IBAction) addCurrentTracksToPlayQueue:(id)sender
{
	[self addStreamsToPlayQueue:[_streamController arrangedObjects]];
}

- (IBAction) add10RandomTracksToPlayQueue:(id)sender
{
	[self addRandomTracksFromLibraryToPlayQueue:10];
}

- (IBAction) add25RandomTracksToPlayQueue:(id)sender
{
	[self addRandomTracksFromLibraryToPlayQueue:25];
}

- (void) addTracksToPlayQueueByArtist:(NSString *)artist
{
	NSParameterAssert(nil != artist);
	
	[self addStreamsToPlayQueue:[[[CollectionManager manager] streamManager] streamsForArtist:artist]];
}

- (void) addTracksToPlayQueueByAlbum:(NSString *)album
{
	NSParameterAssert(nil != album);
	
	[self addStreamsToPlayQueue:[[[CollectionManager manager] streamManager] streamsForAlbumTitle:album]];
}

- (void) addTracksToPlayQueueByComposer:(NSString *)composer
{
	NSParameterAssert(nil != composer);
	
	[self addStreamsToPlayQueue:[[[CollectionManager manager] streamManager] streamsForComposer:composer]];
}

- (void) addTracksToPlayQueueByGenre:(NSString *)genre
{
	NSParameterAssert(nil != genre);
	
	[self addStreamsToPlayQueue:[[[CollectionManager manager] streamManager] streamsForGenre:genre]];
}

- (IBAction) openDocument:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:YES];
	[panel setCanChooseDirectories:YES];
	
	[panel setTitle:NSLocalizedStringFromTable(@"Add to Library", @"Library", @"")];
	[panel setMessage:NSLocalizedStringFromTable(@"Choose files to add to the library.", @"Library", @"")];
	
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
	if(nil != [self nowPlaying] && 0 != [self countOfPlayQueue]) {
		RBSplitSubview *subView = [_splitView subviewWithIdentifier:@"playQueue"];
		if([subView isCollapsed])
			[subView expandWithAnimation];
		[self scrollNowPlayingToVisible];
		[_playQueueController setSelectionIndex:[self playbackIndex]];
	}
}

#pragma mark Browser methods

- (IBAction) browseLibrary:(id)sender
{
	[self selectBrowserNode:_libraryNode];
}

- (IBAction) browseMostPopular:(id)sender
{
	[self selectBrowserNode:_mostPopularNode];
}

- (IBAction) browseHighestRated:(id)sender
{
	[self selectBrowserNode:_highestRatedNode];
}

- (IBAction) browseRecentlyAdded:(id)sender
{
	[self selectBrowserNode:_recentlyAddedNode];
}

- (IBAction) browseRecentlyPlayed:(id)sender
{
	[self selectBrowserNode:_recentlyPlayedNode];
}

- (IBAction) browseRecentlySkipped:(id)sender
{
	[self selectBrowserNode:_recentlySkippedNode];
}

- (BOOL) browseTracksByArtist:(NSString *)artist
{
	NSParameterAssert(nil != artist);
	
	BrowserNode *artistNode = [_artistsNode findChildNamed:artist];
	if(nil != artistNode)
		return [self selectBrowserNode:artistNode];
	else
		return NO;
}

- (BOOL) browseTracksByAlbum:(NSString *)album
{
	NSParameterAssert(nil != album);
	
	BrowserNode *albumNode = [_albumsNode findChildNamed:album];
	if(nil != albumNode)
		return [self selectBrowserNode:albumNode];
	else
		return NO;
}

- (BOOL) browseTracksByComposer:(NSString *)composer
{
	NSParameterAssert(nil != composer);
	
	BrowserNode *composerNode = [_composersNode findChildNamed:composer];
	if(nil != composerNode)
		return [self selectBrowserNode:composerNode];
	else
		return NO;
}

- (BOOL) browseTracksByGenre:(NSString *)genre
{
	NSParameterAssert(nil != genre);
	
	BrowserNode *genreNode = [_genresNode findChildNamed:genre];
	if(nil != genreNode)
		return [self selectBrowserNode:genreNode];
	else	
		return NO;
}

- (BOOL) browseTracksByPlaylist:(NSString *)playlistName
{
	NSParameterAssert(nil != playlistName);
	
	BrowserNode *playlistNode = [_playlistsNode findChildNamed:playlistName];
	if(nil != playlistNode)
		return [self selectBrowserNode:playlistNode];
	else	
		return NO;
}

- (BOOL) browseTracksBySmartPlaylist:(NSString *)smartPlaylistName
{
	NSParameterAssert(nil != smartPlaylistName);
	
	BrowserNode *smartPlaylistNode = [_smartPlaylistsNode findChildNamed:smartPlaylistName];
	if(nil != smartPlaylistNode)
		return [self selectBrowserNode:smartPlaylistNode];
	else	
		return NO;
}

#pragma mark File Addition and Removal

- (BOOL) addFile:(NSString *)filename
{
	NSParameterAssert(nil != filename);
	
	NSError *error = nil;
	
	// Parse external cue sheets
	if([[filename pathExtension] isEqualToString:@"cue"])
		return [self addStreamsFromExternalCueSheet:filename];
	
	// Read the properties to determine if the file contains an embedded cuesheet
	AudioPropertiesReader *propertiesReader = [AudioPropertiesReader propertiesReaderForURL:[NSURL fileURLWithPath:filename] error:&error];
	if(nil == propertiesReader)
		return NO;
	
	BOOL result = [propertiesReader readProperties:&error];
	if(NO == result)
		return NO;
	
	// If the file contains an embedded cuesheet, treat each cue sheet entry as a separate stream in the library
	NSDictionary *cueSheet = [propertiesReader cueSheet];
	if(nil != cueSheet) {
		// Read the metadata for the file as a whole
		AudioMetadataReader *metadataReader	= [AudioMetadataReader metadataReaderForURL:[NSURL fileURLWithPath:filename] error:&error];
		if(nil == metadataReader)
			return NO;
		
		result = [metadataReader readMetadata:&error];
		if(NO == result)
			return NO;

		// Iterate through each track in the cue sheet, adding it to the library if required
		for(NSDictionary *cueSheetTrack in [cueSheet valueForKey:AudioPropertiesCueSheetTracksKey]) {
			// If the stream already exists in the library, skip it
			AudioStream *stream = [[[CollectionManager manager] streamManager] streamForURL:[NSURL fileURLWithPath:filename] 
																			  startingFrame:[cueSheetTrack valueForKey:StreamStartingFrameKey] 
																				 frameCount:[cueSheetTrack valueForKey:StreamFrameCountKey]];
			if(nil != stream)
				continue;

			// Create a dictionary containing all applicable keys for this stream
			NSMutableDictionary *values = [NSMutableDictionary dictionaryWithDictionary:[propertiesReader properties]];
			[values addEntriesFromDictionary:cueSheetTrack];
			[values addEntriesFromDictionary:[metadataReader metadata]];
			
			// Insert the object in the database
			stream = [AudioStream insertStreamForURL:[NSURL fileURLWithPath:filename] withInitialValues:values];
			
			// Add the stream to the selected playlist
			if(nil != stream && [_browserController selectedNodeIsPlaylist])
				[[(PlaylistNode *)[_browserController selectedNode] playlist] addStream:stream];
		}

		return YES;
	}
	else {
		// If the stream already exists in the library, do nothing
		AudioStream *stream = [[[CollectionManager manager] streamManager] streamForURL:[NSURL fileURLWithPath:filename]];
		if(nil != stream)
			return YES;

		// Read the metadata
		AudioMetadataReader *metadataReader	= [AudioMetadataReader metadataReaderForURL:[NSURL fileURLWithPath:filename] error:&error];
		if(nil == metadataReader)
			return NO;
		
		result = [metadataReader readMetadata:&error];
		if(NO == result)
			return NO;
		
		NSMutableDictionary *values = [NSMutableDictionary dictionaryWithDictionary:[propertiesReader properties]];
		[values addEntriesFromDictionary:[metadataReader metadata]];
		
		// Insert the object in the database
		stream = [AudioStream insertStreamForURL:[NSURL fileURLWithPath:filename] withInitialValues:values];
		
		// Add the stream to the selected playlist
		if(nil != stream && [_browserController selectedNodeIsPlaylist])
			[[(PlaylistNode *)[_browserController selectedNode] playlist] addStream:stream];
		
		return (nil != stream);
	}
}

- (BOOL) addFiles:(NSArray *)filenames
{
	return [self addFiles:filenames inModalSession:NULL];
}

- (BOOL) addFiles:(NSArray *)filenames inModalSession:(NSModalSession)modalSession
{
	NSParameterAssert(nil != filenames);
	
	NSString				*path					= nil;
	NSFileManager			*fileManager			= [NSFileManager defaultManager];
	NSDirectoryEnumerator	*directoryEnumerator	= nil;
	BOOL					isDirectory				= NO;
	BOOL					openSuccessful			= NO;
	
	[[CollectionManager manager] beginUpdate];
	
	for(NSString *filename in filenames) {
		
		// Perform a deep search for directories
		if([fileManager fileExistsAtPath:filename isDirectory:&isDirectory] && isDirectory) {
			directoryEnumerator	= [fileManager enumeratorAtPath:filename];
			
			while((path = [directoryEnumerator nextObject])) {
				openSuccessful |= [self addFile:[filename stringByAppendingPathComponent:path]];
				
				if(NULL != modalSession && NSRunContinuesResponse != [[NSApplication sharedApplication] runModalSession:modalSession])
					break;
			}
		}
		else {
			openSuccessful = [self addFile:filename];
			
			if(NULL != modalSession && NSRunContinuesResponse != [[NSApplication sharedApplication] runModalSession:modalSession])
				break;
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
	if(nil == stream)
		return YES;
	
	// Otherwise, remove it
	if([stream isPlaying])
		[self stop:self];
	
	[[[CollectionManager manager] streamManager] deleteStream:stream];
	
	return YES;
}

- (BOOL) removeFiles:(NSArray *)filenames
{
	NSParameterAssert(nil != filenames);
	
	NSString				*path					= nil;
	NSFileManager			*fileManager			= [NSFileManager defaultManager];
	NSDirectoryEnumerator	*directoryEnumerator	= nil;
	BOOL					isDirectory				= NO;
	BOOL					removeSuccessful		= YES;
	
	[[CollectionManager manager] beginUpdate];
	
	for(NSString *filename in filenames) {
		
		// Perform a deep search for directories
		if([fileManager fileExistsAtPath:filename isDirectory:&isDirectory] && isDirectory) {
			directoryEnumerator	= [fileManager enumeratorAtPath:filename];
			
			while((path = [directoryEnumerator nextObject]))
				removeSuccessful &= [self removeFile:[filename stringByAppendingPathComponent:path]];
		}
		else
			removeSuccessful = [self removeFile:filename];
	}
	
	[[CollectionManager manager] finishUpdate];
	
	return removeSuccessful;
}

#pragma mark Playlist manipulation

- (IBAction) insertPlaylist:(id)sender
{
	NSDictionary *initialValues = [NSDictionary dictionaryWithObject:NSLocalizedStringFromTable(@"Untitled Playlist", @"Library", @"") forKey:PlaylistNameKey];
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
	NSDictionary *initialValues = [NSDictionary dictionaryWithObject:NSLocalizedStringFromTable(@"Untitled Smart Playlist", @"Library", @"") forKey:PlaylistNameKey];
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
		if(success)
			stream = [[[CollectionManager manager] streamManager] streamForURL:[NSURL fileURLWithPath:filename]];
	}
		
	// Play the file, if everything worked
	if(nil != stream) {
		if([[self player] isPlaying])
			[self stop:self];
		[self setPlayQueueFromArray:[NSArray arrayWithObject:stream]];
		[self playStreamAtIndex:0];
	}
	
	return success;
}

- (BOOL) playFiles:(NSArray *)filenames
{
	NSParameterAssert(nil != filenames);

	NSString				*path					= nil;
	NSFileManager			*fileManager			= [NSFileManager defaultManager];
	NSDirectoryEnumerator	*directoryEnumerator	= nil;
	BOOL					isDirectory				= NO;
	BOOL					playSuccessful			= NO;
	BOOL					addSuccessful			= NO;
	AudioStream				*stream					= nil;
	NSMutableArray			*streams				= [NSMutableArray array];
	
	// First try to find these files in our library
	for(NSString * filename in filenames) {
		
		// Perform a deep search for directories
		if([fileManager fileExistsAtPath:filename isDirectory:&isDirectory] && isDirectory) {
			directoryEnumerator	= [fileManager enumeratorAtPath:filename];
			
			while((path = [directoryEnumerator nextObject])) {

				// Determine if the stream is in the library already
				stream = [[[CollectionManager manager] streamManager] streamForURL:[NSURL fileURLWithPath:[filename stringByAppendingPathComponent:path]]];
				
				// If it isn't, try and add it
				if(nil == stream) {
					addSuccessful = [self addFile:[filename stringByAppendingPathComponent:path]];
					if(addSuccessful)
						stream = [[[CollectionManager manager] streamManager] streamForURL:[NSURL fileURLWithPath:[filename stringByAppendingPathComponent:path]]];
				}
				
				if(nil != stream) {
					[streams addObject:stream];
					playSuccessful = YES;
				}				
			}
		}
		else {
			stream = [[[CollectionManager manager] streamManager] streamForURL:[NSURL fileURLWithPath:filename]];
			
			// If it isn't, try and add it
			if(nil == stream) {
				addSuccessful = [self addFile:[filename stringByAppendingPathComponent:path]];
				if(addSuccessful)
					stream = [[[CollectionManager manager] streamManager] streamForURL:[NSURL fileURLWithPath:filename]];
			}
			
			if(nil != stream) {
				[streams addObject:stream];
				playSuccessful = YES;
			}			
		}		
	}

	// Replace current streams with the files, and play the first one
	if(playSuccessful) {
		if([[self player] isPlaying])
			[self stop:self];
		[self setPlayQueueFromArray:streams];
		[self playStreamAtIndex:0];

		[self scrollNowPlayingToVisible];		
	}
	
	return playSuccessful;
}

- (IBAction) play:(id)sender
{
	if(NO == [self playButtonEnabled]) {
		NSBeep();
		return;
	}
	
	if([[self player] isPlaying])
		return;
	
	if(NO == [[self player] hasValidStream]) {
		if(0 != [self countOfPlayQueue]) {
			unsigned playIndex = ([self randomPlayback] ? (unsigned)(genrand_real2() * [self countOfPlayQueue]) : 0);			
			[self playStreamAtIndex:playIndex];
		}
		else if([self randomPlayback]) {
			NSArray		*streams			= (1 < [[_streamController selectedObjects] count] ? [_streamController selectedObjects] : [_streamController arrangedObjects]);
			double		randomNumber		= genrand_real2();
			unsigned	randomIndex			= (unsigned)(randomNumber * [streams count]);
			
			[self setPlayQueueFromArray:streams];
			[self playStreamAtIndex:randomIndex];
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
	
	if(NO == [[self player] hasValidStream])
		[self play:sender];
	else {
		[[self player] playPause];
		
		if([[self player] isPlaying])
			[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidResumeNotification 
																object:self
															  userInfo:[NSDictionary dictionaryWithObject:[self nowPlaying] forKey:AudioStreamObjectKey]];
		else
			[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidPauseNotification
																object:self
															  userInfo:[NSDictionary dictionaryWithObject:[self nowPlaying] forKey:AudioStreamObjectKey]];
	}
	
	[self updatePlayButtonState];
}

- (IBAction) stop:(id)sender
{
	if(NO == [[self player] hasValidStream]) {
		NSBeep();
		return;
	}

	AudioStream *stream = [self nowPlaying];

	[self setPlaybackIndex:NSNotFound];
	[self setNextPlaybackIndex:NSNotFound];

	if([[self player] isPlaying])
		[[self player] stop];
	
	[[self player] reset];

	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidStopNotification 
														object:self
													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
	
	[self updatePlayButtonState];
}

- (IBAction) skipForward:(id)sender
{
	if(NO == [[self player] streamSupportsSeeking]) {
		NSBeep();
		return;
	}
	
	[[self player] skipForward];
}

- (IBAction) skipBackward:(id)sender
{
	if(NO == [[self player] streamSupportsSeeking]) {
		NSBeep();
		return;
	}

	[[self player] skipBackward];
}

- (IBAction) skipToEnd:(id)sender
{
	if(NO == [[self player] streamSupportsSeeking]) {
		NSBeep();
		return;
	}

	[[self player] skipToEnd];
}

- (IBAction) skipToBeginning:(id)sender
{
	if(NO == [[self player] streamSupportsSeeking]) {
		NSBeep();
		return;
	}

	[[self player] skipToBeginning];
}

- (IBAction) playNextStream:(id)sender
{
	if(NO == [self canPlayNextStream]) {
		NSBeep();
		return;
	}
	
	AudioStream		*stream			= [self nowPlaying];
	unsigned		streamIndex;
	
	[stream setPlaying:NO];
	
	NSArray *streams = _playQueue;
	
	if(nil == stream || 0 == [streams count]) {
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
		
		if(streamIndex + 1 < [streams count])
			[self playStreamAtIndex:streamIndex + 1];
		else {
			[self setPlaybackIndex:NSNotFound];
			[self setPlayQueueFromArray:nil];
			[self updatePlayButtonState];
		}
	}
}

- (IBAction) playPreviousStream:(id)sender
{
	if(NO == [self canPlayPreviousStream]) {
		NSBeep();
		return;
	}

	AudioStream		*stream			= [self nowPlaying];
	unsigned		streamIndex;
	
	[stream setPlaying:NO];
	
	NSArray *streams = _playQueue;
	
	if(nil == stream || 0 == [streams count])
		[self setPlaybackIndex:NSNotFound];
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
		
		if(1 <= streamIndex)
			[self playStreamAtIndex:streamIndex - 1];
		else
			[self setPlaybackIndex:NSNotFound];
	}
}

- (void) playStreamAtIndex:(NSUInteger)thisIndex
{
	NSParameterAssert([self countOfPlayQueue] > thisIndex);
	
	AudioStream *currentStream = [self nowPlaying];
	
	[[self player] stop];
	
	if(nil != currentStream) {
		NSNumber		*skipCount		= [currentStream valueForKey:StatisticsSkipCountKey];
		NSNumber		*newSkipCount	= [NSNumber numberWithUnsignedInt:[skipCount unsignedIntValue] + 1];

		[currentStream setPlaying:NO];

		[[CollectionManager manager] beginUpdate];

		[currentStream setValue:[NSDate date] forKey:StatisticsLastSkippedDateKey];
		[currentStream setValue:newSkipCount forKey:StatisticsSkipCountKey];
		
		[[CollectionManager manager] finishUpdate];

		[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackWasSkippedNotification 
															object:self 
														  userInfo:[NSDictionary dictionaryWithObject:currentStream forKey:AudioStreamObjectKey]];
	}
	
	[_playQueueTable setNeedsDisplayInRect:[_playQueueTable rectOfRow:[self playbackIndex]]];
	
	[self setPlaybackIndex:thisIndex];
	[self setNextPlaybackIndex:NSNotFound];
	
	[_playQueueTable setNeedsDisplayInRect:[_playQueueTable rectOfRow:[self playbackIndex]]];
	
	AudioStream		*stream		= [self objectInPlayQueueAtIndex:[self playbackIndex]];
	NSError			*error		= nil;
	BOOL			result		= [[self player] setStream:stream error:&error];
	
	if(NO == result) {
		[self presentError:error modalForWindow:[self window] delegate:nil didPresentSelector:nil contextInfo:NULL];
//		[self removeObjectFromPlayQueueAtIndex:[self playbackIndex]];
		[self setPlaybackIndex:NSNotFound];
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
	[self scrollNowPlayingToVisible];
		
	[[self player] play];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidStartNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
	
	[self updatePlayButtonState];
}

- (BOOL) isPlaying
{
	return [[self player] isPlaying];
}

- (NSNumber *) volume
{
	return [NSNumber numberWithFloat:(float)([[self player] volume]*100.0f)];
}

- (void) setVolume:(NSNumber *)volume
{
	[[self player] setVolume:(Float32)([volume floatValue]/100.0f)];
}

- (NSTimeInterval) playerPosition
{
	return [[self player] currentSecond];
}


#pragma mark Play Queue management

- (unsigned) countOfPlayQueue
{
	return [_playQueue count];
}

- (AudioStream *) objectInPlayQueueAtIndex:(NSUInteger)thisIndex
{
	return [_playQueue objectAtIndex:thisIndex];
}

- (void) getPlayQueue:(id *)buffer range:(NSRange)aRange
{
	return [_playQueue getObjects:buffer range:aRange];
}

- (void) insertObject:(AudioStream *)stream inPlayQueueAtIndex:(NSUInteger)thisIndex
{
	[_playQueue insertObject:stream atIndex:thisIndex];	

	if(NSNotFound != [self nextPlaybackIndex] && thisIndex >= [self nextPlaybackIndex])
		[self setNextPlaybackIndex:[self nextPlaybackIndex] + 1];

	if(NSNotFound != [self playbackIndex] && thisIndex <= [self playbackIndex])
		[self setPlaybackIndex:[self playbackIndex] + 1];
	
	[self updatePlayButtonState];
}

- (void) removeObjectFromPlayQueueAtIndex:(NSUInteger)thisIndex
{
	[_playQueue removeObjectAtIndex:thisIndex];	

	if(NSNotFound != [self nextPlaybackIndex] && thisIndex < [self nextPlaybackIndex])
		[self setNextPlaybackIndex:[self nextPlaybackIndex] - 1];

	if(thisIndex == [self playbackIndex]) {
//		[self stop:self];
		[self setPlaybackIndex:NSNotFound];
	}
	else if(NSNotFound != [self playbackIndex] && thisIndex < [self playbackIndex])
		[self setPlaybackIndex:[self playbackIndex] - 1];

	[self updatePlayButtonState];
}

- (void) addStreamToPlayQueue:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	
	[self addStreamsToPlayQueue:[NSArray arrayWithObject:stream]];
}

- (void) addStreamsToPlayQueue:(NSArray *)streams
{
	NSParameterAssert(nil != streams);
	
	[self willChangeValueForKey:PlayQueueKey];
	[_playQueue addObjectsFromArray:streams];
	[self didChangeValueForKey:PlayQueueKey];
	
	[self updatePlayButtonState];
}

- (void) sortStreamsAndAddToPlayQueue:(NSArray *)streams
{
	NSParameterAssert(nil != streams);
	
	NSArray *sortedStreams = [streams sortedArrayUsingDescriptors:[_streamController sortDescriptors]];
	[self addStreamsToPlayQueue:sortedStreams];
}

- (void) insertStreams:(NSArray *)streams inPlayQueueAtIndex:(NSUInteger)thisIndex
{
	[self insertStreams:streams inPlayQueueAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(thisIndex, [streams count])]];
}

- (void) insertStreams:(NSArray *)streams inPlayQueueAtIndexes:(NSIndexSet *)indexes
{
	NSParameterAssert(nil != streams);
	NSParameterAssert(nil != indexes);
	NSParameterAssert([streams count] == [indexes count]);
		
	[self willChangeValueForKey:PlayQueueKey];
	[_playQueue insertObjects:streams atIndexes:indexes];
	[self didChangeValueForKey:PlayQueueKey];
	
	[self updatePlayButtonState];
}

- (IBAction) clearPlayQueue:(id)sender
{
	if([[self player] hasValidStream])
		[self stop:sender];
	
	[self willChangeValueForKey:PlayQueueKey];
	[_playQueue removeAllObjects];
	[self didChangeValueForKey:PlayQueueKey];

	[self updatePlayButtonState];
}

- (IBAction) scramblePlayQueue:(id)sender
{
	unsigned	i;
	double		randomNumber;
	unsigned	randomIndex;
	
	[self willChangeValueForKey:PlayQueueKey];
	for(i = 0; i < [self countOfPlayQueue]; ++i) {
		
		if([self playbackIndex] == i)
			continue;
		
		do {
			randomNumber	= genrand_real2();
			randomIndex		= (unsigned)(randomNumber * [self countOfPlayQueue]);
		} while(randomIndex == [self playbackIndex]);
		
		[_playQueue exchangeObjectAtIndex:i withObjectAtIndex:randomIndex];
	}
	[self didChangeValueForKey:PlayQueueKey];
}

- (IBAction) prunePlayQueue:(id)sender
{
	if(0 == [[_playQueueController selectionIndexes] count]) {
		NSBeep();
		return;
	}
	
	NSMutableIndexSet *indexesToRemove = [[NSMutableIndexSet alloc] init];
	[indexesToRemove addIndexesInRange:NSMakeRange(0, [self countOfPlayQueue])];
	[indexesToRemove removeIndexes:[_playQueueController selectionIndexes]];
	[_playQueueController removeObjectsAtArrangedObjectIndexes:indexesToRemove];
	[indexesToRemove release];
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
	
	if(NSNotFound == [self playbackIndex] || 0 == [streams count])
		result = NO;
	else if([self randomPlayback])
		result = YES;
	else if([self loopPlayback])
		result = YES;
	else
		result = ([self playbackIndex] + 1 < [streams count]);
	
	return result;
}

- (BOOL) canPlayPreviousStream
{
	NSArray		*streams	= _playQueue;
	BOOL		result		= NO;
	
	if(NSNotFound == [self playbackIndex] || 0 == [streams count])
		result = NO;
	else if([self randomPlayback])
		result = YES;
	else if([self loopPlayback])
		result = YES;
	else
		result = (1 <= [self playbackIndex]);
	
	return result;
}

- (AudioStream *) nowPlaying
{
	NSUInteger thisIndex = [self playbackIndex];
	return (NSNotFound == thisIndex ? nil : [self objectInPlayQueueAtIndex:thisIndex]);
}

- (NSUndoManager *) undoManager
{
	return [[CollectionManager manager] undoManager];
}

- (BOOL) streamsAreOrdered
{
	return _streamsAreOrdered;
}

- (BOOL) streamReorderingAllowed
{
	return _streamReorderingAllowed;
}

- (void) saveStateToDefaults
{
	[[NSUserDefaults standardUserDefaults] setBool:[self randomPlayback] forKey:@"randomPlayback"];
	[[NSUserDefaults standardUserDefaults] setBool:[self loopPlayback] forKey:@"loopPlayback"];
	
	[self saveBrowserStateToDefaults];
	
	[[self player] saveStateToDefaults];
}

- (void) restoreStateFromDefaults
{
	[self setRandomPlayback:[[NSUserDefaults standardUserDefaults] boolForKey:@"randomPlayback"]];
	[self setLoopPlayback:[[NSUserDefaults standardUserDefaults] boolForKey:@"loopPlayback"]];

	// Restore sort descriptors
	NSArray *sortDescriptors = nil;
	NSData *sortDescriptorData =[[NSUserDefaults standardUserDefaults] dataForKey:@"streamTableSortDescriptors"];
	if(nil != sortDescriptorData)
		sortDescriptors = (NSArray *)[NSKeyedUnarchiver unarchiveObjectWithData:sortDescriptorData];
	else
		sortDescriptors = [NSArray arrayWithObjects:
//			[[[NSSortDescriptor alloc] initWithKey:MetadataArtistKey ascending:YES] autorelease],
			[[[NSSortDescriptor alloc] initWithKey:MetadataAlbumTitleKey ascending:YES] autorelease],
			[[[NSSortDescriptor alloc] initWithKey:PropertiesDataFormatKey ascending:YES] autorelease],
			[[[NSSortDescriptor alloc] initWithKey:MetadataDiscNumberKey ascending:YES] autorelease],
			[[[NSSortDescriptor alloc] initWithKey:MetadataTrackNumberKey ascending:YES] autorelease],
			nil];
	
	[_streamController setSortDescriptors:sortDescriptors];
	
	[self restoreBrowserStateFromDefaults];

	[[self player] restoreStateFromDefaults];
}

@end

@implementation AudioLibrary (NSTableViewDelegateMethods)

- (NSString *) tableView:(NSTableView *)tableView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(int)row mouseLocation:(NSPoint)mouseLocation
{
    if([cell isKindOfClass:[NSTextFieldCell class]]) {
        if([[cell attributedStringValue] size].width > rect->size.width)
            return [cell stringValue];
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
			if([[aTableColumn identifier] isEqual:@"nowPlaying"])
				[cell setImage:(highlight ? [NSImage imageNamed:@"NowPlayingImage"] : nil)];
			
			// Bold/unbold cell font as required
			NSFont *font = [cell font];
			font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:(highlight ? NSBoldFontMask : NSUnboldFontMask)];
			[cell setFont:font];
		}
	}
}

- (void) tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
	if(tableView == _streamTable) {
		NSArray *sortDescriptors = [tableView sortDescriptors];
		NSData *sortDescriptorData = [NSKeyedArchiver archivedDataWithRootObject:sortDescriptors];
		[[NSUserDefaults standardUserDefaults] setObject:sortDescriptorData forKey:@"streamTableSortDescriptors"];
	}	
}

- (void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
	if([aNotification object] == _streamTable)
		[self updatePlayButtonState];
}

- (void) tableViewColumnDidMove:(NSNotification *)aNotification
{
	if([aNotification object] == _streamTable)
		[self saveStreamTableColumnOrder];
	else if([aNotification object] == _playQueueTable)
		[self savePlayQueueTableColumnOrder];
}

- (void) tableViewColumnDidResize:(NSNotification *)aNotification
{
	if([aNotification object] == _streamTable) {
		NSMutableDictionary		*sizes			= [NSMutableDictionary dictionary];
		
		for(id column in [_streamTable tableColumns])
			[sizes setObject:[NSNumber numberWithFloat:[column width]] forKey:[column identifier]];
		
		[[NSUserDefaults standardUserDefaults] setObject:sizes forKey:@"streamTableColumnSizes"];
	}
	else if([aNotification object] == _playQueueTable) {
		NSMutableDictionary		*sizes			= [NSMutableDictionary dictionary];
		
		for(id column in [_playQueueTable tableColumns])
			[sizes setObject:[NSNumber numberWithFloat:[column width]] forKey:[column identifier]];
		
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
	BrowserNode *node = nil;
//#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
	if(nil != NSClassFromString(@"NSTreeNode"))
		node = [item representedObject];
//#else
	else
		node = [item observedObject];
//#endif

	return [node nameIsEditable];
}

- (NSString *) outlineView:(NSOutlineView *)ov toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tc item:(id)item mouseLocation:(NSPoint)mouseLocation
{
    if([cell isKindOfClass:[NSTextFieldCell class]]) {
        if([[cell attributedStringValue] size].width > rect->size.width)
            return [cell stringValue];
    }
	
    return nil;
}

- (void) outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	BrowserNode *node = nil;
//#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
	if(nil != NSClassFromString(@"NSTreeNode"))
		node = [item representedObject];
//#else
	else
		node = [item observedObject];
//#endif
	
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
	NSArray						*selected			= [_streamController selectedObjects];
	NSDictionary				*bindingInfo		= [_streamController infoForBinding:@"contentArray"];
	AudioStreamCollectionNode	*oldStreamsNode		= [bindingInfo valueForKey:NSObservedObjectKey];
	BrowserNode					*node				= nil;

//#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
	if(nil != NSClassFromString(@"NSTreeNode"))
		node = [opaqueNode representedObject];
//#else
	else
		node = [opaqueNode observedObject];
//#endif

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
				if(NO == [newStreamsNode streamsAreOrdered])
					[_streamController setSortDescriptors:_streamTableSavedSortDescriptors];
			}
			else if([oldStreamsNode streamsAreOrdered]) {
				if(NO == [newStreamsNode streamsAreOrdered])
					[_streamController setSortDescriptors:_streamTableSavedSortDescriptors];
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

			// Save stream ordering info for drag validation
			_streamsAreOrdered			= [newStreamsNode streamsAreOrdered];
			_streamReorderingAllowed	= [newStreamsNode streamReorderingAllowed];
		}
	}
	else if([[oldStreamsNode exposedBindings] containsObject:@"streams"] && NO == [oldStreamsNode streamsAreOrdered]) {
		[_streamTableSavedSortDescriptors release], _streamTableSavedSortDescriptors = nil;
		_streamTableSavedSortDescriptors = [[_streamController sortDescriptors] retain];
		[_streamController setSortDescriptors:nil];
	}
}

@end

@implementation AudioLibrary (NSBrowserDelegateMethods)

- (int) browser:(NSBrowser *)sender numberOfRowsInColumn:(int)column
{
	if(0 == column) {
		NSString	*keyName	= [NSString stringWithFormat:@"@distinctUnionOfObjects.%@", MetadataArtistKey];
		NSArray		*streams	= [[[CollectionManager manager] streamManager] streams];
		NSArray		*artists	= [[streams valueForKeyPath:keyName] sortedArrayUsingSelector:@selector(compare:)];
		
		return [artists count];
	}
	else if(1 == column) {
		id			selectedArtist	= [sender selectedCellInColumn:0];
		NSArray		*streams		= [[[CollectionManager manager] streamManager] streamsForArtist:[selectedArtist stringValue]];
		NSString	*keyName		= [NSString stringWithFormat:@"@distinctUnionOfObjects.%@", MetadataAlbumTitleKey];
		NSArray		*albums			= [[streams valueForKeyPath:keyName] sortedArrayUsingSelector:@selector(compare:)];
		
		return [albums count];
	}
	
	return 0;
}

/*- (BOOL) browser:(NSBrowser *)sender isColumnValid:(int)column
{
	if(0 == column)
		return YES;
	else if(1 == column) {
		
	}
	
	return NO;
}*/

/*- (NSString *) browser:(NSBrowser *)sender titleOfColumn:(int)column
{
	if(0 == column)
		return NSLocalizedStringFromTable(@"Artists", @"Browser", @"");
	
	return nil;
}*/

- (void) browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(int)row column:(int)column
{
	if(0 == column) {
		NSString	*keyName	= [NSString stringWithFormat:@"@distinctUnionOfObjects.%@", MetadataArtistKey];
		NSArray		*streams	= [[[CollectionManager manager] streamManager] streams];
		NSArray		*artists	= [[streams valueForKeyPath:keyName] sortedArrayUsingSelector:@selector(compare:)];

		[cell setStringValue:[artists objectAtIndex:row]];
	}
	else if(1 == column) {
		id			selectedArtist	= [sender selectedCellInColumn:0];
		NSArray		*streams		= [[[CollectionManager manager] streamManager] streamsForArtist:[selectedArtist stringValue]];
		NSString	*keyName		= [NSString stringWithFormat:@"@distinctUnionOfObjects.%@", MetadataAlbumTitleKey];
		NSArray		*albums			= [[streams valueForKeyPath:keyName] sortedArrayUsingSelector:@selector(compare:)];
		
		[cell setStringValue:[albums objectAtIndex:row]];
	}
	
}

@end

@implementation AudioLibrary (CallbackMethods)

- (void) openDocumentSheetDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void *)contextInfo
{
	if(NSOKButton == returnCode) {
#if SQL_DEBUG
		unsigned startCount = [[[[CollectionManager manager] streamManager] streams] count];
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
		unsigned endCount = [[[[CollectionManager manager] streamManager] streams] count];
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

		if(nil != watchFolder)
			[_browserDrawer open:self];
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
	if([[self player] isPlaying])
		[self stop:self];
}

- (NSUndoManager *) windowWillReturnUndoManager:(NSWindow *)sender
{
	return [self undoManager];
}

@end

@implementation AudioLibrary (NSToolbarDelegateMethods)

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag 
{
	NSToolbarItem *toolbarItem = nil;

	if([itemIdentifier isEqualToString:PlayerControlsToolbarItemIdentifier]) {
		toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
		
		[toolbarItem setLabel:NSLocalizedStringFromTable(@"Player Controls", @"Library", @"")];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTable(@"Player Controls", @"Library", @"")];		
		[toolbarItem setToolTip:NSLocalizedStringFromTable(@"Control the audio player", @"Library", @"")];
		
		[toolbarItem setView:_playerControlsToolbarView];
		[toolbarItem setMinSize:[_playerControlsToolbarView frame].size];
		[toolbarItem setMaxSize:[_playerControlsToolbarView frame].size];
	}
	else if([itemIdentifier isEqualToString:PlaybackOrderControlsToolbarItemIdentifier]) {
		toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];

		[toolbarItem setLabel:NSLocalizedStringFromTable(@"Playback Order", @"Library", @"")];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTable(@"Playback Order", @"Library", @"")];		
		[toolbarItem setToolTip:NSLocalizedStringFromTable(@"Control the playback order", @"Library", @"")];

		[toolbarItem setView:_playbackOrderControlsToolbarView];
		[toolbarItem setMinSize:[_playbackOrderControlsToolbarView frame].size];
		[toolbarItem setMaxSize:[_playbackOrderControlsToolbarView frame].size];
	}
	else if([itemIdentifier isEqualToString:VolumeControlToolbarItemIdentifier]) {
		toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
		
		[toolbarItem setLabel:NSLocalizedStringFromTable(@"Volume", @"Library", @"")];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTable(@"Volume", @"Library", @"")];		
		[toolbarItem setToolTip:NSLocalizedStringFromTable(@"Adjust the output volume", @"Library", @"")];
		
		[toolbarItem setView:_volumeControlToolbarView];
		[toolbarItem setMinSize:[_volumeControlToolbarView frame].size];
		[toolbarItem setMaxSize:[_volumeControlToolbarView frame].size];
	}
	else if([itemIdentifier isEqualToString:SearchFieldToolbarItemIdentifier]) {
		toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
		
		[toolbarItem setLabel:NSLocalizedStringFromTable(@"Search", @"Library", @"")];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTable(@"Search", @"Library", @"")];		
		[toolbarItem setToolTip:NSLocalizedStringFromTable(@"Search for tracks", @"Library", @"")];
		
		[toolbarItem setView:_searchFieldToolbarView];
		[toolbarItem setMinSize:[_searchFieldToolbarView frame].size];
		[toolbarItem setMaxSize:[_searchFieldToolbarView frame].size];
	}

    return [toolbarItem autorelease];
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar 
{
	return [NSArray arrayWithObjects:
		PlayerControlsToolbarItemIdentifier,
		PlaybackOrderControlsToolbarItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		VolumeControlToolbarItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		SearchFieldToolbarItemIdentifier,
		nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar 
{
	return [NSArray arrayWithObjects:
		PlayerControlsToolbarItemIdentifier,
		PlaybackOrderControlsToolbarItemIdentifier,
		VolumeControlToolbarItemIdentifier,
		SearchFieldToolbarItemIdentifier,
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		nil];
}

@end

@implementation AudioLibrary (AudioPlayerMethods)

// Signals the end of the stream at currentPlaybackIndex and the beginning of the stream at nextPlaybackIndex
- (void) streamPlaybackDidStart
{
	AudioStream		*stream			= [self nowPlaying];	
	NSNumber		*playCount		= [stream valueForKey:StatisticsPlayCountKey];
	NSNumber		*newPlayCount	= [NSNumber numberWithUnsignedInt:[playCount unsignedIntValue] + 1];
	
	[stream setPlaying:NO];
	
	[[CollectionManager manager] beginUpdate];
	
	[stream setValue:[NSDate date] forKey:StatisticsLastPlayedDateKey];
	[stream setValue:newPlayCount forKey:StatisticsPlayCountKey];
	
	if(nil == [stream valueForKey:StatisticsFirstPlayedDateKey])
		[stream setValue:[NSDate date] forKey:StatisticsFirstPlayedDateKey];
	
	[[CollectionManager manager] finishUpdate];
	
	[_playQueueTable setNeedsDisplayInRect:[_playQueueTable rectOfRow:[self playbackIndex]]];
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"removeStreamsFromPlayQueueWhenFinished"] && [self nextPlaybackIndex] != [self playbackIndex])
		[self removeObjectFromPlayQueueAtIndex:[self playbackIndex]];	
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidCompleteNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];

	[self setPlaybackIndex:[self nextPlaybackIndex]];
	[self setNextPlaybackIndex:NSNotFound];
	
	_sentNextStreamRequest = NO;

	[_playQueueTable setNeedsDisplayInRect:[_playQueueTable rectOfRow:[self playbackIndex]]];
	
	[self updatePlayQueueHistory];
	
	stream = [self nowPlaying];
	NSAssert(nil != stream, @"Playback started for stream index not in play queue.");
	
	[stream setPlaying:YES];
	[self scrollNowPlayingToVisible];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidStartNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
}

// Signals the end of the stream at currentPlaybackIndex
- (void) streamPlaybackDidComplete
{
	AudioStream		*stream			= [self nowPlaying];	
	NSNumber		*playCount		= [stream valueForKey:StatisticsPlayCountKey];
	NSNumber		*newPlayCount	= [NSNumber numberWithUnsignedInt:[playCount unsignedIntValue] + 1];
	
	[stream setPlaying:NO];
	
	[[CollectionManager manager] beginUpdate];
	
	[stream setValue:[NSDate date] forKey:StatisticsLastPlayedDateKey];
	[stream setValue:newPlayCount forKey:StatisticsPlayCountKey];
	
	if(nil == [stream valueForKey:StatisticsFirstPlayedDateKey])
		[stream setValue:[NSDate date] forKey:StatisticsFirstPlayedDateKey];
	
	[[CollectionManager manager] finishUpdate];
	
	[_playQueueTable setNeedsDisplayInRect:[_playQueueTable rectOfRow:[self playbackIndex]]];
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"removeStreamsFromPlayQueueWhenFinished"] && [self nextPlaybackIndex] != [self playbackIndex])
		[self removeObjectFromPlayQueueAtIndex:[self playbackIndex]];	
	
	[self setPlaybackIndex:NSNotFound];

	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidCompleteNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
	
	// If the player isn't playing, it could be because the streams have different PCM formats
	if(NO == [[self player] isPlaying]) {		
		// Next stream was requested by player, but the PCM formats differ so gapless playback was impossible
		if(NSNotFound != [self nextPlaybackIndex])
			[self playStreamAtIndex:[self nextPlaybackIndex]];
		// The player has already stopped, just update our state
		else
			[self updatePlayButtonState];
	}	
}

// The player sends this message to request the next stream, to allow for gapless playback
- (void) requestNextStream
{
	AudioStream		*stream			= [self nowPlaying];
	unsigned		streamIndex;
	NSArray			*streams		= _playQueue;
	
	if(nil == stream || 0 == [streams count])
		[self setNextPlaybackIndex:NSNotFound];
	else if([self randomPlayback]) {
		double		randomNumber;
		unsigned	randomIndex;
		
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"removeStreamsFromPlayQueueWhenFinished"]) {
			if(1 == [streams count])
				randomIndex = NSNotFound;
			else {
				do {
					randomNumber	= genrand_real2();
					randomIndex		= (unsigned)(randomNumber * [streams count]);
				} while(randomIndex == [self playbackIndex]);
			}
		}
		else {
			randomNumber	= genrand_real2();
			randomIndex		= (unsigned)(randomNumber * [streams count]);
		}
		
		[self setNextPlaybackIndex:randomIndex];
	}
	else if([self loopPlayback]) {
		streamIndex = [self playbackIndex];		
		[self setNextPlaybackIndex:(streamIndex + 1 < [streams count] ? streamIndex + 1 : 0)];
	}
	else {
		streamIndex = [self playbackIndex];
		[self setNextPlaybackIndex:(streamIndex + 1 < [streams count] ? streamIndex + 1 : NSNotFound)];
	}

	// A valid stream exists in the table, try to queue it up
	if(NSNotFound != [self nextPlaybackIndex]) {
		NSError		*error		= nil;
		BOOL		result		= [[self player] setNextStream:[self objectInPlayQueueAtIndex:[self nextPlaybackIndex]] error:&error];

		if(result)
			_sentNextStreamRequest = YES;
		// The PCM formats or channel layouts don't match, so gapless won't work for these two streams
		else {
			_sentNextStreamRequest = NO;
			if(nil != error)
				[self presentError:error modalForWindow:[self window] delegate:nil didPresentSelector:nil contextInfo:NULL];
		}
	}
	else
		_sentNextStreamRequest = NO;
}

- (BOOL) sentNextStreamRequest
{
	return _sentNextStreamRequest;
}

- (AudioStream *) nextStream
{
	return [self objectInPlayQueueAtIndex:[self nextPlaybackIndex]];
}

@end

@implementation AudioLibrary (Private)

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
	else
		[_playQueueTable setHighlightedRow:-1];

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

- (void) addRandomTracksFromLibraryToPlayQueue:(unsigned)count
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

- (BOOL) addStreamsFromExternalCueSheet:(NSString *)filename
{
	NSParameterAssert(nil != filename);
	
	NSError *error = nil;
	CueSheetParser *cueSheetParser = [CueSheetParser cueSheetWithURL:[NSURL fileURLWithPath:filename] error:&error];
	if(nil == cueSheetParser)
		return NO;
	
	// Iterate through each track in the cue sheet, adding it to the library if required
	for(NSDictionary *cueSheetTrack in [cueSheetParser cueSheetTracks]) {
		// If the stream already exists in the library, skip it
		AudioStream *stream = [[[CollectionManager manager] streamManager] streamForURL:[cueSheetTrack valueForKey:StreamURLKey] 
																		  startingFrame:[cueSheetTrack valueForKey:StreamStartingFrameKey] 
																			 frameCount:[cueSheetTrack valueForKey:StreamFrameCountKey]];
		if(nil != stream)
			continue;
		
		// Insert the object in the database
		stream = [AudioStream insertStreamForURL:[NSURL fileURLWithPath:filename] withInitialValues:cueSheetTrack];
		
		// Add the stream to the selected playlist
		if(nil != stream && [_browserController selectedNodeIsPlaylist])
			[[(PlaylistNode *)[_browserController selectedNode] playlist] addStream:stream];
	}
	
	return YES;
}

- (void) updatePlayQueueHistory
{
	if(NO == [[NSUserDefaults standardUserDefaults] boolForKey:@"removeStreamsFromPlayQueueWhenFinished"] && [[NSUserDefaults standardUserDefaults] boolForKey:@"limitPlayQueueHistorySize"] && NO == [self randomPlayback]) {
		unsigned playQueueHistorySize	= [[NSUserDefaults standardUserDefaults] integerForKey:@"playQueueHistorySize"];
		NSUInteger thisIndex					= [self playbackIndex];
		
		[self willChangeValueForKey:PlayQueueKey];
		while(thisIndex > playQueueHistorySize) {
			[_playQueue removeObjectAtIndex:0];
			--thisIndex;
		}
		[self didChangeValueForKey:PlayQueueKey];

		[self setPlaybackIndex:thisIndex];
	}
}

- (void) updatePlayButtonState
{	
	if([[self player] isPlaying]) {		
		[_playPauseButton setState:NSOnState];
		[_playPauseButton setToolTip:NSLocalizedStringFromTable(@"Pause playback", @"Player", @"")];
		
		[self setPlayButtonEnabled:YES];
	}
	else if(NO == [[self player] hasValidStream]) {
		[_playPauseButton setState:NSOffState];
		[_playPauseButton setToolTip:NSLocalizedStringFromTable(@"Play", @"Player", @"")];
		
		[self setPlayButtonEnabled:(0 != [self countOfPlayQueue] || 0 != [[_streamController selectedObjects] count])];
	}
	else {
		[_playPauseButton setState:NSOffState];
		[_playPauseButton setToolTip:NSLocalizedStringFromTable(@"Resume playback", @"Player", @"")];
		
		[self setPlayButtonEnabled:YES];
	}
}

- (void) setupToolbar
{
    NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:AudioLibraryToolbarIdentifier];
    [toolbar setAllowsUserCustomization:YES];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
    [toolbar setAutosavesConfiguration:YES];
    
    [toolbar setDelegate:self];
	
    [[self window] setToolbar:[toolbar autorelease]];
}

- (void) setupBrowser
{	
	// Grab the icons we'll be using
	IconFamily	*folderIconFamily	= [IconFamily iconFamilyWithSystemIcon:kGenericFolderIcon];
	NSImage		*folderIcon			= [folderIconFamily imageWithAllReps];
	
	[folderIcon setSize:NSMakeSize(16.0f, 16.0f)];
	
/*	IconFamily	*cdIconFamily		= [IconFamily iconFamilyWithSystemIcon:kGenericCDROMIcon];
	NSImage		*cdIcon				= [cdIconFamily imageWithAllReps];

	[cdIcon setSize:NSMakeSize(16.0f, 16.0f)];*/

	BrowserNode *browserRoot = [[BrowserNode alloc] initWithName:NSLocalizedStringFromTable(@"Collection", @"Library", @"")];
	[browserRoot setIcon:folderIcon];
	
	_libraryNode			= [[LibraryNode alloc] init];
	_mostPopularNode		= [[MostPopularNode alloc] init];
	_highestRatedNode		= [[HighestRatedNode alloc] init];
	_recentlyAddedNode		= [[RecentlyAddedNode alloc] init];
	_recentlyPlayedNode		= [[RecentlyPlayedNode alloc] init];
	_recentlySkippedNode	= [[RecentlySkippedNode alloc] init];
	
	_artistsNode = [[ArtistsNode alloc] init];
	[_artistsNode setIcon:folderIcon];

	_albumsNode = [[AlbumsNode alloc] init];
	[_albumsNode setIcon:folderIcon];

	_composersNode = [[ComposersNode alloc] init];
	[_composersNode setIcon:folderIcon];
	
	_genresNode = [[GenresNode alloc] init];
	[_genresNode setIcon:folderIcon];

	_playlistsNode = [[PlaylistsNode alloc] init];
	[_playlistsNode setIcon:folderIcon];

	_smartPlaylistsNode = [[SmartPlaylistsNode alloc] init];
	[_smartPlaylistsNode setIcon:folderIcon];

	WatchFoldersNode *watchFoldersNode = [[WatchFoldersNode alloc] init];
	[watchFoldersNode setIcon:folderIcon];

	
	[browserRoot addChild:_libraryNode];
	[browserRoot addChild:_mostPopularNode];
	[browserRoot addChild:_highestRatedNode];
	[browserRoot addChild:_recentlyAddedNode];
	[browserRoot addChild:_recentlyPlayedNode];
	[browserRoot addChild:_recentlySkippedNode];
	[browserRoot addChild:_artistsNode];
	[browserRoot addChild:_albumsNode];
	[browserRoot addChild:_composersNode];
	[browserRoot addChild:_genresNode];
	[browserRoot addChild:_playlistsNode];
	[browserRoot addChild:_smartPlaylistsNode];
	[browserRoot addChild:[watchFoldersNode autorelease]];

	[_browserController setContent:[browserRoot autorelease]];

	// Select the LibraryNode
	[self browseLibrary:self];
	
	// Setup the custom data cell
	NSTableColumn		*tableColumn		= [_browserOutlineView tableColumnWithIdentifier:@"name"];
	ImageAndTextCell	*imageAndTextCell	= [[ImageAndTextCell alloc] init];
	
	[imageAndTextCell setLineBreakMode:NSLineBreakByTruncatingTail];
	[tableColumn setDataCell:[imageAndTextCell autorelease]];
}

- (void) saveBrowserStateToDefaults
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:[_browserDrawer state]] forKey:@"browserDrawerState"];
	[[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:[_browserController selectionIndexPath]] forKey:@"browserSelectionIndexPathArchive"];
}

- (void) restoreBrowserStateFromDefaults
{
	// Restore the browser's state
	switch([[NSUserDefaults standardUserDefaults] integerForKey:@"browserDrawerState"]) {
		case NSDrawerOpenState:			[_browserDrawer open];		break;
		case NSDrawerOpeningState:		[_browserDrawer open];		break;
	}
	
	// and selected node
	NSData *archivedIndexPath = [[NSUserDefaults standardUserDefaults] dataForKey:@"browserSelectionIndexPathArchive"];
	if(nil != archivedIndexPath) {
		NSIndexPath *selectedNodeIndexPath = [NSKeyedUnarchiver unarchiveObjectWithData:archivedIndexPath];
		if(nil != selectedNodeIndexPath) {
			BOOL nodeSelected = [_browserController setSelectionIndexPath:selectedNodeIndexPath];
			if(NO == nodeSelected)
				[self browseLibrary:self];
		}
	}
}

- (BOOL) selectBrowserNode:(BrowserNode *)node
{
	NSParameterAssert(nil != node);

	NSTreeNode *match = nil;
	
	for(NSTreeNode *child in [[_browserController arrangedObjects] childNodes]) {
		match = treeNodeForRepresentedObject(child, node);
		if(match)
			break;
	}
	
	return [_browserController setSelectionIndexPath:[match indexPath]];
}

- (void) setupStreamTableColumns
{
	NSMenuItem		*contextMenuItem;	
	int				menuIndex, i;
	
	// Setup stream table columns
	NSDictionary	*visibleDictionary	= [[NSUserDefaults standardUserDefaults] objectForKey:@"streamTableColumnVisibility"];
	NSDictionary	*sizesDictionary	= [[NSUserDefaults standardUserDefaults] objectForKey:@"streamTableColumnSizes"];
	NSArray			*orderArray			= [[NSUserDefaults standardUserDefaults] objectForKey:@"streamTableColumnOrder"];
		
	_streamTableVisibleColumns			= [[NSMutableSet alloc] init];
	_streamTableHiddenColumns			= [[NSMutableSet alloc] init];
	_streamTableHeaderContextMenu		= [[NSMenu alloc] initWithTitle:@"Stream Table Header Context Menu"];
	
	// Set localized date formatters
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
	
	[[[_streamTable tableColumnWithIdentifier:@"dateAdded"] dataCell] setFormatter:dateFormatter];
	[[[_streamTable tableColumnWithIdentifier:@"lastPlayed"] dataCell] setFormatter:dateFormatter];
	[[[_streamTable tableColumnWithIdentifier:@"lastSkipped"] dataCell] setFormatter:dateFormatter];
	
	[dateFormatter release];
	
	// Set localized number formatters
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	
	[[[_streamTable tableColumnWithIdentifier:@"id"] dataCell] setFormatter:numberFormatter];
	[[[_streamTable tableColumnWithIdentifier:@"playCount"] dataCell] setFormatter:numberFormatter];
	[[[_streamTable tableColumnWithIdentifier:@"skipCount"] dataCell] setFormatter:numberFormatter];
	[[[_streamTable tableColumnWithIdentifier:@"bpm"] dataCell] setFormatter:numberFormatter];
	[[[_streamTable tableColumnWithIdentifier:@"bitrate"] dataCell] setFormatter:numberFormatter];
	
	[numberFormatter release];

	[[_streamTable headerView] setMenu:_streamTableHeaderContextMenu];
	
	// Also replace the placeholder item in the menu bar
	 NSMenu *mainMenu = [[NSApplication sharedApplication] mainMenu];
	 NSMenu *viewMenu = [[mainMenu itemAtIndex:VIEW_MENU_INDEX] submenu];
	 if(nil != viewMenu) {
		 NSMenuItem *streamTableColumnsMenuItem = [viewMenu itemAtIndex:STREAM_TABLE_COLUMNS_MENU_ITEM_INDEX];
		 [mainMenu setSubmenu:_streamTableHeaderContextMenu forItem:streamTableColumnsMenuItem];
	 }
	
	// Keep our changes from generating notifications to ourselves
	[_streamTable setDelegate:nil];
	
	for(id obj in [_streamTable tableColumns]) {
		menuIndex = 0;
		
		while(menuIndex < [_streamTableHeaderContextMenu numberOfItems] 
			  && NSOrderedDescending == [[[obj headerCell] title] localizedCompare:[[_streamTableHeaderContextMenu itemAtIndex:menuIndex] title]])
			menuIndex++;
		
		contextMenuItem = [_streamTableHeaderContextMenu insertItemWithTitle:[[obj headerCell] title] action:@selector(streamTableHeaderContextMenuSelected:) keyEquivalent:@"" atIndex:menuIndex];
		
		[contextMenuItem setTarget:self];
		[contextMenuItem setRepresentedObject:obj];
		[contextMenuItem setState:([[visibleDictionary objectForKey:[obj identifier]] boolValue] ? NSOnState : NSOffState)];
		
//		NSLog(@"setting width of %@ to %f", [obj identifier], [[sizesDictionary objectForKey:[obj identifier]] floatValue]);
		[obj setWidth:[[sizesDictionary objectForKey:[obj identifier]] floatValue]];
		
		if([[visibleDictionary objectForKey:[obj identifier]] boolValue])
			[_streamTableVisibleColumns addObject:obj];
		else
			[_streamTableHiddenColumns addObject:obj];
	}

	// Don't modify table columns while enumerating
	for(id obj in _streamTableHiddenColumns)
		[_streamTable removeTableColumn:obj];

	i = 0;
	for(id obj in orderArray) {
		[_streamTable moveColumn:[_streamTable columnWithIdentifier:obj] toColumn:i];
		++i;
	}
	
	[_streamTable setDelegate:self];
}

- (void) setupPlayQueueTableColumns
{
	NSMenuItem		*contextMenuItem;	
	int				menuIndex, i;
	
	// Setup stream table columns
	NSDictionary	*visibleDictionary	= [[NSUserDefaults standardUserDefaults] objectForKey:@"playQueueTableColumnVisibility"];
	NSDictionary	*sizesDictionary	= [[NSUserDefaults standardUserDefaults] objectForKey:@"playQueueTableColumnSizes"];

	_playQueueTableVisibleColumns		= [[NSMutableSet alloc] init];
	_playQueueTableHiddenColumns		= [[NSMutableSet alloc] init];
	_playQueueTableHeaderContextMenu	= [[NSMenu alloc] initWithTitle:@"Play Queue Table Header Context Menu"];
	
	// Set localized date formatters
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
	
	[[[_playQueueTable tableColumnWithIdentifier:@"dateAdded"] dataCell] setFormatter:dateFormatter];
	[[[_playQueueTable tableColumnWithIdentifier:@"lastPlayed"] dataCell] setFormatter:dateFormatter];
	[[[_playQueueTable tableColumnWithIdentifier:@"lastSkipped"] dataCell] setFormatter:dateFormatter];
	
	[dateFormatter release];

	// Set localized number formatters
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	
	[[[_playQueueTable tableColumnWithIdentifier:@"id"] dataCell] setFormatter:numberFormatter];
	[[[_playQueueTable tableColumnWithIdentifier:@"playCount"] dataCell] setFormatter:numberFormatter];
	[[[_playQueueTable tableColumnWithIdentifier:@"skipCount"] dataCell] setFormatter:numberFormatter];
	[[[_playQueueTable tableColumnWithIdentifier:@"bpm"] dataCell] setFormatter:numberFormatter];
	[[[_playQueueTable tableColumnWithIdentifier:@"bitrate"] dataCell] setFormatter:numberFormatter];
	
	[numberFormatter release];
	
	[[_playQueueTable headerView] setMenu:_playQueueTableHeaderContextMenu];
	
	// Also replace the placeholder item in the menu bar
	NSMenu *mainMenu = [[NSApplication sharedApplication] mainMenu];
	NSMenu *viewMenu = [[mainMenu itemAtIndex:VIEW_MENU_INDEX] submenu];
	if(nil != viewMenu) {
		NSMenuItem *playQueueTableColumnsMenuItem = [viewMenu itemAtIndex:PLAY_QUEUE_TABLE_COLUMNS_MENU_ITEM_INDEX];
		[mainMenu setSubmenu:_playQueueTableHeaderContextMenu forItem:playQueueTableColumnsMenuItem];
	}

	// Keep our changes from generating notifications to ourselves
	[_playQueueTable setDelegate:nil];
	
	for(id obj in [_playQueueTable tableColumns]) {
		menuIndex = 0;
		
		while(menuIndex < [_playQueueTableHeaderContextMenu numberOfItems] 
			  && NSOrderedDescending == [[[obj headerCell] title] localizedCompare:[[_playQueueTableHeaderContextMenu itemAtIndex:menuIndex] title]])
			menuIndex++;
		
		contextMenuItem = [_playQueueTableHeaderContextMenu insertItemWithTitle:[[obj headerCell] title] action:@selector(playQueueTableHeaderContextMenuSelected:) keyEquivalent:@"" atIndex:menuIndex];
		
		[contextMenuItem setTarget:self];
		[contextMenuItem setRepresentedObject:obj];
		[contextMenuItem setState:([[visibleDictionary objectForKey:[obj identifier]] boolValue] ? NSOnState : NSOffState)];
		
//		NSLog(@"setting width of %@ to %f", [obj identifier], [[sizesDictionary objectForKey:[obj identifier]] floatValue]);
		[obj setWidth:[[sizesDictionary objectForKey:[obj identifier]] floatValue]];
		
		if([[visibleDictionary objectForKey:[obj identifier]] boolValue])
			[_playQueueTableVisibleColumns addObject:obj];
		else
			[_playQueueTableHiddenColumns addObject:obj];
	}

	// Don't modify table columns while enumerating
	for(id obj in _playQueueTableHiddenColumns)
		[_playQueueTable removeTableColumn:obj];
	
	i = 0;
	for(id obj in [[NSUserDefaults standardUserDefaults] objectForKey:@"playQueueTableColumnOrder"]) {
		[_playQueueTable moveColumn:[_playQueueTable columnWithIdentifier:obj] toColumn:i];
		++i;
	}
	
	[_playQueueTable setDelegate:self];
}

- (void) scanWatchFolders
{
	// Load all the watch folders and update the library contents (in the background because this is a potentially slow operation)
	for(WatchFolder *watchFolder in [[[CollectionManager manager] watchFolderManager] watchFolders]) {
//		[NSThread detachNewThreadSelector:@selector(synchronizeWithWatchFolder:) toTarget:self withObject:watchFolder];
		[self synchronizeWithWatchFolder:watchFolder];
	}	
}

- (void) synchronizeWithWatchFolder:(WatchFolder *)watchFolder
{
	NSParameterAssert(nil != watchFolder);
	
	NSAutoreleasePool	*pool				= [[NSAutoreleasePool alloc] init];
	NSURL				*url				= [watchFolder valueForKey:WatchFolderURLKey];
	NSMutableSet		*libraryFilenames	= [NSMutableSet set];
	
	// Attempt to set the thread's priority (should be low)
/*	BOOL result = [NSThread setThreadPriority:0.2];
	if(NO == result) {
		NSLog(@"Unable to set thread priority");
	}*/
	
	for(AudioStream *stream in [[[CollectionManager manager] streamManager] streamsContainedByURL:url])
		[libraryFilenames addObject:[[stream valueForKey:StreamURLKey] path]];
	
	// Next iterate through and see what is actually in the directory
	NSMutableSet	*physicalFilenames	= [NSMutableSet set];
	NSArray			*allowedTypes		= getAudioExtensions();
	NSString		*path				= [url path];
	NSString		*filename			= nil;
	BOOL			isDir;
	
	BOOL result = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
	if(NO == result || NO == isDir) {
		NSLog(@"Unable to locate folder \"%@\".", path);
		return;
	}
	
	NSDirectoryEnumerator *directoryEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:path];
	
	while((filename = [directoryEnumerator nextObject])) {
		if([allowedTypes containsObject:[filename pathExtension]]) {
			[physicalFilenames addObject:[path stringByAppendingPathComponent:filename]];
		}
	}
	
	// Determine if any files were deleted
	NSMutableSet *removedFilenames = [NSMutableSet setWithSet:libraryFilenames];
	[removedFilenames minusSet:physicalFilenames];
	
	// Determine if any files were added
	NSMutableSet *addedFilenames = [NSMutableSet setWithSet:physicalFilenames];
	[addedFilenames minusSet:libraryFilenames];
	
	if(0 != [addedFilenames count]) {
//		[self performSelectorOnMainThread:@selector(addFiles:) withObject:[addedFilenames allObjects] waitUntilDone:YES];
		[self addFiles:[addedFilenames allObjects]];
	}
	
	if(0 != [removedFilenames count]) {
//		[self performSelectorOnMainThread:@selector(removeFiles:) withObject:[removedFilenames allObjects] waitUntilDone:YES];
		[self removeFiles:[removedFilenames allObjects]];
	}
	
	// Force a refresh
	[watchFolder loadStreams];
	
	[pool release];
}

#pragma mark Stream Table Management

- (void) saveStreamTableColumnOrder
{
	NSMutableArray	*identifiers	= [NSMutableArray array];
	
	for(id obj in [_streamTable tableColumns])
		[identifiers addObject:[obj identifier]];
	
	[[NSUserDefaults standardUserDefaults] setObject:identifiers forKey:@"streamTableColumnOrder"];
	//	[[NSUserDefaults standardUserDefaults] synchronize];
}	

- (void) savePlayQueueTableColumnOrder
{
	NSMutableArray	*identifiers	= [NSMutableArray array];
	
	for(id obj in [_playQueueTable tableColumns])
		[identifiers addObject:[obj identifier]];
	
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
	
	for(id obj in _streamTableVisibleColumns)
		[visibleDictionary setObject:[NSNumber numberWithBool:YES] forKey:[obj identifier]];
	
	for(id obj in _streamTableHiddenColumns)
		[visibleDictionary setObject:[NSNumber numberWithBool:NO] forKey:[obj identifier]];
	
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
	
	for(id obj in _playQueueTableVisibleColumns)
		[visibleDictionary setObject:[NSNumber numberWithBool:YES] forKey:[obj identifier]];
	
	for(id obj in _playQueueTableHiddenColumns)
		[visibleDictionary setObject:[NSNumber numberWithBool:NO] forKey:[obj identifier]];
	
	[[NSUserDefaults standardUserDefaults] setObject:visibleDictionary forKey:@"playQueueTableColumnVisibility"];
	
	[self savePlayQueueTableColumnOrder];
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
	[self willChangeValueForKey:PlayQueueKey];
	
	for(AudioStream *stream in [[aNotification userInfo] objectForKey:AudioStreamsObjectKey])
		[_playQueue removeObject:stream];
	
	[self didChangeValueForKey:PlayQueueKey];

	[self updatePlayButtonState];
}

- (void) watchFolderAdded:(NSNotification *)aNotification
{
	[self synchronizeWithWatchFolder:[[aNotification userInfo] objectForKey:WatchFolderObjectKey]];
	[_streamTable setNeedsDisplay:YES];
}

- (void) watchFolderChanged:(NSNotification *)aNotification
{
	[self performSelector:@selector(synchronizeWithWatchFolder:) withObject:[[aNotification userInfo] objectForKey:WatchFolderObjectKey] afterDelay:0];
//	[self synchronizeWithWatchFolder:[[aNotification userInfo] objectForKey:WatchFolderObjectKey]];	
	[_streamTable setNeedsDisplay:YES];
}

@end

@implementation AudioLibrary (ScriptingAdditions)

- (unsigned) countOfTracks
{
	return [[[[CollectionManager manager] streamManager] streams] count];
}

- (AudioStream *) objectInTracksAtIndex:(NSUInteger)thisIndex
{
	return [[[[CollectionManager manager] streamManager] streams] objectAtIndex:thisIndex];	
}

- (void) getTracks:(id *)buffer range:(NSRange)range
{
	[[[[CollectionManager manager] streamManager] streams] getObjects:buffer range:range];	
}

- (AudioStream *) valueInTracksWithUniqueID:(NSNumber *)uniqueID
{
	return [[[CollectionManager manager] streamManager] streamForID:uniqueID];	
}

- (unsigned) countOfPlaylists
{
	return [[[[CollectionManager manager] playlistManager] playlists] count];
}

- (Playlist *) objectInPlaylistsAtIndex:(NSUInteger)thisIndex
{
	return [[[[CollectionManager manager] playlistManager] playlists] objectAtIndex:thisIndex];	
}

- (void) getPlaylists:(id *)buffer range:(NSRange)range
{
	[[[[CollectionManager manager] playlistManager] playlists] getObjects:buffer range:range];	
}

- (Playlist *) valueInPlaylistsWithUniqueID:(NSNumber *)uniqueID
{
	return [[[CollectionManager manager] playlistManager] playlistForID:uniqueID];	
}

- (unsigned) countOfSmartPlaylists
{
	return [[[[CollectionManager manager] smartPlaylistManager] smartPlaylists] count];
}

- (SmartPlaylist *) objectInSmartPlaylistsAtIndex:(NSUInteger)thisIndex
{
	return [[[[CollectionManager manager] smartPlaylistManager] smartPlaylists] objectAtIndex:thisIndex];	
}

- (void) getSmartPlaylists:(id *)buffer range:(NSRange)range
{
	[[[[CollectionManager manager] smartPlaylistManager] smartPlaylists] getObjects:buffer range:range];	
}

- (SmartPlaylist *) valueInSmartPlaylistsWithUniqueID:(NSNumber *)uniqueID
{
	return [[[CollectionManager manager] smartPlaylistManager] smartPlaylistForID:uniqueID];	
}

- (unsigned) countOfWatchFolders
{
	return [[[[CollectionManager manager] watchFolderManager] watchFolders] count];
}

- (WatchFolder *) objectInWatchFoldersAtIndex:(NSUInteger)thisIndex
{
	return [[[[CollectionManager manager] watchFolderManager] watchFolders] objectAtIndex:thisIndex];	
}

- (void) getWatchFolders:(id *)buffer range:(NSRange)range
{
	[[[[CollectionManager manager] watchFolderManager] watchFolders] getObjects:buffer range:range];	
}

- (WatchFolder *) valueInWatchFoldersWithUniqueID:(NSNumber *)uniqueID
{
	return [[[CollectionManager manager] watchFolderManager] watchFolderForID:uniqueID];	
}

- (NSScriptObjectSpecifier *) objectSpecifier
{
	id							appDescription		= [NSClassDescription classDescriptionForClass:[NSApplication class]];
	NSScriptObjectSpecifier		*appSpecifier		= [[NSApplication sharedApplication] objectSpecifier];
	NSScriptObjectSpecifier		*selfSpecifier		= [[NSPropertySpecifier alloc] initWithContainerClassDescription:appDescription
																								  containerSpecifier:appSpecifier 
																												 key:@"library"];
	
	return [selfSpecifier autorelease];
}

@end
