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
#import "SmartPlaylistManager.h"
#import "WatchFolderManager.h"
#import "AudioStream.h"
#import "Playlist.h"
#import "SmartPlaylist.h"
#import "WatchFolder.h"

#import "SQLiteUtilityFunctions.h"

// ========================================
// Helper functions
BOOL 
executeSQLFromFileInBundle(sqlite3		*db,
						   NSString		*filename,
						   NSError		**error)
{
	NSCParameterAssert(NULL != db);
	NSCParameterAssert(nil != filename);
	
	sqlite3_stmt	*statement		= NULL;
	NSString		*path			= [[NSBundle mainBundle] pathForResource:filename ofType:@"sql"];
	NSString		*sql			= [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:error];
	
	if(nil == sql)
		return NO;

	const char		*sqlUTF8		= [sql UTF8String];
	
	// Process every statement in the SQL file
	for(;;) {
		if(SQLITE_OK != sqlite3_prepare_v2(db, sqlUTF8, -1, &statement, &sqlUTF8)) {
			if(nil != error) {
				NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
				
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The SQL statement for \"%@\" could not be prepared.", @"Errors", @""), filename] forKey:NSLocalizedDescriptionKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"Unable to prepare SQL statement", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The SQLite error was: %@", @"Errors", @""), [NSString stringWithUTF8String:sqlite3_errmsg(db)]] forKey:NSLocalizedRecoverySuggestionErrorKey];
				
				*error = [NSError errorWithDomain:DatabaseErrorDomain 
											 code:DatabaseSQLiteError 
										 userInfo:errorDictionary];
			}
			
			return NO;
		}
		
		// If sqlite3_prepare_v2 returns NULL with no error, the end of input has been reached
		if(NULL == statement)
			break;
		
		if(SQLITE_DONE != sqlite3_step(statement)) {
			if(nil != error) {
				NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
				
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The SQL statement for \"%@\" could not be executed.", @"Errors", @""), filename] forKey:NSLocalizedDescriptionKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"Unable to execute SQL statement", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The SQLite error was: %@", @"Errors", @""), [NSString stringWithUTF8String:sqlite3_errmsg(db)]] forKey:NSLocalizedRecoverySuggestionErrorKey];
				
				*error = [NSError errorWithDomain:DatabaseErrorDomain 
											 code:DatabaseSQLiteError 
										 userInfo:errorDictionary];
			}
			
			return NO;
		}
		
		if(SQLITE_OK != sqlite3_finalize(statement)) {
			if(nil != error) {
				NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
				
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The SQL statement for \"%@\" could not be finalized.", @"Errors", @""), filename] forKey:NSLocalizedDescriptionKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"Unable to finalize SQL statement", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The SQLite error was: %@", @"Errors", @""), [NSString stringWithUTF8String:sqlite3_errmsg(db)]] forKey:NSLocalizedRecoverySuggestionErrorKey];
				
				*error = [NSError errorWithDomain:DatabaseErrorDomain 
											 code:DatabaseSQLiteError 
										 userInfo:errorDictionary];
			}
			
			return NO;
		}
	}
	
	return YES;
}

// ========================================
// Symbolic constants
NSString *const DatabaseErrorDomain = @"org.sbooth.Play.ErrorDomain.Database";

@interface CollectionManager (Private)
- (BOOL) createTables:(NSError **)error;
- (BOOL) createStreamTable:(NSError **)error;
- (BOOL) createPlaylistTable:(NSError **)error;
- (BOOL) createPlaylistEntryTable:(NSError **)error;
- (BOOL) createSmartPlaylistTable:(NSError **)error;
- (BOOL) createWatchFolderTable:(NSError **)error;
- (BOOL) createTriggers:(NSError **)error;

- (BOOL) prepareSQL:(NSError **)error;
- (BOOL) finalizeSQL:(NSError **)error;
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
	if((self = [super init]))
		_sql = [[NSMutableDictionary alloc] init];
	return self;
}

- (void) dealloc
{
	[_sql release], _sql = nil;
	[_streamManager release], _streamManager = nil;
	[_playlistManager release], _playlistManager = nil;
	[_smartPlaylistManager release], _smartPlaylistManager = nil;
	[_watchFolderManager release], _watchFolderManager = nil;

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
		if(nil == _streamManager)
			_streamManager = [[AudioStreamManager alloc] init];
	}
	return _streamManager;
}

- (PlaylistManager *) playlistManager
{
	@synchronized(self) {
		if(nil == _playlistManager)
			_playlistManager = [[PlaylistManager alloc] init];
	}
	return _playlistManager;
}

- (SmartPlaylistManager *) smartPlaylistManager
{
	@synchronized(self) {
		if(nil == _smartPlaylistManager)
			_smartPlaylistManager = [[SmartPlaylistManager alloc] init];
	}
	return _smartPlaylistManager;
}

- (WatchFolderManager *) watchFolderManager
{
	@synchronized(self) {
		if(nil == _watchFolderManager)
			_watchFolderManager = [[WatchFolderManager alloc] init];
	}
	return _watchFolderManager;
}

- (NSUndoManager *) undoManager
{
	@synchronized(self) {
		if(nil == _undoManager)
			_undoManager = [[NSUndoManager alloc] init];
	}
	return _undoManager;
}

- (void) reset
{
	[_streamManager reset];
	[_playlistManager reset];
	[_smartPlaylistManager reset];
	[_watchFolderManager reset];
}

#pragma mark Database connections

// TODO: Break this out into each sub-manager as necessary
- (BOOL) updateDatabaseIfNeeded:(NSString *)databasePath error:(NSError **)error
{
	NSParameterAssert(nil != databasePath);

	BOOL rescanMP3s = NO;
	
	sqlite3 *db = NULL;
	if(SQLITE_OK != sqlite3_open([databasePath UTF8String], &db)) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" could not be opened.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:databasePath]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Unable to open the database", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The SQLite error was: %@", @"Errors", @""), [NSString stringWithUTF8String:sqlite3_errmsg(db)]] forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:DatabaseErrorDomain 
										 code:DatabaseSQLiteError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}

	// The first database upgrade involved adding columns for MusicBrainz support
	if(NO == executeSQLFromFileInBundle(db, @"check_for_musicbrainz_support", error)) {
		if(NO == executeSQLFromFileInBundle(db, @"upgrade_database_for_musicbrainz", error))
			return NO;		
	}
	
	// The second databse upgrade consisted of removing the duration column and adding cue sheet support
	if(NO == executeSQLFromFileInBundle(db, @"check_for_cue_sheet_support", error)) {
		if(NO == executeSQLFromFileInBundle(db, @"upgrade_database_for_cue_sheets", error))
			return NO;
		
		// Unfortunately past versions did not properly set the totalFrames value for MP3s
		rescanMP3s = YES;
	}

	if(SQLITE_OK != sqlite3_close(db)) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The database could not be closed.", @"Errors", @"") forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Unable to close the database", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The SQLite error was: %@", @"Errors", @""), [NSString stringWithUTF8String:sqlite3_errmsg(db)]] forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:DatabaseErrorDomain 
										 code:DatabaseSQLiteError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	if(rescanMP3s) {
		// Display an alert since this could take a while
		NSAlert *alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:@"OK"];
		[alert setMessageText:NSLocalizedStringFromTable(@"Database Update Required", @"Database", @"")];
		[alert setInformativeText:NSLocalizedStringFromTable(@"After the update is complete durations for MP3 files in your collection will be recalculated.", @"Database", @"")];
		[alert setAlertStyle:NSInformationalAlertStyle];
		
		// Display the alert
		[alert runModal];
		[alert release];
		
		if(NO == [self connectToDatabase:databasePath error:error])
			return NO;
		
		// Grab all MP3 files
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathname ENDSWITH %@", @".mp3"];		
		NSArray *streams = [[[self streamManager] streams] filteredArrayUsingPredicate:predicate];
		
		// Rescan file properties to update total frames
		[self beginUpdate];
		[streams makeObjectsPerformSelector:@selector(rescanProperties:) withObject:self];
		[self finishUpdate];
									
		if(NO == [self disconnectFromDatabase:error])
			return NO;
	}
	
	return YES;
}

- (BOOL) connectToDatabase:(NSString *)databasePath error:(NSError **)error
{
	NSParameterAssert(nil != databasePath);
	
	if([self isConnectedToDatabase] && NO == [self disconnectFromDatabase:error])
		return NO;
	
	if(SQLITE_OK != sqlite3_open([databasePath UTF8String], &_db)) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" could not be opened.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:databasePath]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Unable to open the database", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The SQLite error was: %@", @"Errors", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]] forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:DatabaseErrorDomain 
										 code:DatabaseSQLiteError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
		
	if(NO == [self createTables:error])
		return NO;
	
	if(NO == [self prepareSQL:error])
		return NO;
	
	if(NO == [[self streamManager] connectedToDatabase:_db error:error])
		return NO;
	if(NO == [[self playlistManager] connectedToDatabase:_db error:error])
		return NO;
	if(NO == [[self smartPlaylistManager] connectedToDatabase:_db error:error])
		return NO;
	if(NO == [[self watchFolderManager] connectedToDatabase:_db error:error])
		return NO;

	return YES;
}

- (BOOL) disconnectFromDatabase:(NSError **)error
{
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	if(NO == [[self streamManager] disconnectedFromDatabase:error])
		return NO;
	if(NO == [[self playlistManager] disconnectedFromDatabase:error])
		return NO;
	if(NO == [[self smartPlaylistManager] disconnectedFromDatabase:error])
		return NO;
	if(NO == [[self watchFolderManager] disconnectedFromDatabase:error])
		return NO;

	if(NO == [self finalizeSQL:error])
		return NO;
	
	if(SQLITE_OK != sqlite3_close(_db)) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The database could not be closed.", @"Errors", @"") forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Unable to close the database", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The SQLite error was: %@", @"Errors", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]] forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:DatabaseErrorDomain 
										 code:DatabaseSQLiteError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	_db = NULL;
	[self reset];
	
	return YES;
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
	
//	[self doBeginTransaction];
	
	[[self streamManager] beginUpdate];
	[[self playlistManager] beginUpdate];
	[[self smartPlaylistManager] beginUpdate];
	[[self watchFolderManager] beginUpdate];
}

- (void) finishUpdate
{
	NSAssert(YES == [self updateInProgress], @"No update in progress");
	
	[self doBeginTransaction];

	[[self streamManager] processUpdate];
	[[self playlistManager] processUpdate];
	[[self smartPlaylistManager] processUpdate];
	[[self watchFolderManager] processUpdate];

	[self doCommitTransaction];
	
	[[self streamManager] finishUpdate];
	[[self playlistManager] finishUpdate];
	[[self smartPlaylistManager] finishUpdate];
	[[self watchFolderManager] finishUpdate];
	
	_updating = NO;	
}

- (void) cancelUpdate
{
	NSAssert(YES == [self updateInProgress], @"No update in progress");
	
	[[self streamManager] cancelUpdate];
	[[self playlistManager] cancelUpdate];
	[[self smartPlaylistManager] cancelUpdate];
	[[self watchFolderManager] cancelUpdate];

//	[self doRollbackTransaction];
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
	NSParameterAssert(nil != object);
	NSParameterAssert(nil != key);
	
	[[[self undoManager] prepareWithInvocationTarget:object] mySetValue:[object valueForKey:key] forKey:key];
	
	if([object isKindOfClass:[AudioStream class]])
		[[self streamManager] stream:(AudioStream *)object willChangeValueForKey:key];
	else if([object isKindOfClass:[Playlist class]])
		[[self playlistManager] playlist:(Playlist *)object willChangeValueForKey:key];
	else if([object isKindOfClass:[SmartPlaylist class]])
		[[self smartPlaylistManager] smartPlaylist:(SmartPlaylist *)object willChangeValueForKey:key];
	else if([object isKindOfClass:[WatchFolder class]])
		[[self watchFolderManager] watchFolder:(WatchFolder *)object willChangeValueForKey:key];
}

- (void) databaseObject:(DatabaseObject *)object didChangeValueForKey:(NSString *)key
{
	NSParameterAssert(nil != object);
	NSParameterAssert(nil != key);

	if([object isKindOfClass:[AudioStream class]])
		[[self streamManager] stream:(AudioStream *)object didChangeValueForKey:key];
	else if([object isKindOfClass:[Playlist class]])
		[[self playlistManager] playlist:(Playlist *)object didChangeValueForKey:key];
	else if([object isKindOfClass:[SmartPlaylist class]])
		[[self smartPlaylistManager] smartPlaylist:(SmartPlaylist *)object didChangeValueForKey:key];
	else if([object isKindOfClass:[WatchFolder class]])
		[[self watchFolderManager] watchFolder:(WatchFolder *)object didChangeValueForKey:key];
}

@end

@implementation CollectionManager (Private)

#pragma mark Table Creation

- (BOOL) createTables:(NSError **)error
{
	if(NO == [self createStreamTable:error])
		return NO;
	if(NO == [self createPlaylistTable:error])
		return NO;
	if(NO == [self createPlaylistEntryTable:error])
		return NO;
	if(NO == [self createSmartPlaylistTable:error])
		return NO;
	if(NO == [self createWatchFolderTable:error])
		return NO;
	
	if(NO == [self createTriggers:error])
		return NO;
	
	return YES;
}

- (BOOL) createStreamTable:(NSError **)error
{
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));

	return executeSQLFromFileInBundle(_db, @"create_stream_table", error);
}

- (BOOL) createPlaylistTable:(NSError **)error
{
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));

	return executeSQLFromFileInBundle(_db, @"create_playlist_table", error);
}

- (BOOL) createPlaylistEntryTable:(NSError **)error
{
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	return executeSQLFromFileInBundle(_db, @"create_playlist_entry_table", error);
}

- (BOOL) createSmartPlaylistTable:(NSError **)error
{
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	return executeSQLFromFileInBundle(_db, @"create_smart_playlist_table", error);
}

- (BOOL) createWatchFolderTable:(NSError **)error
{
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	return executeSQLFromFileInBundle(_db, @"create_watch_folder_table", error);
}

- (BOOL) createTriggers:(NSError **)error
{
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	if(NO == executeSQLFromFileInBundle(_db, @"delete_playlist_trigger", error) || NO == executeSQLFromFileInBundle(_db, @"delete_stream_trigger", error))
		return NO;
	else
		return YES;
}

#pragma mark Prepared SQL Statements

- (BOOL) prepareSQL:(NSError **)error
{
	NSString		*path				= nil;
	NSString		*sql				= nil;
	NSArray			*files				= [NSArray arrayWithObjects:@"begin_transaction", @"commit_transaction", @"rollback_transaction", nil];
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
