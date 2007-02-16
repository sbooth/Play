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
#import "AudioStream.h"
#import "Playlist.h"
#import "PlaylistEntry.h"

#import "SQLiteUtilityFunctions.h"

@interface AudioStreamManager (CollectionManagerMethods)
- (void) connectedToDatabase:(sqlite3 *)db;
- (void) disconnectedFromDatabase;
- (void) reset;

- (void) beginUpdate;
- (void) finishUpdate;
- (void) cancelUpdate;

- (void) stream:(AudioStream *)stream willChangeValueForKey:(NSString *)key;
- (void) stream:(AudioStream *)stream didChangeValueForKey:(NSString *)key;
@end

@interface CollectionManager (Private)
- (void) createTables;
- (void) createStreamTable;
- (void) createPlaylistTable;
- (void) createPlaylistEntryTable;
- (void) createTriggers;

- (void) prepareSQL;
- (void) finalizeSQL;
- (sqlite3_stmt *) preparedStatementForAction:(NSString *)action;

- (void) doBeginTransaction;
- (void) doCommitTransaction;
- (void) doRollbackTransaction;

/*- (Playlist *) loadPlaylist:(sqlite3_stmt *)statement;
- (PlaylistEntry *) loadPlaylistEntry:(sqlite3_stmt *)statement;

- (BOOL) doInsertPlaylist:(Playlist *)playlist;
- (void) doUpdatePlaylist:(Playlist *)playlist;
- (void) doDeletePlaylist:(Playlist *)playlist;

- (void) bindPlaylistValues:(Playlist *)playlist toStatement:(sqlite3_stmt *)statement;
*/
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
			collectionManagerInstance = [[self alloc] init];
		}
	}
	return collectionManagerInstance;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == collectionManagerInstance) {
            return [super allocWithZone:zone];
        }
    }
    return collectionManagerInstance;
}

- (id) init
{
	if((self = [super init])) {
		
//		_playlists			= NSCreateMapTable(NSIntMapKeyCallBacks, NSObjectMapValueCallBacks, 512);
//		_playlistEntries	= NSCreateMapTable(NSIntMapKeyCallBacks, NSObjectMapValueCallBacks, 1024);
		
		_sql			= [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void) dealloc
{
//	NSFreeMapTable(_playlists), _playlists = NULL;
//	NSFreeMapTable(_playlistEntries), _playlistEntries = NULL;
	
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

- (void) reset
{
	[_streamManager reset];
//	NSResetMapTable(_playlists);
//	NSResetMapTable(_playlistEntries);
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
}

- (void) disconnectFromDatabase
{
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	[[self streamManager] disconnectedFromDatabase];

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
	[_streamManager beginUpdate];
}

- (void) finishUpdate
{
	NSAssert(YES == [self updateInProgress], @"No update in progress");
	
	[_streamManager finishUpdate];
	[self doCommitTransaction];
	_updating = NO;	
}

- (void) cancelUpdate
{
	NSAssert(YES == [self updateInProgress], @"No update in progress");
	
	[_streamManager cancelUpdate];
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

// These methods are ugly right now because it relies on knowing the names of the subclasses
- (void) databaseObject:(DatabaseObject *)object willChangeValueForKey:(NSString *)key
{
	if([object isKindOfClass:[AudioStream class]]) {
		[[self streamManager] stream:(AudioStream *)object willChangeValueForKey:key];
	}
}

- (void) databaseObject:(DatabaseObject *)object didChangeValueForKey:(NSString *)key
{
	if([object isKindOfClass:[AudioStream class]]) {
		[[self streamManager] stream:(AudioStream *)object didChangeValueForKey:key];
	}
/*	else if([object isKindOfClass:[Playlist class]]) {
		[self savePlaylist:(Playlist *)object];
	}
	else if([object isKindOfClass:[PlaylistEntry class]]) {
		[self savePlaylistEntry:(PlaylistEntry *)object];
	}
	*/
}

/*
- (NSArray *) streamsForPlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);

	NSMutableArray	*streams		= [[NSMutableArray alloc] init];
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"select_streams_for_playlist"];
	int				result			= SQLITE_OK;
	AudioStream		*stream			= nil;
				
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":playlist_id"), [[playlist valueForKey:ObjectIDKey] unsignedIntValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);

	while(SQLITE_ROW == (result = sqlite3_step(statement))) {
		stream = [self loadStream:statement];
		[streams addObject:stream];
	}
	
	NSAssert1(SQLITE_DONE == result, @"Error while fetching streams (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Loaded %i streams in %f seconds (%i per second)", [streams count], elapsed, (double)[streams count] / elapsed);
#endif
	
	return [streams autorelease];
}
*/
#pragma mark Playlist support

// ========================================
// Retrieve all playlists from the database

/*- (NSArray *) allPlaylists
{
	NSMutableArray	*playlists		= [[NSMutableArray alloc] init];
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"select_all_playlists"];
	int				result			= SQLITE_OK;
	Playlist		*playlist		= nil;
				
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	while(SQLITE_ROW == (result = sqlite3_step(statement))) {
		playlist = [self loadPlaylist:statement];
		[playlists addObject:playlist];
	}
	
	NSAssert1(SQLITE_DONE == result, @"Error while fetching streams (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Loaded %i playlists in %f seconds (%i per second)", [playlists count], elapsed, (double)[playlists count] / elapsed);
#endif
	
	return [playlists autorelease];
}

- (Playlist *) playlistForID:(NSNumber *)objectID
{
	NSParameterAssert(nil != objectID);
	
	Playlist *playlist = (Playlist *)NSMapGet(_playlists, (void *)[objectID unsignedIntValue]);
	if(nil != playlist) {
		return playlist;
	}
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"select_playlist_by_id"];
	int				result			= SQLITE_OK;
				
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":id"), [objectID unsignedIntValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	while(SQLITE_ROW == (result = sqlite3_step(statement))) {
		playlist = [self loadPlaylist:statement];
	}
	
	NSAssert1(SQLITE_DONE == result, @"Error while fetching streams (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Loaded playlist in %f seconds", elapsed);
#endif
	
	return playlist;
}

- (BOOL) insertPlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	
	return [self doInsertPlaylist:playlist];
}

- (void) savePlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	
	if(NO == [playlist hasChanges]) {
		return;
	}
	
	[self doUpdatePlaylist:playlist];	
	[playlist didSave];
}

- (void) deletePlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	
	[self doDeletePlaylist:playlist];	
}

- (void) revertPlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	
	[playlist revert];
}

- (void) addStream:(AudioStream *)stream toPlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != stream);
	NSParameterAssert(nil != playlist);
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"insert_stream_in_playlist"];
	int				result			= SQLITE_OK;
	id				value			= nil;
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif

	if(nil != (value = [playlist valueForKey:ObjectIDKey])) {
		result = sqlite3_bind_int(statement, 1, [value unsignedIntValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}

	if(nil != (value = [stream valueForKey:ObjectIDKey])) {
		result = sqlite3_bind_int(statement, 2, [value unsignedIntValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	
	result = sqlite3_step(statement);
	NSAssert2(SQLITE_DONE == result, @"Unable to insert a record for %@ (%@).", playlist, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_clear_bindings(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Playlist insertion time = %f seconds", elapsed);
#endif
}

#pragma mark PlaylistEntry Support

- (NSArray *) playlistEntriesForPlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	
	NSMutableArray	*entries		= [[NSMutableArray alloc] init];
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"select_playlist_entries_for_playlist"];
	int				result			= SQLITE_OK;
	PlaylistEntry	*entry			= nil;
				
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":playlist_id"), [[playlist valueForKey:ObjectIDKey] unsignedIntValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	while(SQLITE_ROW == (result = sqlite3_step(statement))) {
		entry = [self loadPlaylistEntry:statement];
		[entries addObject:entry];
	}
	
	NSAssert1(SQLITE_DONE == result, @"Error while fetching streams (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Loaded %i playlist entries in %f seconds (%i per second)", [entries count], elapsed, (double)[entries count] / elapsed);
#endif
	
	return [entries autorelease];
}

- (PlaylistEntry *) playlistEntryForID:(NSNumber *)objectID
{
	NSParameterAssert(nil != objectID);
	
	PlaylistEntry *entry = (PlaylistEntry *)NSMapGet(_playlistEntries, (void *)[objectID unsignedIntValue]);
	if(nil != entry) {
		return entry;
	}
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"select_playlist_entry_by_id"];
	int				result			= SQLITE_OK;
				
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":id"), [objectID unsignedIntValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	while(SQLITE_ROW == (result = sqlite3_step(statement))) {
		entry = [self loadPlaylistEntry:statement];
	}
	
	NSAssert1(SQLITE_DONE == result, @"Error while fetching entry (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Loaded playlist entry in %f seconds", elapsed);
#endif
	
	return entry;
}
*/

@end

@implementation CollectionManager (Private)

#pragma mark Table Creation

- (void) createTables
{
	[self createStreamTable];
	[self createPlaylistTable];
	[self createPlaylistEntryTable];
	
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

#pragma mark Object Loading

/*- (Playlist *) loadPlaylist:(sqlite3_stmt *)statement
{
	const char		*rawText		= NULL;
	NSString		*text			= nil;
	Playlist		*playlist		= nil;
	unsigned		objectID;
	
	// The ID should never be NULL
	NSAssert(SQLITE_NULL != sqlite3_column_type(statement, 0), @"No ID found for playlist");
	objectID = sqlite3_column_int(statement, 0);
	
	playlist = (Playlist *)NSMapGet(_playlists, (void *)objectID);
	if(nil != playlist) {
		return playlist;
	}
	
	playlist = [[Playlist alloc] initWithCollectionManager:self];
	
	// Playlist ID and name
	[playlist initValue:[NSNumber numberWithInt:objectID] forKey:ObjectIDKey];
	if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 1))) {
		text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
		[playlist initValue:text forKey:PlaylistNameKey];
	}
	
	// Statistics
	if(SQLITE_NULL != sqlite3_column_type(statement, 2)) {
		[playlist initValue:[NSDate dateWithTimeIntervalSinceReferenceDate:sqlite3_column_double(statement, 2)] forKey:StatisticsDateCreatedKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 3)) {
		[playlist initValue:[NSDate dateWithTimeIntervalSinceReferenceDate:sqlite3_column_double(statement, 3)] forKey:StatisticsFirstPlayedDateKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 4)) {
		[playlist initValue:[NSDate dateWithTimeIntervalSinceReferenceDate:sqlite3_column_double(statement, 4)] forKey:StatisticsLastPlayedDateKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 5)) {
		[playlist initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 5)] forKey:StatisticsPlayCountKey];
	}
		
	// Register the object	
	NSMapInsert(_playlists, (void *)objectID, (void *)playlist);
	
	return [playlist autorelease];
}

- (PlaylistEntry *) loadPlaylistEntry:(sqlite3_stmt *)statement
{
	PlaylistEntry	*entry			= nil;
	unsigned		objectID;
	
	// The ID should never be NULL
	NSAssert(SQLITE_NULL != sqlite3_column_type(statement, 0), @"No ID found for playlist");
	objectID = sqlite3_column_int(statement, 0);
	
	entry = (PlaylistEntry *)NSMapGet(_playlistEntries, (void *)objectID);
	if(nil != entry) {
		return entry;
	}
	
	entry = [[PlaylistEntry alloc] initWithCollectionManager:self];
	
	// Playlist ID and name
	[entry initValue:[NSNumber numberWithInt:objectID] forKey:ObjectIDKey];
	
	// Statistics
	if(SQLITE_NULL != sqlite3_column_type(statement, 1)) {
		[entry initValue:[NSNumber numberWithUnsignedInt:sqlite3_column_int(statement, 1)] forKey:PlaylistObjectIDKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 2)) {
		[entry initValue:[NSNumber numberWithUnsignedInt:sqlite3_column_int(statement, 2)] forKey:AudioStreamObjectIDKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 3)) {
		[entry initValue:[NSNumber numberWithUnsignedInt:sqlite3_column_int(statement, 3)] forKey:PlaylistEntryPositionKey];
	}
	
	// Register the object	
	NSMapInsert(_playlistEntries, (void *)objectID, (void *)entry);
	
	return [entry autorelease];
}
*/

/*#pragma mark Playlists

- (BOOL) doInsertPlaylist:(Playlist *)playlist
{
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"insert_playlist"];
	int				result			= SQLITE_OK;
	id				value			= nil;
	BOOL			success			= YES;
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	@try {
		// Playlist ID and name
		if(nil != (value = [playlist valueForKey:PlaylistNameKey])) {
			result = sqlite3_bind_text(statement, 1, [value UTF8String], -1, SQLITE_TRANSIENT);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		
		// Statistics
		if(nil != (value = [playlist valueForKey:StatisticsDateCreatedKey])) {
			result = sqlite3_bind_double(statement, 2, [value timeIntervalSinceReferenceDate]);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [playlist valueForKey:StatisticsPlayCountKey])) {
			result = sqlite3_bind_int(statement, 5, [value intValue]);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		
		result = sqlite3_step(statement);
		NSAssert2(SQLITE_DONE == result, @"Unable to insert a record for %@ (%@).", playlist, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		[playlist initValue:[NSNumber numberWithInt:sqlite3_last_insert_rowid(_db)] forKey:ObjectIDKey];
		
		result = sqlite3_reset(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_clear_bindings(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	
	@catch(NSException *exception) {
		NSLog(@"%@",exception);
		
		// Ignore the result code, because it will always be an error in this case
		// (sqlite3_reset returns the result of the previous operation and we are in a catch block)
		/*result = sqlite3_reset(statement);
		
		success = NO;
	}
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Playlist insertion time = %f seconds", elapsed);
#endif
	
	return success;
}

- (void) doUpdatePlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	//	NSParameterAssert(nil != [stream valueForKey:ObjectIDKey]);
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"update_playlist"];
	int				result			= SQLITE_OK;
	unsigned		objectID		= [[playlist valueForKey:ObjectIDKey] unsignedIntValue];
	NSDictionary	*changes		= [playlist changes];
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":id"), objectID);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	[self bindPlaylistValues:playlist toStatement:statement];
	
	result = sqlite3_step(statement);
	NSAssert2(SQLITE_DONE == result, @"Unable to update the record for %@ (%@).", playlist, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_clear_bindings(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Stream update time = %f seconds", elapsed);
#endif
	
	// Reset the object with the stored values
	[playlist initValuesForKeysWithDictionary:changes];
}

- (void) doDeletePlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	//	NSParameterAssert(nil != [playlist valueForKey:ObjectIDKey]);
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"delete_playlist"];
	int				result			= SQLITE_OK;
	unsigned		objectID		= [[playlist valueForKey:ObjectIDKey] unsignedIntValue];
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":id"), objectID);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert2(SQLITE_DONE == result, @"Unable to delete the record for %@ (%@).", playlist, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_clear_bindings(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Stream delete time = %f seconds", elapsed);
#endif
	
	// Deregister the object
	NSMapRemove(_playlists, (void *)objectID);
}

- (void) bindPlaylistValues:(Playlist *)playlist toStatement:(sqlite3_stmt *)statement
{
	NSParameterAssert(nil != playlist);
	NSParameterAssert(NULL != statement);
	
	int				result			= SQLITE_OK;
	id				value			= nil;
	
	// Location
	if(nil != (value = [playlist valueForKey:PlaylistNameKey])) {
		result = sqlite3_bind_text(statement, sqlite3_bind_parameter_index(statement, ":name"), [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	
	// Statistics
	if(nil != (value = [playlist valueForKey:StatisticsDateCreatedKey])) {
		result = sqlite3_bind_double(statement, sqlite3_bind_parameter_index(statement, ":date_created"), [value timeIntervalSinceReferenceDate]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [playlist valueForKey:StatisticsFirstPlayedDateKey])) {
		result = sqlite3_bind_double(statement, sqlite3_bind_parameter_index(statement, ":first_played_date"), [value timeIntervalSinceReferenceDate]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [playlist valueForKey:StatisticsLastPlayedDateKey])) {
		result = sqlite3_bind_double(statement, sqlite3_bind_parameter_index(statement, ":last_played_date"), [value timeIntervalSinceReferenceDate]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [playlist valueForKey:StatisticsPlayCountKey])) {
		result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":play_count"), [value intValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
}
*/
@end