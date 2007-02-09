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

#import "DatabaseContext.h"
#import "AudioStream.h"
#import "Playlist.h"
#import "PlaylistEntry.h"

@interface DatabaseContext (Private)
- (void) createTables;
- (void) createStreamTable;
- (void) createPlaylistTable;
- (void) createPlaylistEntryTable;
- (void) createTriggers;

- (void) prepareSQL;
- (void) finalizeSQL;
- (sqlite3_stmt *) preparedStatementForAction:(NSString *)action;

- (void) beginTransaction;
- (void) commitTransaction;
- (void) rollbackTransaction;

- (AudioStream *) loadStream:(sqlite3_stmt *)statement;
- (Playlist *) loadPlaylist:(sqlite3_stmt *)statement;
- (PlaylistEntry *) loadPlaylistEntry:(sqlite3_stmt *)statement;

- (BOOL) doInsertStream:(AudioStream *)stream;
- (void) doUpdateStream:(AudioStream *)stream;
- (void) doDeleteStream:(AudioStream *)stream;

- (void) bindStreamValues:(AudioStream *)stream toStatement:(sqlite3_stmt *)statement;

- (BOOL) doInsertPlaylist:(Playlist *)playlist;
- (void) doUpdatePlaylist:(Playlist *)playlist;
- (void) doDeletePlaylist:(Playlist *)playlist;

- (void) bindPlaylistValues:(Playlist *)playlist toStatement:(sqlite3_stmt *)statement;


@end

@implementation DatabaseContext

- (id) init
{
	if((self = [super init])) {
		
		_streams			= NSCreateMapTable(NSIntMapKeyCallBacks, NSObjectMapValueCallBacks, 4096);
		_playlists			= NSCreateMapTable(NSIntMapKeyCallBacks, NSObjectMapValueCallBacks, 512);
		_playlistEntries	= NSCreateMapTable(NSIntMapKeyCallBacks, NSObjectMapValueCallBacks, 1024);
		
		_sql				= [[NSMutableDictionary alloc] init];
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	NSFreeMapTable(_streams), _streams = NULL;
	NSFreeMapTable(_playlists), _playlists = NULL;
	NSFreeMapTable(_playlistEntries), _playlistEntries = NULL;
	
	[_sql release], _sql = nil;

	[_undoManager release], _undoManager = nil;

	[super dealloc];
}

- (void) reset
{
	NSResetMapTable(_streams);
	NSResetMapTable(_playlists);
	NSResetMapTable(_playlistEntries);
}

- (NSUndoManager *) undoManager
{
	if(nil == _undoManager) {
		_undoManager = [[NSUndoManager alloc] init];
	}
	return _undoManager;
}

#pragma mark Database connections

- (void) connectToDatabase:(NSString *)databasePath
{
	NSParameterAssert(nil != databasePath);
	
	[self reset];
	
	int result = sqlite3_open([databasePath UTF8String], &_db);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to open the sqlite database (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);	
	
	[self createTables];
	
	[self prepareSQL];
}

- (void) disconnectFromDatabase
{
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	[self finalizeSQL];
	
	int result = sqlite3_close(_db);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to close the sqlite database (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);	
	_db = NULL;	
}

- (BOOL) isConnectedToDatabase
{
	return NULL != _db;
}

#pragma mark Action methods

- (IBAction) undo:(id)sender
{
	
}

- (IBAction) redo:(id)sender
{
	
}

- (IBAction) save:(id)sender
{
}

- (IBAction) revert:(id)sender
{
}

// This method is ugly right now because it relies on knowing the names of the subclasses
- (void) databaseObject:(DatabaseObject *)object didChangeForKey:(NSString *)key
{
	if([object isKindOfClass:[AudioStream class]]) {
		[self saveStream:(AudioStream *)object];
	}
	else if([object isKindOfClass:[Playlist class]]) {
		[self savePlaylist:(Playlist *)object];
	}
	else if([object isKindOfClass:[PlaylistEntry class]]) {
		[self savePlaylistEntry:(PlaylistEntry *)object];
	}
}

#pragma mark AudioStream support

// ========================================
// Retrieve all streams from the database

- (NSArray *) allStreams
{
	NSMutableArray	*streams		= [[NSMutableArray alloc] init];
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"select_all_streams"];
	int				result			= SQLITE_OK;
	AudioStream		*stream			= nil;
				
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));

#if SQL_DEBUG
	clock_t start = clock();
#endif

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

- (AudioStream *) streamForID:(NSNumber *)objectID
{
	NSParameterAssert(nil != objectID);
	
	AudioStream *stream = (AudioStream *)NSMapGet(_streams, (void *)[objectID unsignedIntValue]);
	if(nil != stream) {
		return stream;
	}
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"select_stream_by_id"];
	int				result			= SQLITE_OK;
				
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":id"), [objectID unsignedIntValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	while(SQLITE_ROW == (result = sqlite3_step(statement))) {
		stream = [self loadStream:statement];
	}
	
	NSAssert1(SQLITE_DONE == result, @"Error while fetching streams (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Loaded stream in %f seconds", elapsed);
#endif
	
	return stream;
}

/*- (NSArray *) streamsForIDs:(NSArray *)objectIDs
{
	NSParameterAssert(nil != objectIDs);
	NSParameterAssert(0 != [objectIDs count]);

	NSMutableArray	*streams		= [[NSMutableArray alloc] init];
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"select_streams_by_id"];
	int				result			= SQLITE_OK;
	AudioStream		*stream			= nil;
				
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	result = sqlite3_bind_text(statement, sqlite3_bind_parameter_index(statement, ":ids"), [[objectIDs componentsJoinedByString:@", "] UTF8String], -1, SQLITE_TRANSIENT);
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
}*/

- (BOOL) insertStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);

	return [self doInsertStream:stream];
}

- (void) saveStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	
	if(NO == [stream hasChanges]) {
		return;
	}
	
	[self doUpdateStream:stream];	
	[stream didSave];
}

- (void) deleteStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);

	[self doDeleteStream:stream];	
}

- (void) revertStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	
	[stream revert];
}

#pragma mark Playlist support

// ========================================
// Retrieve all playlists from the database

- (NSArray *) allPlaylists
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
	
/*#if SQL_DEBUG
	clock_t start = clock();
#endif*/
	
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
	
/*#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Playlist insertion time = %f seconds", elapsed);
#endif*/
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

@end

@implementation DatabaseContext (Private)

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
	NSArray			*files				= [NSArray arrayWithObjects:@"begin_transaction", @"commit_transaction", @"rollback_transaction", 
		@"select_all_streams", @"select_streams_for_playlist", @"select_stream_by_id", @"select_streams_by_id", @"insert_stream", @"insert_stream_in_playlist", @"update_stream", @"delete_stream", 
		@"select_all_playlists", @"select_playlist_by_id", @"insert_playlist", @"update_playlist", @"delete_playlist", 
		@"select_playlist_entries_for_playlist", @"select_playlist_entry_by_id", nil];
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

- (void) beginTransaction
{
	if(_hasActiveTransaction) {
		return;
	}
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"begin_transaction"];
	int				result			= SQLITE_OK;
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to begin an SQL transaction (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);

	_hasActiveTransaction = YES;
}

- (void) commitTransaction
{
	if(NO == _hasActiveTransaction) {
		return;
	}
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"commit_transaction"];
	int				result			= SQLITE_OK;
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to commit the SQL transaction (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);

	_hasActiveTransaction = NO;
}

- (void) rollbackTransaction
{
	if(NO == _hasActiveTransaction) {
		return;
	}

	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"rollback_transaction"];
	int				result			= SQLITE_OK;
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to rollback the SQL transaction (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);

	_hasActiveTransaction = NO;
}

#pragma mark Object Loading

- (AudioStream *) loadStream:(sqlite3_stmt *)statement
{
	const char		*rawText		= NULL;
	NSString		*text			= nil;
	AudioStream		*stream			= nil;
	unsigned		objectID;
	
	// The ID should never be NULL
	NSAssert(SQLITE_NULL != sqlite3_column_type(statement, 0), @"No ID found for stream");
	objectID = sqlite3_column_int(statement, 0);
	
	stream = (AudioStream *)NSMapGet(_streams, (void *)objectID);
	if(nil != stream) {
		return stream;
	}
	
	stream = [[AudioStream alloc] initWithDatabaseContext:self];
	
	// Stream ID and location
	[stream initValue:[NSNumber numberWithInt:objectID] forKey:ObjectIDKey];
	if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 1))) {
		text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
		[stream initValue:[NSURL URLWithString:text] forKey:StreamURLKey];
	}
	
	// Statistics
	if(SQLITE_NULL != sqlite3_column_type(statement, 2)) {
		[stream initValue:[NSDate dateWithTimeIntervalSinceReferenceDate:sqlite3_column_double(statement, 2)] forKey:StatisticsDateAddedKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 3)) {
		[stream initValue:[NSDate dateWithTimeIntervalSinceReferenceDate:sqlite3_column_double(statement, 3)] forKey:StatisticsFirstPlayedDateKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 4)) {
		[stream initValue:[NSDate dateWithTimeIntervalSinceReferenceDate:sqlite3_column_double(statement, 4)] forKey:StatisticsLastPlayedDateKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 5)) {
		[stream initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 5)] forKey:StatisticsPlayCountKey];
	}
	
	// Metadata
	if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 6))) {
		text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
		[stream initValue:text forKey:MetadataTitleKey];
	}
	if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 7))) {
		text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
		[stream initValue:text forKey:MetadataAlbumTitleKey];
	}
	if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 8))) {
		text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
		[stream initValue:text forKey:MetadataArtistKey];
	}
	if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 9))) {
		text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
		[stream initValue:text forKey:MetadataAlbumArtistKey];
	}
	if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 10))) {
		text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
		[stream initValue:text forKey:MetadataGenreKey];
	}
	if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 11))) {
		text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
		[stream initValue:text forKey:MetadataComposerKey];
	}
	if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 12))) {
		text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
		[stream initValue:text forKey:MetadataDateKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 13)) {
		[stream initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 13)] forKey:MetadataCompilationKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 14)) {
		[stream initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 14)] forKey:MetadataTrackNumberKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 15)) {
		[stream initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 15)] forKey:MetadataTrackTotalKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 16)) {
		[stream initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 16)] forKey:MetadataDiscNumberKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 17)) {
		[stream initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 17)] forKey:MetadataDiscTotalKey];
	}
	if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 18))) {
		text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
		[stream initValue:text forKey:MetadataCommentKey];
	}
	if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 19))) {
		text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
		[stream initValue:text forKey:MetadataISRCKey];
	}
	if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 20))) {
		text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
		[stream initValue:text forKey:MetadataMCNKey];
	}
	
	// Properties
	if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 21))) {
		text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
		[stream initValue:text forKey:PropertiesFileTypeKey];
	}
	if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 22))) {
		text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
		[stream initValue:text forKey:PropertiesFormatTypeKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 23)) {
		[stream initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 23)] forKey:PropertiesBitsPerChannelKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 24)) {
		[stream initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 24)] forKey:PropertiesChannelsPerFrameKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 25)) {
		[stream initValue:[NSNumber numberWithDouble:sqlite3_column_double(statement, 25)] forKey:PropertiesSampleRateKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 26)) {
		[stream initValue:[NSNumber numberWithLongLong:sqlite3_column_int64(statement, 26)] forKey:PropertiesTotalFramesKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 27)) {
		[stream initValue:[NSNumber numberWithDouble:sqlite3_column_double(statement, 27)] forKey:PropertiesDurationKey];
	}
	if(SQLITE_NULL != sqlite3_column_type(statement, 28)) {
		[stream initValue:[NSNumber numberWithDouble:sqlite3_column_double(statement, 28)] forKey:PropertiesBitrateKey];
	}
	
	// Register the object	
	NSMapInsert(_streams, (void *)objectID, (void *)stream);
	
	return [stream autorelease];
}

- (Playlist *) loadPlaylist:(sqlite3_stmt *)statement
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
	
	playlist = [[Playlist alloc] initWithDatabaseContext:self];
	
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
	
	entry = [[PlaylistEntry alloc] initWithDatabaseContext:self];
	
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

#pragma mark Streams

- (BOOL) doInsertStream:(AudioStream *)stream
{
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"insert_stream"];
	int				result			= SQLITE_OK;
	id				value			= nil;
	BOOL			success			= YES;
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
/*#if SQL_DEBUG
	clock_t start = clock();
#endif*/
	
	@try {
		// Stream ID and location
		result = sqlite3_bind_text(statement, 1, [[[stream valueForKey:@"url"] absoluteString] UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		// Statistics
		if(nil != (value = [stream valueForKey:@"dateAdded"])) {
			result = sqlite3_bind_double(statement, 2, [value timeIntervalSinceReferenceDate]);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"playCount"])) {
			result = sqlite3_bind_int(statement, 5, [value intValue]);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		
		// Metadata
		if(nil != (value = [stream valueForKey:@"title"])) {
			result = sqlite3_bind_text(statement, 6, [value UTF8String], -1, SQLITE_TRANSIENT);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"albumTitle"])) {
			result = sqlite3_bind_text(statement, 7, [value UTF8String], -1, SQLITE_TRANSIENT);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"artist"])) {
			result = sqlite3_bind_text(statement, 8, [value UTF8String], -1, SQLITE_TRANSIENT);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"albumArtist"])) {
			result = sqlite3_bind_text(statement, 9, [value UTF8String], -1, SQLITE_TRANSIENT);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"genre"])) {
			result = sqlite3_bind_text(statement, 10, [value UTF8String], -1, SQLITE_TRANSIENT);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"composer"])) {
			result = sqlite3_bind_text(statement, 11, [value UTF8String], -1, SQLITE_TRANSIENT);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"date"])) {
			result = sqlite3_bind_text(statement, 12, [value UTF8String], -1, SQLITE_TRANSIENT);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"compilation"])) {
			result = sqlite3_bind_int(statement, 13, [value boolValue]);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"trackNumber"])) {
			result = sqlite3_bind_int(statement, 14, [value unsignedIntValue]);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"trackTotal"])) {
			result = sqlite3_bind_int(statement, 15, [value unsignedIntValue]);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"discNumber"])) {
			result = sqlite3_bind_int(statement, 16, [value unsignedIntValue]);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"discTotal"])) {
			result = sqlite3_bind_int(statement, 17, [value unsignedIntValue]);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"comment"])) {
			result = sqlite3_bind_text(statement, 18, [value UTF8String], -1, SQLITE_TRANSIENT);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"isrc"])) {
			result = sqlite3_bind_text(statement, 19, [value UTF8String], -1, SQLITE_TRANSIENT);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"mcn"])) {
			result = sqlite3_bind_text(statement, 20, [value UTF8String], -1, SQLITE_TRANSIENT);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		
		// Properties
		if(nil != (value = [stream valueForKey:@"fileType"])) {
			result = sqlite3_bind_text(statement, 21, [value UTF8String], -1, SQLITE_TRANSIENT);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"formatType"])) {
			result = sqlite3_bind_text(statement, 22, [value UTF8String], -1, SQLITE_TRANSIENT);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"bitsPerChannel"])) {
			result = sqlite3_bind_int(statement, 23, [value unsignedIntValue]);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"channelsPerFrame"])) {
			result = sqlite3_bind_int(statement, 24, [value unsignedIntValue]);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"sampleRate"])) {
			result = sqlite3_bind_double(statement, 25, [value doubleValue]);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"totalFrames"])) {
			result = sqlite3_bind_int64(statement, 26, [value longLongValue]);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"duration"])) {
			result = sqlite3_bind_double(statement, 27, [value doubleValue]);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [stream valueForKey:@"bitrate"])) {
			result = sqlite3_bind_double(statement, 28, [value doubleValue]);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		
		result = sqlite3_step(statement);
		NSAssert2(SQLITE_DONE == result, @"Unable to insert a record for %@ (%@).", [[NSFileManager defaultManager] displayNameAtPath:[[stream valueForKey:StreamURLKey] path]], [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		[stream initValue:[NSNumber numberWithInt:sqlite3_last_insert_rowid(_db)] forKey:ObjectIDKey];
		
		result = sqlite3_reset(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_clear_bindings(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	
	@catch(NSException *exception) {
		NSLog(@"%@",exception);
		
		// Ignore the result code, because it will always be an error in this case
		// (sqlite3_reset returns the result of the previous operation and we are in a catch block)
		/*result =*/ sqlite3_reset(statement);
		
		success = NO;
	}
	
/*#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Stream insertion time = %f seconds", elapsed);
#endif*/
	
	return success;
}

- (void) doUpdateStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	//	NSParameterAssert(nil != [stream valueForKey:ObjectIDKey]);
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"update_stream"];
	int				result			= SQLITE_OK;
	unsigned		objectID		= [[stream valueForKey:ObjectIDKey] unsignedIntValue];
	NSDictionary	*changes		= [stream changes];
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
/*#if SQL_DEBUG
	clock_t start = clock();
#endif*/
	
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":id"), objectID);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	[self bindStreamValues:stream toStatement:statement];
	
	result = sqlite3_step(statement);
	NSAssert2(SQLITE_DONE == result, @"Unable to update the record for %@ (%@).", stream, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_clear_bindings(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
/*#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Stream update time = %f seconds", elapsed);
#endif*/
	
	// Reset the object with the stored values
	[stream initValuesForKeysWithDictionary:changes];

//	[_updatedObjects removeObject:stream];
}

- (void) doDeleteStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	//	NSParameterAssert(nil != [stream valueForKey:ObjectIDKey]);
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"delete_stream"];
	int				result			= SQLITE_OK;
	unsigned		objectID		= [[stream valueForKey:ObjectIDKey] unsignedIntValue];
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
/*#if SQL_DEBUG
	clock_t start = clock();
#endif*/
	
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":id"), objectID);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert2(SQLITE_DONE == result, @"Unable to delete the record for %@ (%@).", stream, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_clear_bindings(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
/*#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Stream delete time = %f seconds", elapsed);
#endif*/

	// Deregister the object
	NSMapRemove(_streams, (void *)objectID);
}

- (void) bindStreamValues:(AudioStream *)stream toStatement:(sqlite3_stmt *)statement
{
	NSParameterAssert(nil != stream);
	NSParameterAssert(NULL != statement);

	int				result			= SQLITE_OK;
	id				value			= nil;

	// Location
	if(nil != (value = [stream valueForKey:StreamURLKey])) {
		result = sqlite3_bind_text(statement, sqlite3_bind_parameter_index(statement, ":url"), [[value absoluteString] UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	
	// Statistics
	if(nil != (value = [stream valueForKey:StatisticsDateAddedKey])) {
		result = sqlite3_bind_double(statement, sqlite3_bind_parameter_index(statement, ":date_added"), [value timeIntervalSinceReferenceDate]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:StatisticsFirstPlayedDateKey])) {
		result = sqlite3_bind_double(statement, sqlite3_bind_parameter_index(statement, ":first_played_date"), [value timeIntervalSinceReferenceDate]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:StatisticsLastPlayedDateKey])) {
		result = sqlite3_bind_double(statement, sqlite3_bind_parameter_index(statement, ":last_played_date"), [value timeIntervalSinceReferenceDate]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:StatisticsPlayCountKey])) {
		result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":play_count"), [value intValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	
	// Metadata
	if(nil != (value = [stream valueForKey:MetadataTitleKey])) {
		result = sqlite3_bind_text(statement, sqlite3_bind_parameter_index(statement, ":title"), [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:MetadataAlbumTitleKey])) {
		result = sqlite3_bind_text(statement, sqlite3_bind_parameter_index(statement, ":album_title"), [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:MetadataArtistKey])) {
		result = sqlite3_bind_text(statement, sqlite3_bind_parameter_index(statement, ":artist"), [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:MetadataAlbumArtistKey])) {
		result = sqlite3_bind_text(statement, sqlite3_bind_parameter_index(statement, ":album_artist"), [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:MetadataGenreKey])) {
		result = sqlite3_bind_text(statement, sqlite3_bind_parameter_index(statement, ":genre"), [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:MetadataComposerKey])) {
		result = sqlite3_bind_text(statement, sqlite3_bind_parameter_index(statement, ":composer"), [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:MetadataDateKey])) {
		result = sqlite3_bind_text(statement, sqlite3_bind_parameter_index(statement, ":date"), [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:MetadataCompilationKey])) {
		result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":compilation"), [value boolValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:MetadataTrackNumberKey])) {
		result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":track_number"), [value unsignedIntValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:MetadataTrackTotalKey])) {
		result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":track_total"), [value unsignedIntValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:MetadataDiscNumberKey])) {
		result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":disc_number"), [value unsignedIntValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:MetadataDiscTotalKey])) {
		result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":disc_total"), [value unsignedIntValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:MetadataCommentKey])) {
		result = sqlite3_bind_text(statement, sqlite3_bind_parameter_index(statement, ":comment"), [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:MetadataISRCKey])) {
		result = sqlite3_bind_text(statement, sqlite3_bind_parameter_index(statement, ":isrc"), [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:MetadataMCNKey])) {
		result = sqlite3_bind_text(statement, sqlite3_bind_parameter_index(statement, ":mcn"), [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	
	// Properties
	if(nil != (value = [stream valueForKey:PropertiesFileTypeKey])) {
		result = sqlite3_bind_text(statement, sqlite3_bind_parameter_index(statement, ":file_type"), [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:PropertiesFormatTypeKey])) {
		result = sqlite3_bind_text(statement, sqlite3_bind_parameter_index(statement, ":format_type"), [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:PropertiesBitsPerChannelKey])) {
		result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":bits_per_channel"), [value unsignedIntValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:PropertiesChannelsPerFrameKey])) {
		result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":channels_per_frame"), [value unsignedIntValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:PropertiesSampleRateKey])) {
		result = sqlite3_bind_double(statement, sqlite3_bind_parameter_index(statement, ":sample_rate"), [value doubleValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:PropertiesTotalFramesKey])) {
		result = sqlite3_bind_int64(statement, sqlite3_bind_parameter_index(statement, ":total_frames"), [value longLongValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:PropertiesDurationKey])) {
		result = sqlite3_bind_double(statement, sqlite3_bind_parameter_index(statement, ":duration"), [value doubleValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:PropertiesBitrateKey])) {
		result = sqlite3_bind_double(statement, sqlite3_bind_parameter_index(statement, ":bitrate"), [value doubleValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
}

#pragma mark Playlists

- (BOOL) doInsertPlaylist:(Playlist *)playlist
{
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"insert_playlist"];
	int				result			= SQLITE_OK;
	id				value			= nil;
	BOOL			success			= YES;
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
/*#if SQL_DEBUG
	clock_t start = clock();
#endif*/
	
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
		/*result =*/ sqlite3_reset(statement);
		
		success = NO;
	}
	
/*#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Playlist insertion time = %f seconds", elapsed);
#endif*/
	
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
	
/*#if SQL_DEBUG
	clock_t start = clock();
#endif*/
	
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":id"), objectID);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	[self bindPlaylistValues:playlist toStatement:statement];
	
	result = sqlite3_step(statement);
	NSAssert2(SQLITE_DONE == result, @"Unable to update the record for %@ (%@).", playlist, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_clear_bindings(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
/*#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Stream update time = %f seconds", elapsed);
#endif*/
	
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
	
/*#if SQL_DEBUG
	clock_t start = clock();
#endif*/
	
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":id"), objectID);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert2(SQLITE_DONE == result, @"Unable to delete the record for %@ (%@).", playlist, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_clear_bindings(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
/*#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Stream delete time = %f seconds", elapsed);
#endif*/
	
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

@end