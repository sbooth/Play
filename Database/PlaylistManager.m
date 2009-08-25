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

#import "PlaylistManager.h"
#import "CollectionManager.h"
#import "Playlist.h"
#import "AudioLibrary.h"

#import "SQLiteUtilityFunctions.h"

@interface PlaylistManager (Private)
- (BOOL) prepareSQL:(NSError **)error;
- (BOOL) finalizeSQL:(NSError **)error;
- (sqlite3_stmt *) preparedStatementForAction:(NSString *)action;

- (BOOL) isConnectedToDatabase;
- (BOOL) updateInProgress;

- (NSArray *) fetchPlaylists;

- (Playlist *) loadPlaylist:(sqlite3_stmt *)statement;

- (BOOL) doInsertPlaylist:(Playlist *)playlist;
- (void) doUpdatePlaylist:(Playlist *)playlist;
- (void) doDeletePlaylist:(Playlist *)playlist;

- (void) doUpdatePlaylistEntriesForPlaylist:(Playlist *)playlist;

- (NSArray *) playlistKeys;
@end

@implementation PlaylistManager

- (id) init
{
	if((self = [super init])) {
		_registeredPlaylists	= NSCreateMapTable(NSIntegerMapKeyCallBacks, NSObjectMapValueCallBacks, 4096);		
		_sql					= [[NSMutableDictionary alloc] init];
		_insertedPlaylists		= [[NSMutableSet alloc] init];
		_updatedPlaylists		= [[NSMutableSet alloc] init];
		_deletedPlaylists		= [[NSMutableSet alloc] init];	
	}
	return self;
}

- (void) dealloc
{
	NSFreeMapTable(_registeredPlaylists), _registeredPlaylists = NULL;	
	
	[_sql release], _sql = nil;
	
	[_cachedPlaylists release], _cachedPlaylists = nil;
	
	[_insertedPlaylists release], _insertedPlaylists = nil;
	[_updatedPlaylists release], _updatedPlaylists = nil;
	[_deletedPlaylists release], _deletedPlaylists = nil;
	
	[_playlistKeys release], _playlistKeys = nil;
	
	_db = NULL;
	
	[super dealloc];
}

#pragma mark Playlist support

- (NSArray *) playlists
{
	@synchronized(self) {
		if(nil == _cachedPlaylists)
			_cachedPlaylists = [[self fetchPlaylists] retain];
	}
	return _cachedPlaylists;
}

- (Playlist *) playlistForID:(NSNumber *)objectID
{
	NSParameterAssert(nil != objectID);
	
	Playlist *playlist = (Playlist *)NSMapGet(_registeredPlaylists, (void *)[objectID unsignedIntValue]);
	if(nil != playlist)
		return playlist;
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"select_playlist_by_id"];
	int				result			= SQLITE_OK;
				
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":id"), [objectID unsignedIntValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	while(SQLITE_ROW == (result = sqlite3_step(statement)))
		playlist = [self loadPlaylist:statement];
	
	NSAssert1(SQLITE_DONE == result, @"Error while fetching playlist (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Loaded playlist in %f seconds", elapsed);
#endif
	
	return playlist;
}

// ========================================
// Insert
- (BOOL) insertPlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	
	BOOL result = YES;
	
	if([self updateInProgress])
		[_insertedPlaylists addObject:playlist];
	else {
		NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([_cachedPlaylists count], 1)];
	
		result = [self doInsertPlaylist:playlist];
		if(result) {
			[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"playlists"];
			[_cachedPlaylists addObject:playlist];	
			[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"playlists"];

			[[NSNotificationCenter defaultCenter] postNotificationName:PlaylistAddedToLibraryNotification 
																object:self 
															  userInfo:[NSDictionary dictionaryWithObject:playlist forKey:PlaylistObjectKey]];
		}
	}
	
	return result;
}

// ========================================
// Update
- (void) savePlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	
	if(NO == [playlist hasChanges])
		return;
	
	if([self updateInProgress])
		[_updatedPlaylists addObject:playlist];
	else {
		[self doUpdatePlaylist:playlist];	
		
		[[NSNotificationCenter defaultCenter] postNotificationName:PlaylistDidChangeNotification 
															object:self 
														  userInfo:[NSDictionary dictionaryWithObject:playlist forKey:PlaylistObjectKey]];
	}
}

// ========================================
// Delete
- (void) deletePlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	
	if([self updateInProgress])
		[_deletedPlaylists addObject:playlist];
	else {
		NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:[_cachedPlaylists indexOfObject:playlist]];
		
		[self doDeletePlaylist:playlist];
		[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"playlists"];
		[_cachedPlaylists removeObject:playlist];	
		[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"playlists"];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:PlaylistRemovedFromLibraryNotification 
															object:self 
														  userInfo:[NSDictionary dictionaryWithObject:playlist forKey:PlaylistObjectKey]];		
	}
}

- (void) revertPlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	
	NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:[_cachedPlaylists indexOfObject:playlist]];
	
	if(NO == [self updateInProgress])
		[self willChange:NSKeyValueChangeSetting valuesAtIndexes:indexes forKey:@"playlists"];
	
	[playlist revert];
	
	if(NO == [self updateInProgress])
		[self didChange:NSKeyValueChangeSetting valuesAtIndexes:indexes forKey:@"playlists"];
}

#pragma mark Metadata support

- (id) valueForKey:(NSString *)key
{
	if([[self playlistKeys] containsObject:key])
		return [[self playlists] valueForKey:key];
	else
		return [super valueForKey:key];
}

@end

@implementation PlaylistManager (CollectionManagerMethods)

- (BOOL) connectedToDatabase:(sqlite3 *)db error:(NSError **)error
{
	_db = db;
	return [self prepareSQL:error];
}

- (BOOL) disconnectedFromDatabase:(NSError **)error
{
	_db = NULL;
	return [self finalizeSQL:error];
}

- (void) reset
{
	[self willChangeValueForKey:@"playlists"];
	NSResetMapTable(_registeredPlaylists);
	[_cachedPlaylists release], _cachedPlaylists = nil;
	[self didChangeValueForKey:@"playlists"];
}

- (void) beginUpdate
{
	NSAssert(NO == _updating, @"Update already in progress");
	
	_updating = YES;
	
	[_insertedPlaylists removeAllObjects];
	[_updatedPlaylists removeAllObjects];
	[_deletedPlaylists removeAllObjects];
}

- (void) processUpdate
{
	NSAssert(YES == _updating, @"No update in progress");
		
	// ========================================
	// Process updates first
	if(0 != [_updatedPlaylists count]) {
		for(Playlist *playlist in _updatedPlaylists)
			[self doUpdatePlaylist:playlist];
	}
	
	// ========================================
	// Processes deletes next
	if(0 != [_deletedPlaylists count]) {
		for(Playlist *playlist in _deletedPlaylists)
			[self doDeletePlaylist:playlist];
	}
	
	// ========================================
	// Finally, process inserts, removing any that fail
	if(0 != [_insertedPlaylists count]) {
		for(Playlist *playlist in _insertedPlaylists) {
			if(NO == [self doInsertPlaylist:playlist])
				[_insertedPlaylists removeObject:playlist];
		}
	}	
}

- (void) finishUpdate
{
	NSAssert(YES == _updating, @"No update in progress");
	
	NSMutableIndexSet 	*indexes 		= [[NSMutableIndexSet alloc] init];
	
	// ========================================
	// Broadcast the notifications
	if(0 != [_updatedPlaylists count]) {
		for(Playlist *playlist in _updatedPlaylists)
			[[NSNotificationCenter defaultCenter] postNotificationName:PlaylistDidChangeNotification 
																object:self 
															  userInfo:[NSDictionary dictionaryWithObject:playlist forKey:PlaylistObjectKey]];		
		
		[_updatedPlaylists removeAllObjects];
	}
	
	// ========================================
	// Handle deletes
	if(0 != [_deletedPlaylists count]) {
		for(Playlist *playlist in _deletedPlaylists)
			[indexes addIndex:[_cachedPlaylists indexOfObject:playlist]];
		
		[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"playlists"];
		
		for(Playlist *playlist in _deletedPlaylists) {
			[_cachedPlaylists removeObject:playlist];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:PlaylistRemovedFromLibraryNotification 
																object:self
															  userInfo:[NSDictionary dictionaryWithObject:playlist forKey:PlaylistObjectKey]];
		}
		
		[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"playlists"];		
		
		[_deletedPlaylists removeAllObjects];
		[indexes removeAllIndexes];
	}
	
	// ========================================
	// And finally inserts
	if(0 != [_insertedPlaylists count]) {
		[indexes addIndexesInRange:NSMakeRange([_cachedPlaylists count], [_insertedPlaylists count])];
		
		[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"playlists"];

		for(Playlist *playlist in _insertedPlaylists) {
			[_cachedPlaylists addObject:playlist];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:PlaylistAddedToLibraryNotification 
																object:self 
															  userInfo:[NSDictionary dictionaryWithObject:playlist forKey:PlaylistObjectKey]];
		}
		
		[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"playlists"];
		
		[_insertedPlaylists removeAllObjects];
	}
	
	_updating = NO;
	
	[indexes release];
}

- (void) cancelUpdate
{
	NSAssert(YES == _updating, @"No update in progress");
	
	// For a canceled update, revert the updated streams and forget about anything else
	if(0 != [_updatedPlaylists count]) {		
		for(Playlist *playlist in _updatedPlaylists)
			[playlist revert];
	}
	
	[_insertedPlaylists removeAllObjects];
	[_updatedPlaylists removeAllObjects];
	[_deletedPlaylists removeAllObjects];
	
	_updating = NO;
}

- (void) playlist:(Playlist *)playlist willChangeValueForKey:(NSString *)key
{
	unsigned index = [_cachedPlaylists indexOfObject:playlist];
	
	if(NSNotFound != index)
		[self willChange:NSKeyValueChangeSetting valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:key];
}

- (void) playlist:(Playlist *)playlist didChangeValueForKey:(NSString *)key
{
	unsigned index = [_cachedPlaylists indexOfObject:playlist];
	
	if(NSNotFound != index) {
		[self savePlaylist:playlist];
		[self didChange:NSKeyValueChangeSetting valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:key];
	}
}

@end

@implementation PlaylistManager (PlaylistMethods)

- (void) playlist:(Playlist *)playlist willInsertStream:(AudioStream *)stream atIndex:(unsigned)index
{}

- (void) playlist:(Playlist *)playlist didInsertStream:(AudioStream *)stream atIndex:(unsigned)index
{
	[self doUpdatePlaylistEntriesForPlaylist:playlist];
}

- (void) playlist:(Playlist *)playlist willRemoveStreamAtIndex:(unsigned)index
{}

- (void) playlist:(Playlist *)playlist didRemoveStreamAtIndex:(unsigned)index
{
	[self doUpdatePlaylistEntriesForPlaylist:playlist];
}

@end

@implementation PlaylistManager (Private)

#pragma mark Prepared SQL Statements

- (BOOL) prepareSQL:(NSError **)error
{
	NSString		*path				= nil;
	NSString		*sql				= nil;
	NSArray			*files				= [NSArray arrayWithObjects:
		@"select_all_playlists", @"select_playlist_by_id", @"insert_playlist", @"update_playlist", @"delete_playlist", 
		@"delete_playlist_entries_for_playlist", @"insert_playlist_entry", nil];
	sqlite3_stmt	*statement			= NULL;
	const char		*tail				= NULL;
	
	for(NSString *filename in files) {
		path 	= [[NSBundle mainBundle] pathForResource:filename ofType:@"sql"];
		sql 	= [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:error];
		
		if(nil == sql)
			return NO;
		
		if(SQLITE_OK != sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, &tail)) {
			if(nil != error) {
				NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
				
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The SQL statement for \"%@\" could not be prepared.", @"Errors", @""), filename] forKey:NSLocalizedDescriptionKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"Unable to prepare SQL statement", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The SQLite error was: %@", @"Errors", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]] forKey:NSLocalizedRecoverySuggestionErrorKey];
				
				*error = [NSError errorWithDomain:DatabaseErrorDomain 
											 code:DatabaseSQLiteError 
										 userInfo:errorDictionary];
			}
			
			return NO;
		}
		
		[_sql setValue:[NSNumber numberWithUnsignedLong:(unsigned long)statement] forKey:filename];
	}
	
	return YES;
}

- (BOOL) finalizeSQL:(NSError **)error
{
	sqlite3_stmt	*statement			= NULL;
	
	for(NSNumber *wrappedPtr in _sql) {
		statement = (sqlite3_stmt *)[wrappedPtr unsignedLongValue];
		if(SQLITE_OK != sqlite3_finalize(statement)) {
			if(nil != error) {
				NSArray *keys = [_sql allKeysForObject:wrappedPtr];
				NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
				
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The SQL statement for \"%@\" could not be finalized.", @"Errors", @""), [keys lastObject]] forKey:NSLocalizedDescriptionKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"Unable to finalize SQL statement", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The SQLite error was: %@", @"Errors", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]] forKey:NSLocalizedRecoverySuggestionErrorKey];
				
				*error = [NSError errorWithDomain:DatabaseErrorDomain 
											 code:DatabaseSQLiteError 
										 userInfo:errorDictionary];
			}
			
			return NO;
		}
	}
	
	[_sql removeAllObjects];
	
	return YES;
}

- (sqlite3_stmt *) preparedStatementForAction:(NSString *)action
{
	return (sqlite3_stmt *)[[_sql valueForKey:action] unsignedLongValue];		
}

- (BOOL) isConnectedToDatabase
{
	return NULL != _db;
}

- (BOOL) updateInProgress
{
	return _updating;
}

#pragma mark Object Loading

- (NSArray *) fetchPlaylists
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
	
	NSAssert1(SQLITE_DONE == result, @"Error while fetching playlists (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Loaded %i playlists in %f seconds (%f per second)", [playlists count], elapsed, (double)[playlists count] / elapsed);
#endif
	
	return [playlists autorelease];
}

- (Playlist *) loadPlaylist:(sqlite3_stmt *)statement
{
	Playlist		*playlist		= nil;
	unsigned		objectID;
	
	// The ID should never be NULL
	NSAssert(SQLITE_NULL != sqlite3_column_type(statement, 0), @"No ID found for playlist");
	objectID = sqlite3_column_int(statement, 0);
	
	playlist = (Playlist *)NSMapGet(_registeredPlaylists, (void *)objectID);
	if(nil != playlist)
		return playlist;
	
	playlist = [[Playlist alloc] init];
	
	// Playlist ID and name
	[playlist initValue:[NSNumber numberWithUnsignedInt:objectID] forKey:ObjectIDKey];
	//	getColumnValue(statement, 0, playlist, ObjectIDKey, eObjectTypeUnsignedInt);
	getColumnValue(statement, 1, playlist, PlaylistNameKey, eObjectTypeString);
	
	// Statistics
	getColumnValue(statement, 2, playlist, StatisticsDateCreatedKey, eObjectTypeDate);
	getColumnValue(statement, 3, playlist, StatisticsFirstPlayedDateKey, eObjectTypeDate);
	getColumnValue(statement, 4, playlist, StatisticsLastPlayedDateKey, eObjectTypeDate);
	getColumnValue(statement, 5, playlist, StatisticsPlayCountKey, eObjectTypeUnsignedInt);
	
	// Register the object	
	NSMapInsert(_registeredPlaylists, (void *)objectID, (void *)playlist);
	
	return [playlist autorelease];
}

#pragma mark Playlists

- (BOOL) doInsertPlaylist:(Playlist *)playlist
{
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"insert_playlist"];
	int				result			= SQLITE_OK;
	BOOL			success			= YES;
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	@try {
		// Location
		bindParameter(statement, 1, playlist, PlaylistNameKey, eObjectTypeString);
		
		// Statistics
		bindParameter(statement, 2, playlist, StatisticsDateCreatedKey, eObjectTypeDate);
		bindParameter(statement, 3, playlist, StatisticsFirstPlayedDateKey, eObjectTypeDate);
		bindParameter(statement, 4, playlist, StatisticsLastPlayedDateKey, eObjectTypeDate);
		bindParameter(statement, 5, playlist, StatisticsPlayCountKey, eObjectTypeUnsignedInt);
		
		result = sqlite3_step(statement);
		NSAssert2(SQLITE_DONE == result, @"Unable to insert a record for %@ (%@).", [playlist valueForKey:PlaylistNameKey], [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		[playlist initValue:[NSNumber numberWithInt:sqlite3_last_insert_rowid(_db)] forKey:ObjectIDKey];
		
		result = sqlite3_reset(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_clear_bindings(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);

		// Register the object	
		NSMapInsert(_registeredPlaylists, (void *)[[playlist valueForKey:ObjectIDKey] unsignedIntValue], (void *)playlist);
	}
	
	@catch(NSException *exception) {
		NSLog(@"%@", exception);
		
		// Ignore the result code, because it will always be an error in this case
		// (sqlite3_reset returns the result of the previous operation and we are in a catch block)
		/*result =*/ sqlite3_reset(statement);
		
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
	//	NSParameterAssert(nil != [playlist valueForKey:ObjectIDKey]);
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"update_playlist"];
	int				result			= SQLITE_OK;
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	// ID and Name
	bindNamedParameter(statement, ":id", playlist, ObjectIDKey, eObjectTypeUnsignedInt);
	bindNamedParameter(statement, ":name", playlist, PlaylistNameKey, eObjectTypeString);
	
	// Statistics
	bindNamedParameter(statement, ":date_created", playlist, StatisticsDateCreatedKey, eObjectTypeDate);
	bindNamedParameter(statement, ":first_played_date", playlist, StatisticsFirstPlayedDateKey, eObjectTypeDate);
	bindNamedParameter(statement, ":last_played_date", playlist, StatisticsLastPlayedDateKey, eObjectTypeDate);
	bindNamedParameter(statement, ":play_count", playlist, StatisticsPlayCountKey, eObjectTypeInt);
	
	result = sqlite3_step(statement);
	NSAssert2(SQLITE_DONE == result, @"Unable to update the record for %@ (%@).", playlist, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_clear_bindings(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Playlist update time = %f seconds", elapsed);
#endif
	
	// Reset the object with the stored values
	[playlist synchronizeSavedValuesWithChangedValues];
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
	NSLog(@"Playlist delete time = %f seconds", elapsed);
#endif
	
	// Deregister the object
	NSMapRemove(_registeredPlaylists, (void *)objectID);
}

// TODO: Would it be better to update the rows instead of deleting and re-inserting them?
- (void) doUpdatePlaylistEntriesForPlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	//	NSParameterAssert(nil != [playlist valueForKey:ObjectIDKey]);
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"delete_playlist_entries_for_playlist"];
	int				result			= SQLITE_OK;
	unsigned		objectID		= [[playlist valueForKey:ObjectIDKey] unsignedIntValue];
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif*/
	
	// First delete the old playlist entries for the playlist
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":playlist_id"), objectID);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert2(SQLITE_DONE == result, @"Unable to delete the record for %@ (%@).", playlist, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_clear_bindings(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);

	// And then insert the new ones
	statement = [self preparedStatementForAction:@"insert_playlist_entry"];
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
	unsigned		index		= 0;
	NSArray			*streams	= [playlist streams];
	AudioStream		*stream		= nil;
	
	for(index = 0; index < [streams count]; ++index) {
		stream = [streams objectAtIndex:index];
		
		bindParameter(statement, 1, playlist, ObjectIDKey, eObjectTypeUnsignedInt);
		bindParameter(statement, 2, stream, ObjectIDKey, eObjectTypeUnsignedInt);
//		bindParameter(statement, 3, playlist, StatisticsLastPlayedDateKey, eObjectTypeDate);
		result = sqlite3_bind_int(statement, 3, index);	
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter %i to sql statement.", 3/*, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]*/);

		result = sqlite3_step(statement);
		NSAssert4(SQLITE_DONE == result, @"Unable to insert a record for %@ in %@ at index %i (%@).", stream, playlist, index, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_reset(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_clear_bindings(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Playlist stream update time = %f seconds", elapsed);
#endif
}

- (NSArray *) playlistKeys
{
	@synchronized(self) {
		if(nil == _playlistKeys) {
			_playlistKeys	= [[NSArray alloc] initWithObjects:
				ObjectIDKey, 
				PlaylistNameKey,
				
				StatisticsDateCreatedKey,
				StatisticsFirstPlayedDateKey,
				StatisticsLastPlayedDateKey,
				StatisticsPlayCountKey,
								
				nil];			
		}
	}
	return _playlistKeys;
}

@end
