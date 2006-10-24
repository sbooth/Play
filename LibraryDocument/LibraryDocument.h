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

@interface LibraryDocument : NSPersistentDocument
{
	IBOutlet NSTableView		*_streamTableView;
	IBOutlet NSTableView		*_playlistTableView;
	
	IBOutlet NSArrayController	*_streamArrayController;
	IBOutlet NSArrayController	*_playlistArrayController;

	IBOutlet NSButton			*_playPauseButton;

	AudioPlayer					*_player;
	
	BOOL						_randomizePlayback;
	BOOL						_loopPlayback;
	BOOL						_playButtonEnabled;
}

- (IBAction)	addFiles:(id)sender;
- (IBAction)	insertPlaylistWithSelectedStreams:(id)sender;
- (IBAction)	removeAudioStreams:(id)sender;

- (IBAction)	play:(id)sender;
- (IBAction)	playPause:(id)sender;

- (IBAction)	skipForward:(id)sender;
- (IBAction)	skipBackward:(id)sender;

- (IBAction)	skipToEnd:(id)sender;
- (IBAction)	skipToBeginning:(id)sender;

- (IBAction)	nextStream:(id)sender;
- (IBAction)	previousStream:(id)sender;

- (IBAction)	showStreamInformationSheet:(id)sender;

- (void)		playStream:(NSArray *)streams;
- (void)		streamPlaybackDidComplete;

- (void)		addFileToLibrary:(NSString *)path;
- (void)		addURLToLibrary:(NSURL *)url;

// Properties

- (BOOL)		randomizePlayback;
- (void)		setRandomizePlayback:(BOOL)randomizePlayback;

- (BOOL)		loopPlayback;
- (void)		setLoopPlayback:(BOOL)loopPlayback;

- (BOOL)		playButtonEnabled;
- (void)		setPlayButtonEnabled:(BOOL)playButtonEnabled;

@end
