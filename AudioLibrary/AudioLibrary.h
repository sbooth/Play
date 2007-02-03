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

#include <sqlite3.h>

@class AudioPlayer;
@class AudioStream;
@class Playlist;

// ========================================
// Notification names
// ========================================
extern NSString * const			AudioStreamPlaybackDidStartNotification;
extern NSString * const			AudioStreamPlaybackDidStopNotification;
extern NSString * const			AudioStreamPlaybackDidPauseNotification;
extern NSString * const			AudioStreamPlaybackDidResumeNotification;

// ========================================
// Notification keys
// ========================================
extern NSString * const			AudioStreamObjectKey;

@interface AudioLibrary : NSWindowController
{
	IBOutlet NSArrayController	*_streamController;
	IBOutlet NSArrayController	*_playlistController;
	
	IBOutlet NSTableView		*_streamTable;
	IBOutlet NSTableView		*_playlistTable;
	
	IBOutlet NSButton			*_playPauseButton;
	
	IBOutlet NSButton			*_addStreamsButton;
	IBOutlet NSButton			*_removeStreamsButton;
	IBOutlet NSButton			*_streamInfoButton;
	
	IBOutlet NSButton			*_addPlaylistButton;
	IBOutlet NSButton			*_removePlaylistsButton;
	IBOutlet NSButton			*_playlistInfoButton;
	
	IBOutlet NSImageView		*_albumArtImageView;
	IBOutlet NSDrawer			*_playlistDrawer;
	
	@private
	AudioPlayer					*_player;
	AudioStream					*_nowPlaying;
	
	BOOL						_randomizePlayback;
	BOOL						_loopPlayback;
	BOOL						_playButtonEnabled;
	
	NSMutableSet				*_streamTableVisibleColumns;
	NSMutableSet				*_streamTableHiddenColumns;
	NSMenu						*_streamTableHeaderContextMenu;

	NSMutableArray				*_streams;
	NSMutableArray				*_playlists;
	
	NSMutableDictionary			*_sql;
	
	sqlite3						*_db;	
}

// ========================================
// The standard global instance
+ (AudioLibrary *)	defaultLibrary;

// ========================================
// Playback control
- (IBAction)	play:(id)sender;
- (IBAction)	playPause:(id)sender;
- (IBAction)	playSelection:(id)sender;

- (IBAction)	stop:(id)sender;

- (IBAction)	skipForward:(id)sender;
- (IBAction)	skipBackward:(id)sender;

- (IBAction)	skipToEnd:(id)sender;
- (IBAction)	skipToBeginning:(id)sender;

- (IBAction)	playNextStream:(id)sender;
- (IBAction)	playPreviousStream:(id)sender;

// ========================================
// File addition
- (IBAction)	openDocument:(id)sender;

- (BOOL)		addFile:(NSString *)filename;
- (BOOL)		addFiles:(NSArray *)filenames;

- (IBAction)	newPlaylist:(id)sender;

- (void)		audioStreamDidChange:(AudioStream *)stream;
- (void)		playlistDidChange:(Playlist *)playlist;

// ========================================
// Action methods
- (IBAction) showStreamInformationSheet:(id)sender;

// ========================================
// Properties
- (BOOL)		randomizePlayback;
- (void)		setRandomizePlayback:(BOOL)randomizePlayback;

- (BOOL)		loopPlayback;
- (void)		setLoopPlayback:(BOOL)loopPlayback;

- (BOOL)		playButtonEnabled;
- (void)		setPlayButtonEnabled:(BOOL)playButtonEnabled;

- (BOOL)		canPlayNextStream;
- (BOOL)		canPlayPreviousStream;

- (AudioStream *) nowPlaying;
- (void) setNowPlaying:(AudioStream *)nowPlaying;

// ========================================
// AudioPlayer Callbacks
- (void)		streamPlaybackDidStart:(NSURL *)url;
- (void)		streamPlaybackDidComplete;
- (void)		requestNextStream;

@end
