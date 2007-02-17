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

@interface PlaylistManager (Private)
- (void) 			prepareSQL;
- (void) 			finalizeSQL;
- (sqlite3_stmt *) 	preparedStatementForAction:(NSString *)action;

- (BOOL) isConnectedToDatabase;
- (BOOL) updateInProgress;

- (NSArray *) fetchPlaylists;

- (Playlist *) loadPlaylist:(sqlite3_stmt *)statement;

- (BOOL) doInsertPlaylist:(Playlist *)playlist;
- (void) doUpdatePlaylist:(Playlist *)playlist;
- (void) doDeletePlaylist:(Playlist *)playlist;

- (NSArray *) playlistKeys;
@end

@implementation PlaylistManager

- (id) init
{
	if((self = [super init])) {
		_registeredPlaylists	= NSCreateMapTable(NSIntMapKeyCallBacks, NSObjectMapValueCallBacks, 4096);		
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
		if(nil == _cachedPlaylists) {
			_cachedPlaylists = [[self fetchPlaylists] retain];
		}
	}
	return _cachedPlaylists;
}

- (Playlist *) playlistForID:(NSNumber *)objectID
{
	NSParameterAssert(nil != objectID);
	
	Playlist *playlist = (Playlist *)NSMapGet(_registeredPlaylists, (void *)[objectID unsignedIntValue]);
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
	
	BOOL result;
	
	if([self updateInProgress]) {
		[_insertedPlaylists addObject:playlist];
	}
	else {
		NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:0];
	
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
	
	if(NO == [playlist hasChanges]) {
		return;
	}
	
	if([self updateInProgress]) {
		[_updatedPlaylists addObject:playlist];
	}
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
	
	if([self updateInProgress]) {
		[_deletedPlaylists addObject:playlist];
	}
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
	
	if(NO == [self updateInProgress]) {
		[self willChange:NSKeyValueChangeSetting valuesAtIndexes:indexes forKey:@"playlists"];
	}
	
	[playlist revert];
	
	if(NO == [self updateInProgress]) {
		[self didChange:NSKeyValueChangeSetting valuesAtIndexes:indexes forKey:@"playlists"];
	}
}

#pragma mark Metadata support

- (id) valueForKey:(NSString *)key
{
	if([[self playlistKeys] containsObject:key]) {
		NSString *keyName = [NSString stringWithFormat:@"@distinctUnionOfObjects.%@", key];
		return [[[self playlists] valueForKeyPath:keyName] sortedArrayUsingSelector:@selector(compare:)];
	}
	else {
		return [super valueForKey:key];
	}
}

@end

@implementation PlaylistManager (CollectionManagerMethods)

- (void) connectedToDatabase:(sqlite3 *)db
{
	_db = db;
	[self prepareSQL];
}

- (void) disconnectedFromDatabase
{
	[self finalizeSQL];
	_db = NULL;
}

- (void) reset
{
	[self willChangeValueForKey:@"playlists"];
	NSResetMapTable(_registeredPlaylists);
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
	
	NSEnumerator 		*enumerator 	= nil;
	Playlist			*playlist 		= nil;
	
	// ========================================
	// Process updates first
	if(0 != [_updatedPlaylists count]) {
		enumerator = [_updatedPlaylists objectEnumerator];
		while((playlist = [enumerator nextObject])) {
			[self doUpdatePlaylist:playlist];
		}
	}
	
	// ========================================
	// Processes deletes next
	if(0 != [_deletedPlaylists count]) {
		enumerator = [_deletedPlaylists objectEnumerator];
		while((playlist = [enumerator nextObject])) {
			[self doDeletePlaylist:playlist];
		}
	}
	
	// ========================================
	// Finally, process inserts, removing any that fail
	if(0 != [_insertedPlaylists count]) {
		enumerator = [[_insertedPlaylists allObjects] objectEnumerator];
		while((playlist = [enumerator nextObject])) {
			if(NO == [self doInsertPlaylist:playlist]) {
				[_insertedPlaylists removeObject:playlist];
			}
		}
	}	
}

- (void) finishUpdate
{
	NSAssert(YES == _updating, @"No update in progress");
	
	NSEnumerator 		*enumerator 	= nil;
	Playlist			*playlist 		= nil;
	NSMutableIndexSet 	*indexes 		= [[NSMutableIndexSet alloc] init];
	
	// ========================================
	// Broadcast the notifications
	if(0 != [_updatedPlaylists count]) {
		enumerator = [_updatedPlaylists objectEnumerator];
		while((playlist = [enumerator nextObject])) {
			[[NSNotificationCenter defaultCenter] postNotificationName:PlaylistDidChangeNotification 
																object:self 
															  userInfo:[NSDictionary dictionaryWithObject:playlist forKey:PlaylistObjectKey]];		
		}		
		
		[_updatedPlaylists removeAllObjects];
	}
	
	// ========================================
	// Handle deletes
	if(0 != [_deletedPlaylists count]) {
		enumerator = [_deletedPlaylists objectEnumerator];
		while((playlist = [enumerator nextObject])) {
			[indexes addIndex:[_cachedPlaylists indexOfObject:playlist]];
		}
		
		[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"playlists"];
		enumerator = [_deletedPlaylists objectEnumerator];
		while((playlist = [enumerator nextObject])) {
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
		[indexes addIndexesInRange:NSMakeRange(0, [_insertedPlaylists count])];
		
		[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"playlists"];
		enumerator = [[_insertedPlaylists allObjects] objectEnumerator];
		while((playlist = [enumerator nextObject])) {
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
		NSEnumerator	*enumerator 	= nil;
		Playlist		*playlist 		= nil;
		
		enumerator = [_updatedPlaylists objectEnumerator];
		while((playlist = [enumerator nextObject])) {
			[playlist revert];
		}
	}
	
	[_insertedPlaylists removeAllObjects];
	[_updatedPlaylists removeAllObjects];
	[_deletedPlaylists removeAllObjects];
	
	_updating = NO;
}

- (void) playlist:(Playlist *)playlist willChangeValueForKey:(NSString *)key
{
	id			value	= [playlist valueForKey:key];
	unsigned	index	= [[self valueForKey:key] indexOfObject:value];
	
	if(NSNotFound == index) {
		[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:0] forKey:key];
	}
	else {
		[self willChange:NSKeyValueChangeSetting valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:key];
	}
}

- (void) playlist:(Playlist *)playlist didChangeValueForKey:(NSString *)key
{
	id			value	= [playlist valueForKey:key];
	unsigned	index	= [[self valueForKey:key] indexOfObject:value];
	
	[self savePlaylist:playlist];
	
	if(NSNotFound == index) {
		[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:0] forKey:key];
	}
	else {
		[self didChange:NSKeyValueChangeSetting valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:key];
	}
}

@end

@implementation PlaylistManager (Private)

#pragma mark Prepared SQL Statements

- (void) prepareSQL
{
	NSError			*error				= nil;	
	NSString		*path				= nil;
	NSString		*sql				= nil;
	NSString		*filename			= nil;
	NSArray			*files				= [NSArray arrayWithObjects:
		@"select_all_playlists", @"select_playlist_by_id", @"insert_playlist", @"update_playlist", @"delete_playlist", nil];
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

- (Playlist *) loadPlaylist:(sqlite3_stmt *)statement
{
	Playlist		*playlist		= nil;
	unsigned		objectID;
	
	// The ID should never be NULL
	NSAssert(SQLITE_NULL != sqlite3_column_type(statement, 0), @"No ID found for playlist");
	objectID = sqlite3_column_int(statement, 0);
	
	playlist = (Playlist *)NSMapGet(_registeredPlaylists, (void *)objectID);
	if(nil != playlist) {
		return playlist;
	}
	
	playlist = [[Playlist alloc] init];
	
	// Playlist ID and name
	[playlist initValue:[NSNumber numberWithUnsignedInt:objectID] forKey:ObjectIDKey];
	//	getColumnValue(statement, 0, playlist, ObjectIDKey, eObjectTypeUnsignedInteger);
	getColumnValue(statement, 1, playlist, PlaylistNameKey, eObjectTypeString);
	
	// Statistics
	getColumnValue(statement, 2, playlist, StatisticsDateCreatedKey, eObjectTypeDate);
	getColumnValue(statement, 3, playlist, StatisticsFirstPlayedDateKey, eObjectTypeDate);
	getColumnValue(statement, 4, playlist, StatisticsLastPlayedDateKey, eObjectTypeDate);
	getColumnValue(statement, 5, playlist, StatisticsPlayCountKey, eObjectTypeUnsignedInteger);
	
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
	
/*#if SQL_DEBUG
	clock_t start = clock();
#endif*/
	
	@try {
		// Location
		bindParameter(statement, 1, playlist, PlaylistNameKey, eObjectTypeString);
		
		// Statistics
		bindParameter(statement, 2, playlist, StatisticsDateCreatedKey, eObjectTypeDate);
		bindParameter(statement, 3, playlist, StatisticsFirstPlayedDateKey, eObjectTypeDate);
		bindParameter(statement, 4, playlist, StatisticsLastPlayedDateKey, eObjectTypeDate);
		bindParameter(statement, 5, playlist, StatisticsPlayCountKey, eObjectTypeUnsignedInteger);
		
		result = sqlite3_step(statement);
		NSAssert2(SQLITE_DONE == result, @"Unable to insert a record for %@ (%@).", [playlist valueForKey:PlaylistNameKey], [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		[playlist initValue:[NSNumber numberWithInt:sqlite3_last_insert_rowid(_db)] forKey:ObjectIDKey];
		
		result = sqlite3_reset(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_clear_bindings(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	
	@catch(NSException *exception) {
		NSLog(@"%@", exception);
		
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

- (void) doUpdatePlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	//	NSParameterAssert(nil != [playlist valueForKey:ObjectIDKey]);
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"update_playlist"];
	int				result			= SQLITE_OK;
	NSDictionary	*changes		= [playlist changedValues];
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
/*#if SQL_DEBUG
	clock_t start = clock();
#endif*/
	
	// ID and Name
	bindNamedParameter(statement, ":id", playlist, ObjectIDKey, eObjectTypeUnsignedInteger);
	bindNamedParameter(statement, ":name", playlist, PlaylistNameKey, eObjectTypeString);
	
	// Statistics
	bindNamedParameter(statement, ":date_created", playlist, StatisticsDateCreatedKey, eObjectTypeDate);
	bindNamedParameter(statement, ":first_played_date", playlist, StatisticsFirstPlayedDateKey, eObjectTypeDate);
	bindNamedParameter(statement, ":last_played_date", playlist, StatisticsLastPlayedDateKey, eObjectTypeDate);
	bindNamedParameter(statement, ":play_count", playlist, StatisticsPlayCountKey, eObjectTypeInteger);
	
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
	NSMapRemove(_registeredPlaylists, (void *)objectID);
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
