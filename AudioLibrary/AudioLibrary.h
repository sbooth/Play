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

#import <Cocoa/Cocoa.h>

@class AudioStream, Playlist;
@class AudioPlayer;
@class CollectionManager;
@class AudioStreamTableView, AudioStreamArrayController;
@class BrowserOutlineView, BrowserTreeController;
@class BrowserNode, LibraryNode, PlayQueueNode;

// ========================================
// Notification Names
// ========================================
extern NSString * const		AudioStreamAddedToLibraryNotification;
extern NSString * const		AudioStreamsAddedToLibraryNotification;

extern NSString * const		AudioStreamRemovedFromLibraryNotification;
extern NSString * const		AudioStreamsRemovedFromLibraryNotification;

extern NSString * const		AudioStreamDidChangeNotification;
extern NSString * const		AudioStreamsDidChangeNotification;

extern NSString * const		AudioStreamPlaybackDidStartNotification;
extern NSString * const		AudioStreamPlaybackDidStopNotification;
extern NSString * const		AudioStreamPlaybackDidPauseNotification;
extern NSString * const		AudioStreamPlaybackDidResumeNotification;
extern NSString * const		AudioStreamPlaybackDidCompleteNotification;

extern NSString * const		PlaylistAddedToLibraryNotification;
extern NSString * const		PlaylistRemovedFromLibraryNotification;
extern NSString * const		PlaylistDidChangeNotification;

extern NSString * const		SmartPlaylistAddedToLibraryNotification;
extern NSString * const		SmartPlaylistRemovedFromLibraryNotification;
extern NSString * const		SmartPlaylistDidChangeNotification;

extern NSString * const		WatchFolderAddedToLibraryNotification;
extern NSString * const		WatchFolderRemovedFromLibraryNotification;
extern NSString * const		WatchFolderDidChangeNotification;

// ========================================
// Notification Keys
// ========================================
extern NSString * const		AudioStreamObjectKey;			// AudioStream
extern NSString * const		AudioStreamsObjectKey;			// NSArray
extern NSString * const		PlaylistObjectKey;				// Playlist
extern NSString * const		SmartPlaylistObjectKey;			// SmartPlaylist
extern NSString * const		WatchFolderObjectKey;			// WatchFolder

// ========================================
// KVC key names
// ========================================
extern NSString * const		PlayQueueKey;

// ========================================
// The main class which represents a user's audio library
// ========================================
@interface AudioLibrary : NSWindowController
{
	IBOutlet AudioStreamArrayController		*_streamController;
	IBOutlet BrowserTreeController			*_browserController;
	
	IBOutlet AudioStreamTableView			*_streamTable;
	IBOutlet BrowserOutlineView				*_browserOutlineView;
	
	IBOutlet NSButton		*_playPauseButton;
	
	IBOutlet NSImageView	*_albumArtImageView;
	IBOutlet NSDrawer		*_browserDrawer;
	
	@private
	AudioPlayer				*_player;
	
	BOOL					_randomPlayback;
	BOOL					_loopPlayback;
	BOOL					_playButtonEnabled;
	
	BOOL					_streamsAreOrdered;

	NSMutableArray			*_playQueue;	
	unsigned				_playbackIndex;
	unsigned				_nextPlaybackIndex;
	
	LibraryNode				*_libraryNode;
	PlayQueueNode			*_playQueueNode;
	
	NSMutableSet			*_streamTableVisibleColumns;
	NSMutableSet			*_streamTableHiddenColumns;
	NSMenu					*_streamTableHeaderContextMenu;
	NSArray					*_streamTableSavedSortDescriptors;	
}

// ========================================
// The standard global instance
+ (AudioLibrary *) library;

// ========================================
// Playback control
- (BOOL)		playFile:(NSString *)filename;
- (BOOL)		playFiles:(NSArray *)filenames;

- (IBAction)	play:(id)sender;
- (IBAction)	playPause:(id)sender;

- (IBAction)	stop:(id)sender;

- (IBAction)	skipForward:(id)sender;
- (IBAction)	skipBackward:(id)sender;

- (IBAction)	skipToEnd:(id)sender;
- (IBAction)	skipToBeginning:(id)sender;

- (IBAction)	playNextStream:(id)sender;
- (IBAction)	playPreviousStream:(id)sender;

// ========================================
// File addition and removal
- (IBAction)	openDocument:(id)sender;

- (BOOL)		addFile:(NSString *)filename;
- (BOOL)		addFiles:(NSArray *)filenames;
- (BOOL)		addFiles:(NSArray *)filenames inModalSession:(NSModalSession)modalSession;

- (BOOL)		removeFile:(NSString *)filename;
- (BOOL)		removeFiles:(NSArray *)filenames;

// ========================================
// Playlist manipulation
- (IBAction)	insertPlaylist:(id)sender;
- (IBAction)	insertPlaylistWithSelection:(id)sender;

- (IBAction)	insertSmartPlaylist:(id)sender;

- (IBAction)	insertWatchFolder:(id)sender;

// ========================================
// Action methods
- (IBAction)	toggleBrowser:(id)sender;

- (IBAction)	streamTableDoubleClicked:(id)sender;
- (IBAction)	browserViewDoubleClicked:(id)sender;

- (IBAction)	addSelectedStreamsToPlayQueue:(id)sender;
- (IBAction)	addCurrentStreamsToPlayQueue:(id)sender;
- (IBAction)	add10RandomStreamsToPlayQueue:(id)sender;
- (IBAction)	add25RandomStreamsToPlayQueue:(id)sender;

- (IBAction)	removeSelectedStreams:(id)sender;

- (IBAction)	jumpToLibrary:(id)sender;
- (IBAction)	jumpToNowPlaying:(id)sender;
- (IBAction)	jumpToPlayQueue:(id)sender;

- (IBAction)	showStreamInformationSheet:(id)sender;
- (IBAction)	showMetadataEditingSheet:(id)sender;
- (IBAction)	showPlaylistInformationSheet:(id)sender;

- (IBAction)	rescanMetadata:(id)sender;

// ========================================
// Current Streams
- (unsigned)		countOfPlayQueue;
- (AudioStream *)	objectInPlayQueueAtIndex:(unsigned)index;
- (void)			getPlayQueue:(id *)buffer range:(NSRange)aRange;

- (void) insertObject:(AudioStream *)stream inPlayQueueAtIndex:(unsigned)index;
- (void) removeObjectFromPlayQueueAtIndex:(unsigned)index;

// ========================================
// Browser support
- (BOOL)		selectLibraryNode;
- (BOOL)		selectPlayQueueNode;

// ========================================
// Library properties
- (BOOL)		randomPlayback;
- (void)		setRandomPlayback:(BOOL)randomPlayback;

- (BOOL)		loopPlayback;
- (void)		setLoopPlayback:(BOOL)loopPlayback;

- (BOOL)		playButtonEnabled;

- (BOOL)		canPlayNextStream;
- (BOOL)		canPlayPreviousStream;

- (BOOL)		streamsAreOrdered;

- (AudioStream *) nowPlaying;

// ========================================
// Undo/redo support
- (NSUndoManager *) undoManager;

@end
