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
#include "sqlite3.h"

@class Playlist;

// ========================================
// Class that provides access to the Playlist objects contained
// in the database managed by the CollectionManager
// Provides a single, unique object for each stream
// This class does not guarantee fast access!
// This class is KVC-compliant (read only) for the key "playlists" and all
// keys supported by Playlist
// ========================================
@interface PlaylistManager : NSObject
{
	@private
	sqlite3					*_db;					// The database to use, owned by CollectionManager
	NSMutableDictionary		*_sql;					// Prepared SQL statements
	
	NSMapTable 				*_registeredPlaylists;	// Registered playlists
	NSMutableArray			*_cachedPlaylists;		// Current state of all playlists from the database
	
	NSMutableSet			*_insertedPlaylists;	// Playlists inserted during a transaction
	NSMutableSet			*_updatedPlaylists;		// Playlists updated during a transaction
	NSMutableSet			*_deletedPlaylists;		// Playlists deleted during a transaction
	
	BOOL					_updating;				// Indicates if a transaction is in progress
	
	NSArray					*_playlistKeys;			// Playlist (aggregate) keys this object supports
}

// ========================================
// Playlist support
- (NSArray *) playlists;

- (Playlist *) playlistForID:(NSNumber *)objectID;

- (BOOL) insertPlaylist:(Playlist *)playlist;
- (void) savePlaylist:(Playlist *)playlist;
- (void) deletePlaylist:(Playlist *)playlist;
- (void) revertPlaylist:(Playlist *)playlist;

@end

// ========================================
// Interfaces for other classes, not for general consumption
@class AudioStream;

@interface PlaylistManager (CollectionManagerMethods)
- (BOOL) connectedToDatabase:(sqlite3 *)db error:(NSError **)error;
- (BOOL) disconnectedFromDatabase:(NSError **)error;
- (void) reset;

- (void) beginUpdate;
- (void) processUpdate;
- (void) finishUpdate;
- (void) cancelUpdate;

- (void) playlist:(Playlist *)playlist willChangeValueForKey:(NSString *)key;
- (void) playlist:(Playlist *)playlist didChangeValueForKey:(NSString *)key;
@end

@interface PlaylistManager (PlaylistMethods)
- (void) playlist:(Playlist *)playlist willInsertStream:(AudioStream *)stream atIndex:(unsigned)index;
- (void) playlist:(Playlist *)playlist didInsertStream:(AudioStream *)stream atIndex:(unsigned)index;

- (void) playlist:(Playlist *)playlist willRemoveStreamAtIndex:(unsigned)index;
- (void) playlist:(Playlist *)playlist didRemoveStreamAtIndex:(unsigned)index;
@end
