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

#import "CollectionManager.h"
#import "AudioStreamManager.h"
#import "PlaylistManager.h"
#import "WatchFolderManager.h"
#import "AudioStream.h"
#import "Playlist.h"
#import "PlaylistEntry.h"

#import "SQLiteUtilityFunctions.h"

// ========================================
// AudioStream friend methods
@interface AudioStreamManager (CollectionManagerMethods)
- (void) connectedToDatabase:(sqlite3 *)db;
- (void) disconnectedFromDatabase;
- (void) reset;

- (void) beginUpdate;
- (void) processUpdate;
- (void) finishUpdate;
- (void) cancelUpdate;

- (void) stream:(AudioStream *)stream willChangeValueForKey:(NSString *)key;
- (void) stream:(AudioStream *)stream didChangeValueForKey:(NSString *)key;
@end

// ========================================
// PlaylistManager friend methods
@interface PlaylistManager (CollectionManagerMethods)
- (void) connectedToDatabase:(sqlite3 *)db;
- (void) disconnectedFromDatabase;
- (void) reset;

- (void) beginUpdate;
- (void) processUpdate;
- (void) finishUpdate;
- (void) cancelUpdate;

- (void) playlist:(Playlist *)playlist willChangeValueForKey:(NSString *)key;
- (void) playlist:(Playlist *)playlist didChangeValueForKey:(NSString *)key;
@end

// ========================================
// WatchFolderManager friend methods
@interface WatchFolderManager (CollectionManagerMethods)
- (void) connectedToDatabase:(sqlite3 *)db;
- (void) disconnectedFromDatabase;
- (void) reset;

- (void) beginUpdate;
- (void) processUpdate;
- (void) finishUpdate;
- (void) cancelUpdate;

- (void) watchFolder:(WatchFolder *)folder willChangeValueForKey:(NSString *)key;
- (void) watchFolder:(WatchFolder *)folder didChangeValueForKey:(NSString *)key;
@end

@interface CollectionManager (Private)
- (void) createTables;
- (void) createStreamTable;
- (void) createPlaylistTable;
- (void) createPlaylistEntryTable;
- (void) createWatchFolderTable;
- (void) createTriggers;

- (void) prepareSQL;
- (void) finalizeSQL;
- (sqlite3_stmt *) preparedStatementForAction:(NSString *)action;

- (void) doBeginTransaction;
- (void) doCommitTransaction;
- (void) doRollbackTransaction;
@end

// ========================================
// The singleton instance
// ========================================
static CollectionManager *collectionManagerInstance = nil;

@implementation CollectionManager

+ (CollectionManager *) manager
{
	@synchronized(self) {
		if(nil == collectionManagerInstance) {
			// assignment not done here
			[[self alloc] init];
		}
	}
	return collectionManagerInstance;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == collectionManagerInstance) {
			// assignment and return on first allocation
            collectionManagerInstance = [super allocWithZone:zone];
			return collectionManagerInstance;
        }
    }
    return nil;
}

- (id) init
{
	if((self = [super init])) {
		_sql = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void) dealloc
{
	[_sql release], _sql = nil;
	[_streamManager release], _streamManager = nil;

	[_undoManager release], _undoManager = nil;

	[super dealloc];
}

- (id) 			copyWithZone:(NSZone *)zone			{ return self; }
- (id) 			retain								{ return self; }
- (unsigned) 	retainCount							{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void) 		release								{ /* do nothing */ }
- (id) 			autorelease							{ return self; }

- (AudioStreamManager *) streamManager
{
	@synchronized(self) {
		if(nil == _streamManager) {
			_streamManager = [[AudioStreamManager alloc] init];
		}
	}
	return _streamManager;
}

- (PlaylistManager *) playlistManager
{
	@synchronized(self) {
		if(nil == _playlistManager) {
			_playlistManager = [[PlaylistManager alloc] init];
		}
	}
	return _playlistManager;
}

- (WatchFolderManager *) watchFolderManager
{
	@synchronized(self) {
		if(nil == _watchFolderManager) {
			_watchFolderManager = [[WatchFolderManager alloc] init];
		}
	}
	return _watchFolderManager;
}

- (NSUndoManager *) undoManager
{
	@synchronized(self) {
		if(nil == _undoManager) {
			_undoManager = [[NSUndoManager alloc] init];
		}
	}
	return _undoManager;
}

- (void) reset
{
	[_streamManager reset];
	[_playlistManager reset];
	[_watchFolderManager reset];
}

#pragma mark Database connections

- (void) connectToDatabase:(NSString *)databasePath
{
	NSParameterAssert(nil != databasePath);
	
	if([self isConnectedToDatabase]) {
		[self disconnectFromDatabase];
	}
	
	int result = sqlite3_open([databasePath UTF8String], &_db);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to open the sqlite database (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);	
	
	[self createTables];
	
	[self prepareSQL];
	
	[[self streamManager] connectedToDatabase:_db];
	[[self playlistManager] connectedToDatabase:_db];
	[[self watchFolderManager] connectedToDatabase:_db];
}

- (void) disconnectFromDatabase
{
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	[[self streamManager] disconnectedFromDatabase];
	[[self playlistManager] disconnectedFromDatabase];
	[[self watchFolderManager] disconnectedFromDatabase];

	[self finalizeSQL];
	
	int result = sqlite3_close(_db);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to close the sqlite database (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);	
	_db = NULL;

	[self reset];
}

- (BOOL) isConnectedToDatabase
{
	return NULL != _db;
}

#pragma mark Mass updating (transaction) support

- (void) beginUpdate
{
	NSAssert(NO == [self updateInProgress], @"Update already in progress");

	_updating = YES;
	
	[self doBeginTransaction];
	
	[[self streamManager] beginUpdate];
	[[self playlistManager] beginUpdate];
	[[self watchFolderManager] beginUpdate];
}

- (void) finishUpdate
{
	NSAssert(YES == [self updateInProgress], @"No update in progress");
	
	[[self streamManager] processUpdate];
	[[self playlistManager] processUpdate];
	[[self watchFolderManager] processUpdate];

	[self doCommitTransaction];
	
	[[self streamManager] finishUpdate];
	[[self playlistManager] finishUpdate];
	[[self watchFolderManager] finishUpdate];
	
	_updating = NO;	
}

- (void) cancelUpdate
{
	NSAssert(YES == [self updateInProgress], @"No update in progress");
	
	[[self streamManager] cancelUpdate];
	[[self playlistManager] cancelUpdate];
	[[self watchFolderManager] cancelUpdate];

	[self doRollbackTransaction];
	_updating = NO;
}

- (BOOL) updateInProgress
{
	return _updating;	
}

#pragma mark DatabaseObject support

- (void) saveObject:(DatabaseObject *)object
{}

- (void) revertObject:(DatabaseObject *)object
{}

- (void) deleteObject:(DatabaseObject *)object
{}

// These methods are ugly right now because they rely on knowing the names of the subclasses
- (void) databaseObject:(DatabaseObject *)object willChangeValueForKey:(NSString *)key
{
	[[[self undoManager] prepareWithInvocationTarget:object] mySetValue:[object valueForKey:key] forKey:key];
	
	if([object isKindOfClass:[AudioStream class]]) {
		[[self streamManager] stream:(AudioStream *)object willChangeValueForKey:key];
	}
	else if([object isKindOfClass:[Playlist class]]) {
		[[self playlistManager] playlist:(Playlist *)object willChangeValueForKey:key];
	}
	else if([object isKindOfClass:[WatchFolder class]]) {
		[[self watchFolderManager] watchFolder:(WatchFolder *)object willChangeValueForKey:key];
	}	
}

- (void) databaseObject:(DatabaseObject *)object didChangeValueForKey:(NSString *)key
{
	if([object isKindOfClass:[AudioStream class]]) {
		[[self streamManager] stream:(AudioStream *)object didChangeValueForKey:key];
	}
	else if([object isKindOfClass:[Playlist class]]) {
		[[self playlistManager] playlist:(Playlist *)object didChangeValueForKey:key];
	}
	else if([object isKindOfClass:[WatchFolder class]]) {
		[[self watchFolderManager] watchFolder:(WatchFolder *)object didChangeValueForKey:key];
	}	
}

@end

@implementation CollectionManager (Private)

#pragma mark Table Creation

- (void) createTables
{
	[self createStreamTable];
	[self createPlaylistTable];
	[self createPlaylistEntryTable];
	[self createWatchFolderTable];
	
	[self createTriggers];
}

- (void) createStreamTable
{
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));

	sqlite3_stmt	*statement		= NULL;
	int				result			= SQLITE_OK;
	const char		*tail			= NULL;
	NSError			*error			= nil;
	NSString		*path			= [[NSBundle mainBundle] pathForResource:@"create_stream_table" ofType:@"sql"];
	NSString		*sql			= [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	
	NSAssert1(nil != sql, NSLocalizedStringFromTable(@"Unable to locate sql file \"%@\".", @"Database", @""), @"create_stream_table");
	
	result = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to prepare sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to create the streams table (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}

- (void) createPlaylistTable
{
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));

	sqlite3_stmt	*statement		= NULL;
	int				result			= SQLITE_OK;
	const char		*tail			= NULL;
	NSError			*error			= nil;
	NSString		*path			= [[NSBundle mainBundle] pathForResource:@"create_playlist_table" ofType:@"sql"];
	NSString		*sql			= [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	
	NSAssert1(nil != sql, NSLocalizedStringFromTable(@"Unable to locate sql file \"%@\".", @"Database", @""), @"create_playlist_table");
	
	result = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to prepare sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to create the playlists table (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}

- (void) createPlaylistEntryTable
{
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	sqlite3_stmt	*statement		= NULL;
	int				result			= SQLITE_OK;
	const char		*tail			= NULL;
	NSError			*error			= nil;
	NSString		*path			= [[NSBundle mainBundle] pathForResource:@"create_playlist_entry_table" ofType:@"sql"];
	NSString		*sql			= [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	
	NSAssert1(nil != sql, NSLocalizedStringFromTable(@"Unable to locate sql file \"%@\".", @"Database", @""), @"create_playlist_entry_table");
	
	result = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to prepare sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to create the playlist entry table (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}

- (void) createWatchFolderTable
{
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	sqlite3_stmt	*statement		= NULL;
	int				result			= SQLITE_OK;
	const char		*tail			= NULL;
	NSError			*error			= nil;
	NSString		*path			= [[NSBundle mainBundle] pathForResource:@"create_watch_folder_table" ofType:@"sql"];
	NSString		*sql			= [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	
	NSAssert1(nil != sql, NSLocalizedStringFromTable(@"Unable to locate sql file \"%@\".", @"Database", @""), @"create_watch_folder_table");
	
	result = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to prepare sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to create the playlist entry table (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}

- (void) createTriggers
{
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	NSArray			*triggers		= [NSArray arrayWithObjects:@"delete_playlist_trigger", @"delete_stream_trigger", nil];
	NSEnumerator	*enumerator		= [triggers objectEnumerator];
	NSString		*trigger		= nil;
	sqlite3_stmt	*statement		= NULL;
	int				result			= SQLITE_OK;
	const char		*tail			= NULL;
	NSError			*error			= nil;
	NSString		*path			= nil;
	NSString		*sql			= nil;
	
	while((trigger = [enumerator nextObject])) {
		path = [[NSBundle mainBundle] pathForResource:trigger ofType:@"sql"];
		sql = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
		
		NSAssert1(nil != sql, NSLocalizedStringFromTable(@"Unable to locate sql file \"%@\".", @"Database", @""), trigger);
		
		result = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, &tail);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to prepare sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_step(statement);
		NSAssert2(SQLITE_DONE == result, @"Unable to create the \"%@\" trigger (%@).", trigger, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_finalize(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
}

#pragma mark Prepared SQL Statements

- (void) prepareSQL
{
	NSError			*error				= nil;	
	NSString		*path				= nil;
	NSString		*sql				= nil;
	NSString		*filename			= nil;
	NSArray			*files				= [NSArray arrayWithObjects:@"begin_transaction", @"commit_transaction", @"rollback_transaction", nil];
	NSEnumerator	*enumerator			= [files objectEnumerator];
	sqlite3_stmt	*statement			= NULL;
	int				result				= SQLITE_OK;
	const char		*tail				= NULL;
	
	while((filename = [enumerator nextObject])) {
		path 	= [[NSBundle mainBundle] pathForResource:filename ofType:@"sql"];
		sql 	= [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
		NSAssert1(nil != sql, NSLocalizedStringFromTable(@"Unable to locate sql file \"%@\".", @"Database", @""), filename);
		
		result = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, &tail);
		NSAssert2(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to prepare sql statement for '%@' (%@).", @"Database", @""), filename, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		[_sql setValue:[NSNumber numberWithUnsignedLong:(unsigned long)statement] forKey:filename];
	}	
}

- (void) finalizeSQL
{
	NSEnumerator	*enumerator			= [_sql objectEnumerator];
	NSNumber		*wrappedPtr			= nil;
	sqlite3_stmt	*statement			= NULL;
	int				result				= SQLITE_OK;
	
	while((wrappedPtr = [enumerator nextObject])) {
		statement = (sqlite3_stmt *)[wrappedPtr unsignedLongValue];		
		result = sqlite3_finalize(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	
	[_sql removeAllObjects];
}

- (sqlite3_stmt *) preparedStatementForAction:(NSString *)action
{
	return (sqlite3_stmt *)[[_sql valueForKey:action] unsignedLongValue];		
}

#pragma mark Transactions

- (void) doBeginTransaction
{
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"begin_transaction"];
	int				result			= SQLITE_OK;
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to begin an SQL transaction (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}

- (void) doCommitTransaction
{
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"commit_transaction"];
	int				result			= SQLITE_OK;
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to commit the SQL transaction (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}

- (void) doRollbackTransaction
{
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"rollback_transaction"];
	int				result			= SQLITE_OK;
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to rollback the SQL transaction (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}

@end
