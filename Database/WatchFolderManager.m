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

#import "UKKQueue.h"

#import "SQLiteUtilityFunctions.h"

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

@interface WatchFolderManager (UKFileWatcherDelegateMethods)
-(void) watcher:(id<UKFileWatcher>)kq receivedNotification:(NSString*)nm forPath:(NSString*)fpath;
@end

@interface WatchFolderManager (Private)
- (void) 			prepareSQL;
- (void) 			finalizeSQL;
- (sqlite3_stmt *) 	preparedStatementForAction:(NSString *)action;

- (BOOL) isConnectedToDatabase;
- (BOOL) updateInProgress;

- (NSArray *) fetchWatchFolders;

- (WatchFolder *) loadWatchFolder:(sqlite3_stmt *)statement;

- (BOOL) doInsertWatchFolder:(WatchFolder *)folder;
- (void) doUpdateWatchFolder:(WatchFolder *)folder;
- (void) doDeleteWatchFolder:(WatchFolder *)folder;

- (NSArray *) watchFolderKeys;

- (UKKQueue *) kq;

- (void) synchronizeLibraryStreamsWithURL:(NSURL *)url;
@end

@implementation WatchFolderManager

- (id) init
{
	if((self = [super init])) {
		_registeredFolders	= NSCreateMapTable(NSIntMapKeyCallBacks, NSObjectMapValueCallBacks, 4096);		
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
		if(nil == _cachedFolders) {
			_cachedFolders = [[self fetchWatchFolders] retain];
		}
	}
	return _cachedFolders;
}

- (WatchFolder *) watchFolderForID:(NSNumber *)objectID
{
	NSParameterAssert(nil != objectID);
	
	WatchFolder *folder = (WatchFolder *)NSMapGet(_registeredFolders, (void *)[objectID unsignedIntValue]);
	if(nil != folder) {
		return folder;
	}
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"select_watch_folder_by_id"];
	int				result			= SQLITE_OK;
				
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":id"), [objectID unsignedIntValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	while(SQLITE_ROW == (result = sqlite3_step(statement))) {
		folder = [self loadWatchFolder:statement];
	}
	
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
	
	if([self updateInProgress]) {
		[_insertedFolders addObject:folder];
	}
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
	
	if(NO == [folder hasChanges]) {
		return;
	}
	
	if([self updateInProgress]) {
		[_updatedFolders addObject:folder];
	}
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
	
	if([self updateInProgress]) {
		[_deletedFolders addObject:folder];
	}
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
	
	if(NO == [self updateInProgress]) {
		[self willChange:NSKeyValueChangeSetting valuesAtIndexes:indexes forKey:@"watchFolders"];
	}
	
	[folder revert];
	
	if(NO == [self updateInProgress]) {
		[self didChange:NSKeyValueChangeSetting valuesAtIndexes:indexes forKey:@"watchFolders"];
	}
}

#pragma mark Metadata support

- (id) valueForKey:(NSString *)key
{
	if([[self watchFolderKeys] containsObject:key]) {
		return [[self watchFolders] valueForKey:key];
	}
	else {
		return [super valueForKey:key];
	}
}

@end

@implementation WatchFolderManager (CollectionManagerMethods)

- (void) connectedToDatabase:(sqlite3 *)db
{
	_db = db;
	[self prepareSQL];
	
	// Load all the watch folders and update the library contents (in the background because this is a potentially slow operation)
	NSEnumerator *enumerator = [[self watchFolders] objectEnumerator];
	WatchFolder *watchFolder = nil;
	NSURL *url = nil;
	while((watchFolder = [enumerator nextObject])) {
		url = [watchFolder valueForKey:WatchFolderURLKey];
		[NSThread detachNewThreadSelector:@selector(synchronizeLibraryStreamsWithURL:) toTarget:self withObject:url];
		[[self kq] addPath:[url path]];
	}
}

- (void) disconnectedFromDatabase
{
	[[self kq] removeAllPathsFromQueue];
	[self finalizeSQL];
	_db = NULL;
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
	
	NSEnumerator 		*enumerator 	= nil;
	WatchFolder			*folder 		= nil;
	
	// ========================================
	// Process updates first
	if(0 != [_updatedFolders count]) {
		enumerator = [_updatedFolders objectEnumerator];
		while((folder = [enumerator nextObject])) {
			[self doUpdateWatchFolder:folder];
		}
	}
	
	// ========================================
	// Processes deletes next
	if(0 != [_deletedFolders count]) {
		enumerator = [_deletedFolders objectEnumerator];
		while((folder = [enumerator nextObject])) {
			[self doDeleteWatchFolder:folder];
		}
	}
	
	// ========================================
	// Finally, process inserts, removing any that fail
	if(0 != [_insertedFolders count]) {
		enumerator = [[_insertedFolders allObjects] objectEnumerator];
		while((folder = [enumerator nextObject])) {
			if(NO == [self doInsertWatchFolder:folder]) {
				[_insertedFolders removeObject:folder];
			}
		}
	}	
}

- (void) finishUpdate
{
	NSAssert(YES == _updating, @"No update in progress");
	
	NSEnumerator 		*enumerator 	= nil;
	WatchFolder			*folder 		= nil;
	NSMutableIndexSet 	*indexes 		= [[NSMutableIndexSet alloc] init];
	
	// ========================================
	// Broadcast the notifications
	if(0 != [_updatedFolders count]) {
		enumerator = [_updatedFolders objectEnumerator];
		while((folder = [enumerator nextObject])) {
			[[NSNotificationCenter defaultCenter] postNotificationName:WatchFolderDidChangeNotification 
																object:self 
															  userInfo:[NSDictionary dictionaryWithObject:folder forKey:WatchFolderObjectKey]];		
		}		
		
		[_updatedFolders removeAllObjects];
	}
	
	// ========================================
	// Handle deletes
	if(0 != [_deletedFolders count]) {
		enumerator = [_deletedFolders objectEnumerator];
		while((folder = [enumerator nextObject])) {
			[indexes addIndex:[_cachedFolders indexOfObject:folder]];
		}
		
		[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"watchFolders"];
		enumerator = [_deletedFolders objectEnumerator];
		while((folder = [enumerator nextObject])) {
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
		enumerator = [[_insertedFolders allObjects] objectEnumerator];
		while((folder = [enumerator nextObject])) {
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
		NSEnumerator	*enumerator 	= nil;
		WatchFolder		*folder 		= nil;
		
		enumerator = [_updatedFolders objectEnumerator];
		while((folder = [enumerator nextObject])) {
			[folder revert];
		}
	}
	
	[_insertedFolders removeAllObjects];
	[_updatedFolders removeAllObjects];
	[_deletedFolders removeAllObjects];
	
	_updating = NO;
}

- (void) watchFolder:(WatchFolder *)folder willChangeValueForKey:(NSString *)key
{
	unsigned index = [_cachedFolders indexOfObject:folder];
		
	if(NSNotFound != index) {
		[self willChange:NSKeyValueChangeSetting valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:key];
	}
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

@implementation WatchFolderManager (UKFileWatcherDelegateMethods)

-(void) watcher:(id<UKFileWatcher>)kq receivedNotification:(NSString*)nm forPath:(NSString*)fpath
{
	/*
	 extern NSString* UKFileWatcherRenameNotification;
	 extern NSString* UKFileWatcherWriteNotification;
	 extern NSString* UKFileWatcherDeleteNotification;
	 extern NSString* UKFileWatcherAttributeChangeNotification;
	 extern NSString* UKFileWatcherSizeIncreaseNotification;
	 extern NSString* UKFileWatcherLinkCountChangeNotification;
	 extern NSString* UKFileWatcherAccessRevocationNotification;
	 */
	NSLog(@"receivedNotification:%@ forPath:%@", nm, fpath);

	NSURL *url = [NSURL fileURLWithPath:fpath];
	[NSThread detachNewThreadSelector:@selector(synchronizeLibraryStreamsWithURL:) toTarget:self withObject:url];
}

@end

@implementation WatchFolderManager (Private)

#pragma mark Prepared SQL Statements

- (void) prepareSQL
{
	NSError			*error				= nil;	
	NSString		*path				= nil;
	NSString		*sql				= nil;
	NSString		*filename			= nil;
	NSArray			*files				= [NSArray arrayWithObjects:
		@"select_all_watch_folders", @"select_watch_folder_by_id", @"insert_watch_folder", @"update_watch_folder", @"delete_watch_folder", nil];
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
	if(nil != folder) {
		return folder;
	}
	
	folder = [[WatchFolder alloc] init];
	
	// WatchFolder ID and name
	[folder initValue:[NSNumber numberWithUnsignedInt:objectID] forKey:ObjectIDKey];
	//	getColumnValue(statement, 0, folder, ObjectIDKey, eObjectTypeUnsignedInteger);
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
	NSDictionary	*changes		= [folder changedValues];
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	// ID, URL and Name
	bindNamedParameter(statement, ":id", folder, ObjectIDKey, eObjectTypeUnsignedInteger);
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
	[folder initValuesForKeysWithDictionary:changes];
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

- (UKKQueue *) kq
{
	if(nil == _kq) {
		_kq = [[UKKQueue alloc] init];
		[_kq setDelegate:self];
	}
	return _kq;
}

#pragma mark URL and AudioStream Addition

- (void) synchronizeLibraryStreamsWithURL:(NSURL *)url
{
	NSParameterAssert(nil != url);

	// First grab the paths for the streams in the library under this url
	NSAutoreleasePool	*pool				= [[NSAutoreleasePool alloc] init];
	NSArray				*libraryStreams		= [[[CollectionManager manager] streamManager] streamsContainedByURL:url];
	NSEnumerator		*enumerator			= [libraryStreams objectEnumerator];
	AudioStream			*stream				= nil;
	NSMutableSet		*libraryFilenames	= [NSMutableSet set];
	
	while((stream = [enumerator nextObject])) {
		[libraryFilenames addObject:[[stream valueForKey:StreamURLKey] path]];
	}
	
	// Next iterate through and see what is actually in the directory
	NSMutableSet	*physicalFilenames	= [NSMutableSet set];
	NSArray			*allowedTypes		= getAudioExtensions();
	NSString		*path				= [url path];
	NSString		*filename			= nil;
	BOOL			isDir;
	BOOL			result				= [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
	
	if(NO == result || NO == isDir) {
		NSLog(@"Unable to locate folder \"%@\".", path);
		return;
	}
	
	NSDirectoryEnumerator *directoryEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:path];
	
	while((filename = [directoryEnumerator nextObject])) {
		if([allowedTypes containsObject:[filename pathExtension]]) {
			[physicalFilenames addObject:[path stringByAppendingPathComponent:filename]];
		}
	}

	// Determine if any files were deleted
	NSMutableSet	*removedFilenames		= [NSMutableSet setWithSet:libraryFilenames];
	[removedFilenames minusSet:physicalFilenames];

	// Determine if any files were added
	NSMutableSet	*addedFilenames			= [NSMutableSet setWithSet:physicalFilenames];
	[addedFilenames minusSet:libraryFilenames];

	if(0 != [addedFilenames count]) {
		[[AudioLibrary library] performSelectorOnMainThread:@selector(addFiles:) withObject:[addedFilenames allObjects] waitUntilDone:YES];
	}
	
	if(0 != [removedFilenames count]) {
		[[AudioLibrary library] performSelectorOnMainThread:@selector(removeFiles:) withObject:[removedFilenames allObjects] waitUntilDone:YES];
	}
	
	[pool release];
}

@end
