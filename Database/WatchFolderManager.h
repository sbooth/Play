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

@class WatchFolder;

// ========================================
// Class that provides access to the Playlist objects contained
// in the database managed by the CollectionManager
// Provides a single, unique object for each stream
// This class does not guarantee fast access!
// This class is KVC-compliant (read only) for the key "watchFolders" and all
// keys supported by WatchFolder
// ========================================
@interface WatchFolderManager : NSObject
{
	@private
	sqlite3					*_db;					// The database to use, owned by CollectionManager
	NSMutableDictionary		*_sql;					// Prepared SQL statements
	
	NSMapTable 				*_registeredFolders;	// Registered watch folders
	NSMutableArray			*_cachedFolders;		// Current state of all watch folders from the database
	
	NSMutableSet			*_insertedFolders;		// WatchFolders inserted during a transaction
	NSMutableSet			*_updatedFolders;		// WatchFolders updated during a transaction
	NSMutableSet			*_deletedFolders;		// WatchFolders deleted during a transaction
	
	BOOL					_updating;				// Indicates if a transaction is in progress
	
	NSArray					*_folderKeys;			// WatchFolders (aggregate) keys this object supports
}

// ========================================
// WatchFolder support
- (NSArray *) watchFolders;

- (WatchFolder *) watchFolderForID:(NSNumber *)objectID;

- (BOOL) insertWatchFolder:(WatchFolder *)folder;
- (void) saveWatchFolder:(WatchFolder *)folder;
- (void) deleteWatchFolder:(WatchFolder *)folder;
- (void) revertWatchFolder:(WatchFolder *)folder;

@end

// ========================================
// Interfaces for other classes, not for general consumption
@interface WatchFolderManager (CollectionManagerMethods)
- (BOOL) connectedToDatabase:(sqlite3 *)db error:(NSError **)error;
- (BOOL) disconnectedFromDatabase:(NSError **)error;
- (void) reset;

- (void) beginUpdate;
- (void) processUpdate;
- (void) finishUpdate;
- (void) cancelUpdate;

- (void) watchFolder:(WatchFolder *)folder willChangeValueForKey:(NSString *)key;
- (void) watchFolder:(WatchFolder *)folder didChangeValueForKey:(NSString *)key;
@end
