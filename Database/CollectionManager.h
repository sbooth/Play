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

@class AudioStreamManager;
@class PlaylistManager;
@class WatchFolderManager;
@class DatabaseObject;
@class AudioStream;

@interface CollectionManager : NSObject
{
	@private
	sqlite3					*_db;				// The database
	NSMutableDictionary		*_sql;				// Prepared SQL statements
	
	AudioStreamManager		*_streamManager;
	PlaylistManager			*_playlistManager;
	WatchFolderManager		*_watchFolderManager;
	
	NSUndoManager			*_undoManager;		// For undo/redo management
	
	BOOL					_updating;
}

// ========================================
// The shared instances
+ (CollectionManager *) 	manager;

// ========================================
// Access to the collection
- (AudioStreamManager *) 	streamManager;
- (PlaylistManager *) 		playlistManager;
- (WatchFolderManager *) 	watchFolderManager;

// ========================================
// Database connection
- (void) connectToDatabase:(NSString *)databasePath;
- (void) disconnectFromDatabase;
- (BOOL) isConnectedToDatabase;

// ========================================
// Mass updating (transaction) support
- (void) beginUpdate;
- (void) finishUpdate;
- (void) cancelUpdate;

- (BOOL) updateInProgress;

// ========================================
// Generic DatabaseObject support
- (void) saveObject:(DatabaseObject *)object;
- (void) deleteObject:(DatabaseObject *)object;
- (void) revertObject:(DatabaseObject *)object;

- (void) databaseObject:(DatabaseObject *)object willChangeValueForKey:(NSString *)key;
- (void) databaseObject:(DatabaseObject *)object didChangeValueForKey:(NSString *)key;

// ========================================
// UndoManager for tracking changes to registered objects
- (NSUndoManager *) undoManager;

@end
