/*
 *  $Id$
 *
 *  Copyright (C) 2006 Stephen F. Booth <me@sbooth.org>
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
#import "AudioPlayer.h"
#import "UKKQueue.h"

@class Library;

@interface LibraryDocument : NSPersistentDocument
{
	IBOutlet NSTableView		*_streamTableView;
	IBOutlet NSTableView		*_playlistTableView;
	
	IBOutlet NSArrayController	*_streamArrayController;
	IBOutlet NSArrayController	*_playlistArrayController;

	IBOutlet NSButton			*_playPauseButton;
	
	IBOutlet NSButton			*_addStreamsButton;
	IBOutlet NSButton			*_removeStreamsButton;
	IBOutlet NSButton			*_streamInfoButton;

	IBOutlet NSButton			*_addPlaylistButton;
	IBOutlet NSButton			*_removePlaylistsButton;
	IBOutlet NSButton			*_playlistInfoButton;
	
	IBOutlet NSImageView		*_albumArtImageView;
	IBOutlet NSDrawer			*_playlistDrawer;

	AudioPlayer					*_player;
	
	BOOL						_randomizePlayback;
	BOOL						_loopPlayback;
	BOOL						_playButtonEnabled;
	
	NSMutableSet				*_streamTableVisibleColumns;
	NSMutableSet				*_streamTableHiddenColumns;
	NSMenu						*_streamTableHeaderContextMenu;
	
	NSThread					*_libraryThread;
	
	UKKQueue					*_kq;
	
	Library						*_libraryObject;
}

// ========================================
// Action methods


- (IBAction)	showStreamInformationSheet:(id)sender;

// ========================================
// Playback control
- (IBAction)	play:(id)sender;
- (IBAction)	playPause:(id)sender;
- (IBAction)	playSelection:(id)sender;

- (IBAction)	skipForward:(id)sender;
- (IBAction)	skipBackward:(id)sender;

- (IBAction)	skipToEnd:(id)sender;
- (IBAction)	skipToBeginning:(id)sender;

- (IBAction)	playNextStream:(id)sender;
- (IBAction)	playPreviousStream:(id)sender;

// ========================================
// File addition
- (IBAction)	addFiles:(id)sender;

- (void)		addFileToLibrary:(NSString *)path;
- (void)		addURLToLibrary:(NSURL *)URL;

- (void)		addFilesToLibrary:(NSArray *)filenames;
- (void)		addURLsToLibrary:(NSArray *)URLs;

// ========================================
// File removal
- (IBAction)	removeAudioStreams:(id)sender;

- (void)		removeFileFromLibrary:(NSString *)path;
- (void)		removeURLFromLibrary:(NSURL *)URL;

- (void)		removeFilesFromLibrary:(NSArray *)filenames;
- (void)		removeURLsFromLibrary:(NSArray *)URLs;

// ========================================
// Playlists
- (IBAction)	insertStaticPlaylist:(id)sender;
- (IBAction)	insertDynamicPlaylist:(id)sender;
- (IBAction)	insertFolderPlaylist:(id)sender;
- (IBAction)	insertPlaylistWithSelectedStreams:(id)sender;

- (IBAction)	nextPlaylist:(id)sender;
- (IBAction)	previousPlaylist:(id)sender;

- (IBAction)	showPlaylistInformationSheet:(id)sender;

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

// ========================================
// Callbacks
- (void)		streamPlaybackDidStart:(NSURL *)url;
- (void)		streamPlaybackDidComplete;
- (void)		requestNextStream;

@end
