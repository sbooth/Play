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

#import "SmartPlaylistManager.h"
#import "CollectionManager.h"
#import "SmartPlaylist.h"
#import "AudioLibrary.h"

#import "SQLiteUtilityFunctions.h"

@interface SmartPlaylistManager (CollectionManagerMethods)
- (void) connectedToDatabase:(sqlite3 *)db;
- (void) disconnectedFromDatabase;
- (void) reset;

- (void) beginUpdate;
- (void) processUpdate;
- (void) finishUpdate;
- (void) cancelUpdate;

- (void) smartPlaylist:(SmartPlaylist *)playlist willChangeValueForKey:(NSString *)key;
- (void) smartPlaylist:(SmartPlaylist *)playlist didChangeValueForKey:(NSString *)key;
@end

@interface SmartPlaylistManager (PlaylistMethods)
- (void) playlist:(Playlist *)playlist willInsertStream:(AudioStream *)stream atIndex:(unsigned)index;
- (void) playlist:(Playlist *)playlist didInsertStream:(AudioStream *)stream atIndex:(unsigned)index;

- (void) playlist:(Playlist *)playlist willRemoveStreamAtIndex:(unsigned)index;
- (void) playlist:(Playlist *)playlist didRemoveStreamAtIndex:(unsigned)index;
@end

@interface SmartPlaylistManager (Private)
- (void) 			prepareSQL;
- (void) 			finalizeSQL;
- (sqlite3_stmt *) 	preparedStatementForAction:(NSString *)action;

- (BOOL) isConnectedToDatabase;
- (BOOL) updateInProgress;

- (NSArray *) fetchSmartPlaylists;

- (SmartPlaylist *) loadSmartPlaylist:(sqlite3_stmt *)statement;

- (BOOL) doInsertSmartPlaylist:(SmartPlaylist *)playlist;
- (void) doUpdateSmartPlaylist:(SmartPlaylist *)playlist;
- (void) doDeleteSmartPlaylist:(SmartPlaylist *)playlist;

- (NSArray *) smartPlaylistKeys;
@end

@implementation SmartPlaylistManager

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

#pragma mark SmartPlaylist support

- (NSArray *) smartPlaylists
{
	@synchronized(self) {
		if(nil == _cachedPlaylists)
			_cachedPlaylists = [[self fetchSmartPlaylists] retain];
	}
	return _cachedPlaylists;
}

- (SmartPlaylist *) smartPlaylistForID:(NSNumber *)objectID
{
	NSParameterAssert(nil != objectID);
	
	SmartPlaylist *playlist = (SmartPlaylist *)NSMapGet(_registeredPlaylists, (void *)[objectID unsignedIntValue]);
	if(nil != playlist)
		return playlist;
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"select_smart_playlist_by_id"];
	int				result			= SQLITE_OK;
				
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":id"), [objectID unsignedIntValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	while(SQLITE_ROW == (result = sqlite3_step(statement)))
		playlist = [self loadSmartPlaylist:statement];
	
	NSAssert1(SQLITE_DONE == result, @"Error while fetching smart playlist (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Loaded smart playlist in %f seconds", elapsed);
#endif
	
	return playlist;
}

// ========================================
// Insert
- (BOOL) insertSmartPlaylist:(SmartPlaylist *)playlist
{
	NSParameterAssert(nil != playlist);
	
	BOOL result = YES;
	
	if([self updateInProgress])
		[_insertedPlaylists addObject:playlist];
	else {
		NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([_cachedPlaylists count], 1)];
	
		result = [self doInsertSmartPlaylist:playlist];
		if(result) {
			[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"smartPlaylists"];
			[_cachedPlaylists addObject:playlist];	
			[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"smartPlaylists"];

			[[NSNotificationCenter defaultCenter] postNotificationName:SmartPlaylistAddedToLibraryNotification 
																object:self 
															  userInfo:[NSDictionary dictionaryWithObject:playlist forKey:SmartPlaylistObjectKey]];
		}
	}
	
	return result;
}

// ========================================
// Update
- (void) saveSmartPlaylist:(SmartPlaylist *)playlist
{
	NSParameterAssert(nil != playlist);
	
	if(NO == [playlist hasChanges])
		return;
	
	if([self updateInProgress])
		[_updatedPlaylists addObject:playlist];
	else {
		[self doUpdateSmartPlaylist:playlist];	
		
		[[NSNotificationCenter defaultCenter] postNotificationName:SmartPlaylistDidChangeNotification 
															object:self 
														  userInfo:[NSDictionary dictionaryWithObject:playlist forKey:SmartPlaylistObjectKey]];
	}
}

// ========================================
// Delete
- (void) deleteSmartPlaylist:(SmartPlaylist *)playlist
{
	NSParameterAssert(nil != playlist);
	
	if([self updateInProgress])
		[_deletedPlaylists addObject:playlist];
	else {
		NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:[_cachedPlaylists indexOfObject:playlist]];
		
		[self doDeleteSmartPlaylist:playlist];
		[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"smartPlaylists"];
		[_cachedPlaylists removeObject:playlist];	
		[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"smartPlaylists"];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:SmartPlaylistRemovedFromLibraryNotification 
															object:self 
														  userInfo:[NSDictionary dictionaryWithObject:playlist forKey:SmartPlaylistObjectKey]];		
	}
}

- (void) revertSmartPlaylist:(SmartPlaylist *)playlist
{
	NSParameterAssert(nil != playlist);
	
	NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:[_cachedPlaylists indexOfObject:playlist]];
	
	if(NO == [self updateInProgress])
		[self willChange:NSKeyValueChangeSetting valuesAtIndexes:indexes forKey:@"smartPlaylists"];
	
	[playlist revert];
	
	if(NO == [self updateInProgress])
		[self didChange:NSKeyValueChangeSetting valuesAtIndexes:indexes forKey:@"smartPlaylists"];
}

#pragma mark Metadata support

- (id) valueForKey:(NSString *)key
{
	if([[self smartPlaylistKeys] containsObject:key])
		return [[self smartPlaylists] valueForKey:key];
	else
		return [super valueForKey:key];
}

@end

@implementation SmartPlaylistManager (CollectionManagerMethods)

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
	[self willChangeValueForKey:@"smartPlaylists"];
	NSResetMapTable(_registeredPlaylists);
	[_cachedPlaylists release], _cachedPlaylists = nil;
	[self didChangeValueForKey:@"smartPlaylists"];
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
	SmartPlaylist		*playlist 		= nil;
	
	// ========================================
	// Process updates first
	if(0 != [_updatedPlaylists count]) {
		enumerator = [_updatedPlaylists objectEnumerator];
		while((playlist = [enumerator nextObject]))
			[self doUpdateSmartPlaylist:playlist];
	}
	
	// ========================================
	// Processes deletes next
	if(0 != [_deletedPlaylists count]) {
		enumerator = [_deletedPlaylists objectEnumerator];
		while((playlist = [enumerator nextObject]))
			[self doDeleteSmartPlaylist:playlist];
	}
	
	// ========================================
	// Finally, process inserts, removing any that fail
	if(0 != [_insertedPlaylists count]) {
		enumerator = [[_insertedPlaylists allObjects] objectEnumerator];
		while((playlist = [enumerator nextObject])) {
			if(NO == [self doInsertSmartPlaylist:playlist])
				[_insertedPlaylists removeObject:playlist];
		}
	}	
}

- (void) finishUpdate
{
	NSAssert(YES == _updating, @"No update in progress");
	
	NSEnumerator 		*enumerator 	= nil;
	SmartPlaylist		*playlist 		= nil;
	NSMutableIndexSet 	*indexes 		= [[NSMutableIndexSet alloc] init];
	
	// ========================================
	// Broadcast the notifications
	if(0 != [_updatedPlaylists count]) {
		enumerator = [_updatedPlaylists objectEnumerator];
		while((playlist = [enumerator nextObject]))
			[[NSNotificationCenter defaultCenter] postNotificationName:SmartPlaylistDidChangeNotification 
																object:self 
															  userInfo:[NSDictionary dictionaryWithObject:playlist forKey:SmartPlaylistObjectKey]];		
		
		[_updatedPlaylists removeAllObjects];
	}
	
	// ========================================
	// Handle deletes
	if(0 != [_deletedPlaylists count]) {
		enumerator = [_deletedPlaylists objectEnumerator];
		while((playlist = [enumerator nextObject]))
			[indexes addIndex:[_cachedPlaylists indexOfObject:playlist]];
		
		[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"smartPlaylists"];
		enumerator = [_deletedPlaylists objectEnumerator];
		while((playlist = [enumerator nextObject])) {
			[_cachedPlaylists removeObject:playlist];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:SmartPlaylistRemovedFromLibraryNotification 
																object:self
															  userInfo:[NSDictionary dictionaryWithObject:playlist forKey:SmartPlaylistObjectKey]];
		}
		[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"smartPlaylists"];		
		
		[_deletedPlaylists removeAllObjects];
		[indexes removeAllIndexes];
	}
	
	// ========================================
	// And finally inserts
	if(0 != [_insertedPlaylists count]) {
		[indexes addIndexesInRange:NSMakeRange([_cachedPlaylists count], [_insertedPlaylists count])];
		
		[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"smartPlaylists"];
		enumerator = [[_insertedPlaylists allObjects] objectEnumerator];
		while((playlist = [enumerator nextObject])) {
			[_cachedPlaylists addObject:playlist];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:SmartPlaylistAddedToLibraryNotification 
																object:self 
															  userInfo:[NSDictionary dictionaryWithObject:playlist forKey:SmartPlaylistObjectKey]];
		}
		[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"smartPlaylists"];
		
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
		SmartPlaylist	*playlist 		= nil;
		
		enumerator = [_updatedPlaylists objectEnumerator];
		while((playlist = [enumerator nextObject]))
			[playlist revert];
	}
	
	[_insertedPlaylists removeAllObjects];
	[_updatedPlaylists removeAllObjects];
	[_deletedPlaylists removeAllObjects];
	
	_updating = NO;
}

- (void) smartPlaylist:(SmartPlaylist *)playlist willChangeValueForKey:(NSString *)key
{
	unsigned index = [_cachedPlaylists indexOfObject:playlist];
	
	if(NSNotFound != index)
		[self willChange:NSKeyValueChangeSetting valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:key];
}

- (void) smartPlaylist:(SmartPlaylist *)playlist didChangeValueForKey:(NSString *)key
{
	unsigned index = [_cachedPlaylists indexOfObject:playlist];
	
	if(NSNotFound != index) {
		[self saveSmartPlaylist:playlist];	
		[self didChange:NSKeyValueChangeSetting valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:key];
	}
}

@end

@implementation SmartPlaylistManager (Private)

#pragma mark Prepared SQL Statements

- (void) prepareSQL
{
	NSError			*error				= nil;	
	NSString		*path				= nil;
	NSString		*sql				= nil;
	NSString		*filename			= nil;
	NSArray			*files				= [NSArray arrayWithObjects:
		@"select_all_smart_playlists", @"select_smart_playlist_by_id", @"insert_smart_playlist", @"update_smart_playlist",
		@"delete_smart_playlist", nil];
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

- (NSArray *) fetchSmartPlaylists
{
	NSMutableArray	*playlists		= [[NSMutableArray alloc] init];
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"select_all_smart_playlists"];
	int				result			= SQLITE_OK;
	SmartPlaylist	*playlist		= nil;
				
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	while(SQLITE_ROW == (result = sqlite3_step(statement))) {
		playlist = [self loadSmartPlaylist:statement];
		[playlists addObject:playlist];
	}
	
	NSAssert1(SQLITE_DONE == result, @"Error while fetching smart playlists (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Loaded %i smart playlists in %f seconds (%f per second)", [playlists count], elapsed, (double)[playlists count] / elapsed);
#endif
	
	return [playlists autorelease];
}

- (SmartPlaylist *) loadSmartPlaylist:(sqlite3_stmt *)statement
{
	SmartPlaylist	*playlist		= nil;
	unsigned		objectID;
	
	// The ID should never be NULL
	NSAssert(SQLITE_NULL != sqlite3_column_type(statement, 0), @"No ID found for playlist");
	objectID = sqlite3_column_int(statement, 0);
	
	playlist = (SmartPlaylist *)NSMapGet(_registeredPlaylists, (void *)objectID);
	if(nil != playlist)
		return playlist;
	
	playlist = [[SmartPlaylist alloc] init];
	
	// Playlist ID and name
	[playlist initValue:[NSNumber numberWithUnsignedInt:objectID] forKey:ObjectIDKey];
	//	getColumnValue(statement, 0, playlist, ObjectIDKey, eObjectTypeUnsignedInteger);
	getColumnValue(statement, 1, playlist, PlaylistNameKey, eObjectTypeString);
	getColumnValue(statement, 2, playlist, SmartPlaylistPredicateKey, eObjectTypePredicate);
	
	// Statistics
	getColumnValue(statement, 3, playlist, StatisticsDateCreatedKey, eObjectTypeDate);
	getColumnValue(statement, 4, playlist, StatisticsFirstPlayedDateKey, eObjectTypeDate);
	getColumnValue(statement, 5, playlist, StatisticsLastPlayedDateKey, eObjectTypeDate);
	getColumnValue(statement, 6, playlist, StatisticsPlayCountKey, eObjectTypeUnsignedInteger);
	
	// Register the object	
	NSMapInsert(_registeredPlaylists, (void *)objectID, (void *)playlist);
	
	return [playlist autorelease];
}

#pragma mark SmartPlaylists

- (BOOL) doInsertSmartPlaylist:(SmartPlaylist *)playlist
{
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"insert_smart_playlist"];
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
		bindParameter(statement, 2, playlist, SmartPlaylistPredicateKey, eObjectTypePredicate);
		
		// Statistics
		bindParameter(statement, 3, playlist, StatisticsDateCreatedKey, eObjectTypeDate);
		bindParameter(statement, 4, playlist, StatisticsFirstPlayedDateKey, eObjectTypeDate);
		bindParameter(statement, 5, playlist, StatisticsLastPlayedDateKey, eObjectTypeDate);
		bindParameter(statement, 6, playlist, StatisticsPlayCountKey, eObjectTypeUnsignedInteger);
		
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
	NSLog(@"Smart playlist insertion time = %f seconds", elapsed);
#endif
	
	return success;
}

- (void) doUpdateSmartPlaylist:(SmartPlaylist *)playlist
{
	NSParameterAssert(nil != playlist);
	//	NSParameterAssert(nil != [playlist valueForKey:ObjectIDKey]);
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"update_smart_playlist"];
	int				result			= SQLITE_OK;
	NSDictionary	*changes		= [playlist changedValues];
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	// ID and Name
	bindNamedParameter(statement, ":id", playlist, ObjectIDKey, eObjectTypeUnsignedInteger);
	bindNamedParameter(statement, ":name", playlist, PlaylistNameKey, eObjectTypeString);

	// Predicate
	bindNamedParameter(statement, ":predicate", playlist, SmartPlaylistPredicateKey, eObjectTypePredicate);

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
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Smart playlist update time = %f seconds", elapsed);
#endif
	
	// Reset the object with the stored values
	[playlist initValuesForKeysWithDictionary:changes];
}

- (void) doDeleteSmartPlaylist:(SmartPlaylist *)playlist
{
	NSParameterAssert(nil != playlist);
	//	NSParameterAssert(nil != [playlist valueForKey:ObjectIDKey]);
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"delete_smart_playlist"];
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
	NSLog(@"Smart playlist delete time = %f seconds", elapsed);
#endif
	
	// Deregister the object
	NSMapRemove(_registeredPlaylists, (void *)objectID);
}

- (NSArray *) smartPlaylistKeys
{
	@synchronized(self) {
		if(nil == _playlistKeys) {
			_playlistKeys	= [[NSArray alloc] initWithObjects:
				ObjectIDKey, 
				PlaylistNameKey,

				SmartPlaylistPredicateKey,
				
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
