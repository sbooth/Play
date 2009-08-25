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

#import "WatchFolderManager.h"
#import "CollectionManager.h"
#import "AudioStreamManager.h"
#import "AudioStream.h"
#import "WatchFolder.h"
#import "AudioLibrary.h"

#import "SQLiteUtilityFunctions.h"

@interface WatchFolderManager (Private)
- (BOOL) prepareSQL:(NSError **)error;
- (BOOL) finalizeSQL:(NSError **)error;
- (sqlite3_stmt *) preparedStatementForAction:(NSString *)action;

- (BOOL) isConnectedToDatabase;
- (BOOL) updateInProgress;

- (NSArray *) fetchWatchFolders;

- (WatchFolder *) loadWatchFolder:(sqlite3_stmt *)statement;

- (BOOL) doInsertWatchFolder:(WatchFolder *)folder;
- (void) doUpdateWatchFolder:(WatchFolder *)folder;
- (void) doDeleteWatchFolder:(WatchFolder *)folder;

- (NSArray *) watchFolderKeys;
@end

@implementation WatchFolderManager

- (id) init
{
	if((self = [super init])) {
		_registeredFolders	= NSCreateMapTable(NSIntegerMapKeyCallBacks, NSObjectMapValueCallBacks, 4096);		
		_sql				= [[NSMutableDictionary alloc] init];
		_insertedFolders	= [[NSMutableSet alloc] init];
		_updatedFolders		= [[NSMutableSet alloc] init];
		_deletedFolders		= [[NSMutableSet alloc] init];	
	}
	return self;
}

- (void) dealloc
{
	NSFreeMapTable(_registeredFolders), _registeredFolders = NULL;	
	
	[_sql release], _sql = nil;
	
	[_cachedFolders release], _cachedFolders = nil;
	
	[_insertedFolders release], _insertedFolders = nil;
	[_updatedFolders release], _updatedFolders = nil;
	[_deletedFolders release], _deletedFolders = nil;
	
	[_folderKeys release], _folderKeys = nil;
	
	_db = NULL;
	
	[super dealloc];
}

#pragma mark WatchFolder support

- (NSArray *) watchFolders
{
	@synchronized(self) {
		if(nil == _cachedFolders)
			_cachedFolders = [[self fetchWatchFolders] retain];
	}
	return _cachedFolders;
}

- (WatchFolder *) watchFolderForID:(NSNumber *)objectID
{
	NSParameterAssert(nil != objectID);
	
	WatchFolder *folder = (WatchFolder *)NSMapGet(_registeredFolders, (void *)[objectID unsignedIntValue]);
	if(nil != folder)
		return folder;
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"select_watch_folder_by_id"];
	int				result			= SQLITE_OK;
				
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":id"), [objectID unsignedIntValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	while(SQLITE_ROW == (result = sqlite3_step(statement)))
		folder = [self loadWatchFolder:statement];
	
	NSAssert1(SQLITE_DONE == result, @"Error while fetching folder (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Loaded watch folder in %f seconds", elapsed);
#endif
	
	return folder;
}

// ========================================
// Insert
- (BOOL) insertWatchFolder:(WatchFolder *)folder
{
	NSParameterAssert(nil != folder);
	
	BOOL result = YES;
	
	if([self updateInProgress])
		[_insertedFolders addObject:folder];
	else {
		NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([_cachedFolders count], 1)];
		
		result = [self doInsertWatchFolder:folder];
		if(result) {
			[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"watchFolders"];
			[_cachedFolders addObject:folder];	
			[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"watchFolders"];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:WatchFolderAddedToLibraryNotification 
																object:self 
															  userInfo:[NSDictionary dictionaryWithObject:folder forKey:WatchFolderObjectKey]];
		}
	}
	
	return result;
}

// ========================================
// Update
- (void) saveWatchFolder:(WatchFolder *)folder
{
	NSParameterAssert(nil != folder);
	
	if(NO == [folder hasChanges])
		return;
	
	if([self updateInProgress])
		[_updatedFolders addObject:folder];
	else {
		[self doUpdateWatchFolder:folder];	
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WatchFolderDidChangeNotification 
															object:self 
														  userInfo:[NSDictionary dictionaryWithObject:folder forKey:WatchFolderObjectKey]];
	}
}

// ========================================
// Delete
- (void) deleteWatchFolder:(WatchFolder *)folder
{
	NSParameterAssert(nil != folder);
	
	if([self updateInProgress])
		[_deletedFolders addObject:folder];
	else {
		NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:[_cachedFolders indexOfObject:folder]];
		
		[self doDeleteWatchFolder:folder];
		[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"watchFolders"];
		[_cachedFolders removeObject:folder];	
		[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"watchFolders"];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WatchFolderRemovedFromLibraryNotification 
															object:self 
														  userInfo:[NSDictionary dictionaryWithObject:folder forKey:WatchFolderObjectKey]];		
	}
}

- (void) revertWatchFolder:(WatchFolder *)folder
{
	NSParameterAssert(nil != folder);
	
	NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:[_cachedFolders indexOfObject:folder]];
	
	if(NO == [self updateInProgress])
		[self willChange:NSKeyValueChangeSetting valuesAtIndexes:indexes forKey:@"watchFolders"];
	
	[folder revert];
	
	if(NO == [self updateInProgress])
		[self didChange:NSKeyValueChangeSetting valuesAtIndexes:indexes forKey:@"watchFolders"];
}

#pragma mark Metadata support

- (id) valueForKey:(NSString *)key
{
	if([[self watchFolderKeys] containsObject:key])
		return [[self watchFolders] valueForKey:key];
	else
		return [super valueForKey:key];
}

@end

@implementation WatchFolderManager (CollectionManagerMethods)

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
	[self willChangeValueForKey:@"watchFolders"];
	NSResetMapTable(_registeredFolders);
	[_cachedFolders release], _cachedFolders = nil;
	[self didChangeValueForKey:@"watchFolders"];
}

- (void) beginUpdate
{
	NSAssert(NO == _updating, @"Update already in progress");
	
	_updating = YES;
	
	[_insertedFolders removeAllObjects];
	[_updatedFolders removeAllObjects];
	[_deletedFolders removeAllObjects];
}

- (void) processUpdate
{
	NSAssert(YES == _updating, @"No update in progress");
	
	// ========================================
	// Process updates first
	if(0 != [_updatedFolders count]) {
		for(WatchFolder *folder in _updatedFolders)
			[self doUpdateWatchFolder:folder];
	}
	
	// ========================================
	// Processes deletes next
	if(0 != [_deletedFolders count]) {
		for(WatchFolder *folder in _deletedFolders)
			[self doDeleteWatchFolder:folder];
	}
	
	// ========================================
	// Finally, process inserts, removing any that fail
	if(0 != [_insertedFolders count]) {
		for(WatchFolder *folder in _insertedFolders) {
			if(NO == [self doInsertWatchFolder:folder])
				[_insertedFolders removeObject:folder];
		}
	}	
}

- (void) finishUpdate
{
	NSAssert(YES == _updating, @"No update in progress");
	
	NSMutableIndexSet 	*indexes 		= [[NSMutableIndexSet alloc] init];
	
	// ========================================
	// Broadcast the notifications
	if(0 != [_updatedFolders count]) {
		for(WatchFolder *folder in _updatedFolders)
			[[NSNotificationCenter defaultCenter] postNotificationName:WatchFolderDidChangeNotification 
																object:self 
															  userInfo:[NSDictionary dictionaryWithObject:folder forKey:WatchFolderObjectKey]];		
		
		[_updatedFolders removeAllObjects];
	}
	
	// ========================================
	// Handle deletes
	if(0 != [_deletedFolders count]) {
		for(WatchFolder *folder in _deletedFolders)
			[indexes addIndex:[_cachedFolders indexOfObject:folder]];
		
		[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"watchFolders"];

		for(WatchFolder *folder in _deletedFolders) {
			[_cachedFolders removeObject:folder];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:WatchFolderRemovedFromLibraryNotification 
																object:self
															  userInfo:[NSDictionary dictionaryWithObject:folder forKey:WatchFolderObjectKey]];
		}
		
		[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"watchFolders"];		
		
		[_deletedFolders removeAllObjects];
		[indexes removeAllIndexes];
	}
	
	// ========================================
	// And finally inserts
	if(0 != [_insertedFolders count]) {
		[indexes addIndexesInRange:NSMakeRange([_cachedFolders count], [_insertedFolders count])];
		
		[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"watchFolders"];

		for(WatchFolder *folder in _insertedFolders) {
			[_cachedFolders addObject:folder];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:WatchFolderAddedToLibraryNotification 
																object:self 
															  userInfo:[NSDictionary dictionaryWithObject:folder forKey:WatchFolderObjectKey]];
		}
		
		[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"watchFolders"];
		
		[_insertedFolders removeAllObjects];
	}
	
	_updating = NO;
	
	[indexes release];
}

- (void) cancelUpdate
{
	NSAssert(YES == _updating, @"No update in progress");
	
	// For a canceled update, revert the updated streams and forget about anything else
	if(0 != [_updatedFolders count]) {		
		for(WatchFolder *folder in _updatedFolders)
			[folder revert];
	}
	
	[_insertedFolders removeAllObjects];
	[_updatedFolders removeAllObjects];
	[_deletedFolders removeAllObjects];
	
	_updating = NO;
}

- (void) watchFolder:(WatchFolder *)folder willChangeValueForKey:(NSString *)key
{
	unsigned index = [_cachedFolders indexOfObject:folder];
		
	if(NSNotFound != index)
		[self willChange:NSKeyValueChangeSetting valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:key];
}

- (void) watchFolder:(WatchFolder *)folder didChangeValueForKey:(NSString *)key
{
	unsigned index = [_cachedFolders indexOfObject:folder];
	
	if(NSNotFound != index) {
		[self saveWatchFolder:folder];	
		[self didChange:NSKeyValueChangeSetting valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:key];
	}
}

@end

@implementation WatchFolderManager (Private)

#pragma mark Prepared SQL Statements

- (BOOL) prepareSQL:(NSError **)error
{
	NSString		*path				= nil;
	NSString		*sql				= nil;
	NSArray			*files				= [NSArray arrayWithObjects:
		@"select_all_watch_folders", @"select_watch_folder_by_id", @"insert_watch_folder", @"update_watch_folder", @"delete_watch_folder", nil];
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

- (NSArray *) fetchWatchFolders
{
	NSMutableArray	*folders		= [[NSMutableArray alloc] init];
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"select_all_watch_folders"];
	int				result			= SQLITE_OK;
	WatchFolder		*folder			= nil;
				
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	while(SQLITE_ROW == (result = sqlite3_step(statement))) {
		folder = [self loadWatchFolder:statement];
		[folders addObject:folder];
	}
	
	NSAssert1(SQLITE_DONE == result, @"Error while fetching watch folders (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Loaded %i watch folders in %f seconds (%f per second)", [folders count], elapsed, (double)[folders count] / elapsed);
#endif
	
	return [folders autorelease];
}

- (WatchFolder *) loadWatchFolder:(sqlite3_stmt *)statement
{
	WatchFolder		*folder		= nil;
	unsigned		objectID;
	
	// The ID should never be NULL
	NSAssert(SQLITE_NULL != sqlite3_column_type(statement, 0), @"No ID found for folder");
	objectID = sqlite3_column_int(statement, 0);
	
	folder = (WatchFolder *)NSMapGet(_registeredFolders, (void *)objectID);
	if(nil != folder)
		return folder;
	
	folder = [[WatchFolder alloc] init];
	
	// WatchFolder ID and name
	[folder initValue:[NSNumber numberWithUnsignedInt:objectID] forKey:ObjectIDKey];
	//	getColumnValue(statement, 0, folder, ObjectIDKey, eObjectTypeUnsignedInt);
	getColumnValue(statement, 1, folder, WatchFolderURLKey, eObjectTypeURL);
	getColumnValue(statement, 2, folder, WatchFolderNameKey, eObjectTypeString);
		
	// Register the object	
	NSMapInsert(_registeredFolders, (void *)objectID, (void *)folder);
	
	return [folder autorelease];
}

#pragma mark WatchFolders

- (BOOL) doInsertWatchFolder:(WatchFolder *)folder
{
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"insert_watch_folder"];
	int				result			= SQLITE_OK;
	BOOL			success			= YES;
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	@try {
		bindParameter(statement, 1, folder, WatchFolderURLKey, eObjectTypeURL);
		bindParameter(statement, 2, folder, WatchFolderNameKey, eObjectTypeString);
				
		result = sqlite3_step(statement);
		NSAssert2(SQLITE_DONE == result, @"Unable to insert a record for %@ (%@).", [folder valueForKey:WatchFolderNameKey], [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		[folder initValue:[NSNumber numberWithInt:sqlite3_last_insert_rowid(_db)] forKey:ObjectIDKey];
		
		result = sqlite3_reset(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_clear_bindings(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);

		// Register the object	
		NSMapInsert(_registeredFolders, (void *)[[folder valueForKey:ObjectIDKey] unsignedIntValue], (void *)folder);
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
	NSLog(@"Watch folder insertion time = %f seconds", elapsed);
#endif
	
	return success;
}

- (void) doUpdateWatchFolder:(WatchFolder *)folder
{
	NSParameterAssert(nil != folder);
	//	NSParameterAssert(nil != [folder valueForKey:ObjectIDKey]);
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"update_watch_folder"];
	int				result			= SQLITE_OK;
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	// ID, URL and Name
	bindNamedParameter(statement, ":id", folder, ObjectIDKey, eObjectTypeUnsignedInt);
	bindNamedParameter(statement, ":url", folder, WatchFolderURLKey, eObjectTypeURL);
	bindNamedParameter(statement, ":name", folder, WatchFolderNameKey, eObjectTypeString);
	
	result = sqlite3_step(statement);
	NSAssert2(SQLITE_DONE == result, @"Unable to update the record for %@ (%@).", folder, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_clear_bindings(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Watch folder update time = %f seconds", elapsed);
#endif
	
	// Reset the object with the stored values
	[folder synchronizeSavedValuesWithChangedValues];
}

- (void) doDeleteWatchFolder:(WatchFolder *)folder
{
	NSParameterAssert(nil != folder);
	//	NSParameterAssert(nil != [folder valueForKey:ObjectIDKey]);
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"delete_watch_folder"];
	int				result			= SQLITE_OK;
	unsigned		objectID		= [[folder valueForKey:ObjectIDKey] unsignedIntValue];
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":id"), objectID);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert2(SQLITE_DONE == result, @"Unable to delete the record for %@ (%@).", folder, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_clear_bindings(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Watch folder delete time = %f seconds", elapsed);
#endif
	
	// Deregister the object
	NSMapRemove(_registeredFolders, (void *)objectID);
}

- (NSArray *) watchFolderKeys
{
	@synchronized(self) {
		if(nil == _folderKeys) {
			_folderKeys	= [[NSArray alloc] initWithObjects:
				ObjectIDKey, 
				
				WatchFolderURLKey,
				WatchFolderNameKey,
				
				nil];			
		}
	}
	return _folderKeys;
}

@end
