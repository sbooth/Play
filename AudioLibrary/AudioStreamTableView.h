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

// ========================================
// Pboard Types
// ========================================
extern NSString * const		AudioStreamPboardType;
extern NSString * const		AudioStreamTableMovedRowsPboardType;
extern NSString * const		iTunesPboardType;

@interface AudioStreamTableView : NSTableView 
{
	IBOutlet NSArrayController *_streamController;
}

// ========================================
// Action Methods
- (IBAction)	addToPlayQueue:(id)sender;

- (IBAction)	showInformationSheet:(id)sender;

- (IBAction)	resetPlayCount:(id)sender;
- (IBAction)	resetSkipCount:(id)sender;

- (IBAction)	editMetadata:(id)sender;
- (IBAction)	rescanMetadata:(id)sender;
- (IBAction)	saveMetadata:(id)sender;
- (IBAction)	clearMetadata:(id)sender;

- (IBAction)	calculateTrackReplayGain:(id)sender;
- (IBAction)	calculateTrackAndAlbumReplayGain:(id)sender;
- (IBAction)	clearReplayGain:(id)sender;

- (IBAction)	determinePUIDs:(id)sender;

- (IBAction)	lookupTrackInMusicBrainz:(id)sender;
- (IBAction)	searchMusicBrainzForMatchingTracks:(id)sender;

- (IBAction)	remove:(id)sender;

- (IBAction)	browseTracksWithSameArtist:(id)sender;
- (IBAction)	browseTracksWithSameAlbum:(id)sender;
- (IBAction)	browseTracksWithSameComposer:(id)sender;
- (IBAction)	browseTracksWithSameGenre:(id)sender;

- (IBAction)	addTracksWithSameArtistToPlayQueue:(id)sender;
- (IBAction)	addTracksWithSameAlbumToPlayQueue:(id)sender;
- (IBAction)	addTracksWithSameComposerToPlayQueue:(id)sender;
- (IBAction)	addTracksWithSameGenreToPlayQueue:(id)sender;

- (IBAction)	openWithFinder:(id)sender;
- (IBAction)	revealInFinder:(id)sender;

- (IBAction)	convert:(id)sender;
- (IBAction)	convertWithMax:(id)sender;

- (IBAction)	editWithTag:(id)sender;

- (IBAction)	openWith:(id)sender;

- (IBAction)	insertPlaylistWithSelection:(id)sender;

- (IBAction)	doubleClickAction:(id)sender;

// ========================================
// Message displayed when the table is empty
- (NSString *)	emptyMessage;

@end
