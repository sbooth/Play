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

@class SmartPlaylist;

// ========================================
// Class that provides access to the SmartPlaylist objects contained
// in the database managed by the CollectionManager
// Provides a single, unique object for each stream
// This class does not guarantee fast access!
// This class is KVC-compliant (read only) for the key "smartPlaylists" and all
// keys supported by SmartPlaylist
// ========================================
@interface SmartPlaylistManager : NSObject
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
- (NSArray *) smartPlaylists;

- (SmartPlaylist *) smartPlaylistForID:(NSNumber *)objectID;

- (BOOL) insertSmartPlaylist:(SmartPlaylist *)playlist;
- (void) saveSmartPlaylist:(SmartPlaylist *)playlist;
- (void) deleteSmartPlaylist:(SmartPlaylist *)playlist;
- (void) revertSmartPlaylist:(SmartPlaylist *)playlist;

@end

// ========================================
// Interfaces for other classes, not for general consumption
@interface SmartPlaylistManager (CollectionManagerMethods)
- (BOOL) connectedToDatabase:(sqlite3 *)db error:(NSError **)error;
- (BOOL) disconnectedFromDatabase:(NSError **)error;
- (void) reset;

- (void) beginUpdate;
- (void) processUpdate;
- (void) finishUpdate;
- (void) cancelUpdate;

- (void) smartPlaylist:(SmartPlaylist *)playlist willChangeValueForKey:(NSString *)key;
- (void) smartPlaylist:(SmartPlaylist *)playlist didChangeValueForKey:(NSString *)key;
@end
