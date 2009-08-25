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

#import "AudioStreamManager.h"
#import "CollectionManager.h"
#import "AudioStream.h"
#import "Playlist.h"
#import "SmartPlaylist.h"
#import "WatchFolder.h"
#import "AudioLibrary.h"

#import "SQLiteUtilityFunctions.h"

@interface AudioStreamManager (Private)
- (BOOL) prepareSQL:(NSError **)error;
- (BOOL) finalizeSQL:(NSError **)error;
- (sqlite3_stmt *) preparedStatementForAction:(NSString *)action;

- (BOOL) isConnectedToDatabase;
- (BOOL) updateInProgress;

- (NSArray *) fetchStreams;

- (AudioStream *) loadStream:(sqlite3_stmt *)statement;

- (BOOL) doInsertStream:(AudioStream *)stream;
- (void) doUpdateStream:(AudioStream *)stream;
- (void) doDeleteStream:(AudioStream *)stream;

- (NSArray *) streamKeys;
@end

@implementation AudioStreamManager

- (id) init
{
	if((self = [super init])) {
		_registeredStreams	= NSCreateMapTable(NSIntegerMapKeyCallBacks, NSObjectMapValueCallBacks, 4096);		
		_sql				= [[NSMutableDictionary alloc] init];
		_insertedStreams	= [[NSMutableSet alloc] init];
		_updatedStreams		= [[NSMutableSet alloc] init];
		_deletedStreams		= [[NSMutableSet alloc] init];	
	}
	return self;
}

- (void) dealloc
{
	NSFreeMapTable(_registeredStreams), _registeredStreams = NULL;	

	[_sql release], _sql = nil;

	[_cachedStreams release], _cachedStreams = nil;

	[_insertedStreams release], _insertedStreams = nil;
	[_updatedStreams release], _updatedStreams = nil;
	[_deletedStreams release], _deletedStreams = nil;

	[_streamKeys release], _streamKeys = nil;

	_db = NULL;

	[super dealloc];
}

#pragma mark AudioStream support

- (NSArray *) streams
{
	@synchronized(self) {
		if(nil == _cachedStreams)
			_cachedStreams = [[self fetchStreams] retain];
	}
	return _cachedStreams;
}

- (NSArray *) streamsForArtist:(NSString *)artist
{
	NSParameterAssert(nil != artist);
		
	return [[self streams] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"%K == %@", MetadataArtistKey, artist]];
}

- (NSArray *) streamsForAlbumTitle:(NSString *)albumTitle
{
	NSParameterAssert(nil != albumTitle);

	return [[self streams] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"%K == %@", MetadataAlbumTitleKey, albumTitle]];
}

- (NSArray *) streamsForGenre:(NSString *)genre
{
	NSParameterAssert(nil != genre);
	
	return [[self streams] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"%K == %@", MetadataGenreKey, genre]];
}

- (NSArray *) streamsForComposer:(NSString *)composer
{
	NSParameterAssert(nil != composer);
	
	return [[self streams] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"%K == %@", MetadataComposerKey, composer]];
}

- (NSArray *) streamsContainedByURL:(NSURL *)url
{
	NSParameterAssert(nil != url);
	
	NSMutableArray	*streams		= [[NSMutableArray alloc] init];
	NSURL			*streamURL		= nil;
	
	for(AudioStream *stream in [self streams]) {
		streamURL = [stream valueForKey:StreamURLKey];
		if([[streamURL path] hasPrefix:[url path]])
			[streams addObject:stream];
	}
	
	return [streams autorelease];
}

- (AudioStream *) streamForID:(NSNumber *)objectID
{
	NSParameterAssert(nil != objectID);
	
	AudioStream *stream = (AudioStream *)NSMapGet(_registeredStreams, (void *)[objectID unsignedIntValue]);
	if(nil != stream)
		return stream;
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"select_stream_by_id"];
	int				result			= SQLITE_OK;
				
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":id"), [objectID unsignedIntValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	while(SQLITE_ROW == (result = sqlite3_step(statement)))
		stream = [self loadStream:statement];
	
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

- (AudioStream *) streamForURL:(NSURL *)url
{
	return [self streamForURL:url startingFrame:[NSNumber numberWithInt:-1] frameCount:[NSNumber numberWithInt:-1]];
}

- (AudioStream *) streamForURL:(NSURL *)url startingFrame:(NSNumber *)startingFrame
{
	return [self streamForURL:url startingFrame:startingFrame frameCount:[NSNumber numberWithInt:-1]];
}

- (AudioStream *) streamForURL:(NSURL *)url startingFrame:(NSNumber *)startingFrame frameCount:(NSNumber *)frameCount
{
	NSParameterAssert(nil != url);
	NSParameterAssert(nil != startingFrame);
	NSParameterAssert(nil != frameCount);

	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"select_stream_by_url"];
	int				result			= SQLITE_OK;
	AudioStream		*stream			= nil;
				
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	result = sqlite3_bind_text(statement, sqlite3_bind_parameter_index(statement, ":url"), [[url absoluteString] UTF8String], -1, SQLITE_TRANSIENT);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);

	result = sqlite3_bind_int64(statement, sqlite3_bind_parameter_index(statement, ":starting_frame"), [startingFrame longLongValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);

	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":frame_count"), [frameCount unsignedIntValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);

	while(SQLITE_ROW == (result = sqlite3_step(statement)))
		stream = [self loadStream:statement];
	
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

// ========================================
// Insert
- (BOOL) insertStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);

	BOOL result = YES;
	
	if([self updateInProgress])
		[_insertedStreams addObject:stream];
	else {
		NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([_cachedStreams count], 1)];

		result = [self doInsertStream:stream];
		if(result) {
			[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"streams"];
			[_cachedStreams addObject:stream];	
			[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"streams"];
		
			[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamAddedToLibraryNotification 
																object:self 
															  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
		}
	}
	
	return result;
}

// ========================================
// Update
- (void) saveStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	
	if(NO == [stream hasChanges])
		return;
	
	if([self updateInProgress])
		[_updatedStreams addObject:stream];
	else {
		[self doUpdateStream:stream];	
		
		[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamDidChangeNotification 
															object:self 
														  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
	}
}

// ========================================
// Delete
- (void) deleteStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);

	if([self updateInProgress])
		[_deletedStreams addObject:stream];
	else {
		NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:[_cachedStreams indexOfObject:stream]];
		
		[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"streams"];
		[self doDeleteStream:stream];
		[_cachedStreams removeObject:stream];	
		[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"streams"];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamRemovedFromLibraryNotification 
															object:self 
														  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];		
	}
}

- (void) revertStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	
	NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:[_cachedStreams indexOfObject:stream]];

	if(NO == [self updateInProgress])
		[self willChange:NSKeyValueChangeSetting valuesAtIndexes:indexes forKey:@"streams"];

	[stream revert];
	
	if(NO == [self updateInProgress])
		[self didChange:NSKeyValueChangeSetting valuesAtIndexes:indexes forKey:@"streams"];
}

#pragma mark Metadata support

- (id) valueForKey:(NSString *)key
{
	if([[self streamKeys] containsObject:key])
		return [[self streams] valueForKey:key];
	else
		return [super valueForKey:key];
}

@end

@implementation AudioStreamManager (CollectionManagerMethods)

- (BOOL) connectedToDatabase:(sqlite3 *)db error:(NSError **)error
{
	NSParameterAssert(NULL != db);
	
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
	[self willChangeValueForKey:@"streams"];
	NSResetMapTable(_registeredStreams);
	[_cachedStreams release], _cachedStreams = nil;
	[self didChangeValueForKey:@"streams"];
}

- (void) beginUpdate
{
	NSAssert(NO == _updating, @"Update already in progress");
	
	_updating = YES;
	
	[_insertedStreams removeAllObjects];
	[_updatedStreams removeAllObjects];
	[_deletedStreams removeAllObjects];
}

- (void) processUpdate
{
	NSAssert(YES == _updating, @"No update in progress");
		
	// ========================================
	// Process updates first
	if(0 != [_updatedStreams count]) {
		for(AudioStream *stream in _updatedStreams)
			[self doUpdateStream:stream];
	}
	
	// ========================================
	// Processes deletes next
	if(0 != [_deletedStreams count]) {
		for(AudioStream *stream in _deletedStreams)
			[self doDeleteStream:stream];
	}
	
	// ========================================
	// Finally, process inserts, removing any that fail
	if(0 != [_insertedStreams count]) {
		for(AudioStream *stream in _insertedStreams) {
			if(NO == [self doInsertStream:stream])
				[_insertedStreams removeObject:stream];
		}
	}	
}

- (void) finishUpdate
{
	NSAssert(YES == _updating, @"No update in progress");

	NSMutableIndexSet 	*indexes 		= [[NSMutableIndexSet alloc] init];
	NSMutableArray		*streams		= nil;
	
	// ========================================
	// Broadcast the notifications
	if(0 != [_updatedStreams count]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamsDidChangeNotification 
															object:self
														  userInfo:[NSDictionary dictionaryWithObject:[_updatedStreams allObjects] forKey:AudioStreamsObjectKey]];		
	
		[_updatedStreams removeAllObjects];
	}

	// ========================================
	// Handle deletes
	if(0 != [_deletedStreams count]) {
		streams = [NSMutableArray array];
		
		for(AudioStream *stream in _deletedStreams)
			[indexes addIndex:[_cachedStreams indexOfObject:stream]];

		[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"streams"];
		
		for(AudioStream *stream in _deletedStreams) {
			[streams addObject:stream];
			[_cachedStreams removeObject:stream];
		}
		
		[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"streams"];		

		[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamsRemovedFromLibraryNotification 
															object:self
														  userInfo:[NSDictionary dictionaryWithObject:streams forKey:AudioStreamsObjectKey]];
		
		[_deletedStreams removeAllObjects];
		[indexes removeAllIndexes];
	}

	// ========================================
	// And finally inserts
	if(0 != [_insertedStreams count]) {
		streams = [NSMutableArray array];
		
		[indexes addIndexesInRange:NSMakeRange([_cachedStreams count], [_insertedStreams count])];
		[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"streams"];

		for(AudioStream *stream in _insertedStreams) {
			[streams addObject:stream];
			[_cachedStreams addObject:stream];
		}
		
		[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"streams"];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamsAddedToLibraryNotification 
															object:self
														  userInfo:[NSDictionary dictionaryWithObject:streams forKey:AudioStreamsObjectKey]];
		
		[_insertedStreams removeAllObjects];
	}
		
	_updating = NO;
	
	[indexes release];
}

- (void) cancelUpdate
{
	NSAssert(YES == _updating, @"No update in progress");

	// For a canceled update, revert the updated streams and forget about anything else
	if(0 != [_updatedStreams count]) {		
		for(AudioStream *stream in _updatedStreams)
			[stream revert];
	}

	[_insertedStreams removeAllObjects];
	[_updatedStreams removeAllObjects];
	[_deletedStreams removeAllObjects];
	
	_updating = NO;
}

- (void) stream:(AudioStream *)stream willChangeValueForKey:(NSString *)key
{
	NSParameterAssert(nil != stream);
	NSParameterAssert(nil != key);

	unsigned index = [_cachedStreams indexOfObject:stream];
	
	if(NSNotFound != index)
		[self willChange:NSKeyValueChangeSetting valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:key];
}

- (void) stream:(AudioStream *)stream didChangeValueForKey:(NSString *)key
{
	NSParameterAssert(nil != stream);
	NSParameterAssert(nil != key);

	unsigned index = [_cachedStreams indexOfObject:stream];

	if(NSNotFound != index) {
		[self saveStream:stream];
		[self didChange:NSKeyValueChangeSetting valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:key];
	}
}

@end

@implementation AudioStreamManager (PlaylistMethods)

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
	NSLog(@"Loaded %i streams in %f seconds (%f per second)", [streams count], elapsed, (double)[streams count] / elapsed);
#endif
	
	return [streams autorelease];
}

@end

@implementation AudioStreamManager (SmartPlaylistMethods)

- (NSArray *) streamsForSmartPlaylist:(SmartPlaylist *)playlist
{
	NSParameterAssert(nil != playlist);

	// In Leopard passing nil as a predicate to filteredArrayUsingPredicate: causes a crash
	NSPredicate *playlistPredicate = [playlist valueForKey:SmartPlaylistPredicateKey];
	if(nil != playlistPredicate)
		return [[self streams] filteredArrayUsingPredicate:playlistPredicate];
	else
		return nil;
}

@end

@implementation AudioStreamManager (WatchFolderMethods)

- (NSArray *) streamsForWatchFolder:(WatchFolder *)folder
{
	NSParameterAssert(nil != folder);

	NSMutableArray	*streams		= [[NSMutableArray alloc] init];
	NSURL			*folderURL		= [folder valueForKey:WatchFolderURLKey];
	NSURL			*streamURL		= nil;

	for(AudioStream *stream in [self streams]) {
		streamURL = [stream valueForKey:StreamURLKey];
		if([[streamURL path] hasPrefix:[folderURL path]])
			[streams addObject:stream];
	}

	return [streams autorelease];
}

@end

@implementation AudioStreamManager (Private)

#pragma mark Prepared SQL Statements

- (BOOL) prepareSQL:(NSError **)error
{
	NSString		*path				= nil;
	NSString		*sql				= nil;
	NSArray			*files				= [NSArray arrayWithObjects:
		@"select_all_streams", @"select_stream_by_id", @"select_stream_by_url", @"select_streams_for_playlist", @"insert_stream", @"update_stream", @"delete_stream", nil];
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
	NSParameterAssert(nil != action);
	
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

- (NSArray *) fetchStreams
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
	NSLog(@"Loaded %i streams in %f seconds (%f per second)", [streams count], elapsed, (double)[streams count] / elapsed);
#endif
	
	return [streams autorelease];
}

- (AudioStream *) loadStream:(sqlite3_stmt *)statement
{
	NSParameterAssert(NULL != statement);
	
	AudioStream		*stream			= nil;
	unsigned		objectID;
	
	// The ID should never be NULL
	NSAssert(SQLITE_NULL != sqlite3_column_type(statement, 0), @"No ID found for stream");
	objectID = sqlite3_column_int(statement, 0);
	
	stream = (AudioStream *)NSMapGet(_registeredStreams, (void *)objectID);
	if(nil != stream)
		return stream;
	
	stream = [[AudioStream alloc] init];
	
	// Stream ID and location
	[stream initValue:[NSNumber numberWithUnsignedInt:objectID] forKey:ObjectIDKey];
//	getColumnValue(statement, 0, stream, ObjectIDKey, eObjectTypeUnsignedInt);
	getColumnValue(statement, 1, stream, StreamURLKey, eObjectTypeURL);
	getColumnValue(statement, 2, stream, StreamStartingFrameKey, eObjectTypeLongLong);
	getColumnValue(statement, 3, stream, StreamFrameCountKey, eObjectTypeUnsignedInt);

	// Statistics
	getColumnValue(statement, 4, stream, StatisticsDateAddedKey, eObjectTypeDate);
	getColumnValue(statement, 5, stream, StatisticsFirstPlayedDateKey, eObjectTypeDate);
	getColumnValue(statement, 6, stream, StatisticsLastPlayedDateKey, eObjectTypeDate);
	getColumnValue(statement, 7, stream, StatisticsLastSkippedDateKey, eObjectTypeDate);
	getColumnValue(statement, 8, stream, StatisticsPlayCountKey, eObjectTypeUnsignedInt);
	getColumnValue(statement, 9, stream, StatisticsSkipCountKey, eObjectTypeUnsignedInt);
	getColumnValue(statement, 10, stream, StatisticsRatingKey, eObjectTypeUnsignedInt);

	// Metadata
	getColumnValue(statement, 11, stream, MetadataTitleKey, eObjectTypeString);
	getColumnValue(statement, 12, stream, MetadataAlbumTitleKey, eObjectTypeString);
	getColumnValue(statement, 13, stream, MetadataArtistKey, eObjectTypeString);
	getColumnValue(statement, 14, stream, MetadataAlbumArtistKey, eObjectTypeString);
	getColumnValue(statement, 15, stream, MetadataGenreKey, eObjectTypeString);
	getColumnValue(statement, 16, stream, MetadataComposerKey, eObjectTypeString);
	getColumnValue(statement, 17, stream, MetadataDateKey, eObjectTypeString);	
	getColumnValue(statement, 18, stream, MetadataCompilationKey, eObjectTypeBool);
	getColumnValue(statement, 19, stream, MetadataTrackNumberKey, eObjectTypeInt);
	getColumnValue(statement, 20, stream, MetadataTrackTotalKey, eObjectTypeInt);
	getColumnValue(statement, 21, stream, MetadataDiscNumberKey, eObjectTypeInt);
	getColumnValue(statement, 22, stream, MetadataDiscTotalKey, eObjectTypeInt);
	getColumnValue(statement, 23, stream, MetadataCommentKey, eObjectTypeString);
	getColumnValue(statement, 24, stream, MetadataISRCKey, eObjectTypeString);
	getColumnValue(statement, 25, stream, MetadataMCNKey, eObjectTypeString);
	getColumnValue(statement, 26, stream, MetadataBPMKey, eObjectTypeInt);

	getColumnValue(statement, 27, stream, MetadataMusicDNSPUIDKey, eObjectTypeString);
	getColumnValue(statement, 28, stream, MetadataMusicBrainzIDKey, eObjectTypeString);

	// Replay Gain
	getColumnValue(statement, 29, stream, ReplayGainReferenceLoudnessKey, eObjectTypeDouble);
	getColumnValue(statement, 30, stream, ReplayGainTrackGainKey, eObjectTypeDouble);
	getColumnValue(statement, 31, stream, ReplayGainTrackPeakKey, eObjectTypeDouble);
	getColumnValue(statement, 32, stream, ReplayGainAlbumGainKey, eObjectTypeDouble);
	getColumnValue(statement, 33, stream, ReplayGainAlbumPeakKey, eObjectTypeDouble);

	// Properties
	getColumnValue(statement, 34, stream, PropertiesFileTypeKey, eObjectTypeString);
	getColumnValue(statement, 35, stream, PropertiesDataFormatKey, eObjectTypeString);
	getColumnValue(statement, 36, stream, PropertiesFormatDescriptionKey, eObjectTypeString);
	getColumnValue(statement, 37, stream, PropertiesBitsPerChannelKey, eObjectTypeUnsignedInt);
	getColumnValue(statement, 38, stream, PropertiesChannelsPerFrameKey, eObjectTypeUnsignedInt);
	getColumnValue(statement, 39, stream, PropertiesSampleRateKey, eObjectTypeDouble);
	getColumnValue(statement, 40, stream, PropertiesTotalFramesKey, eObjectTypeLongLong);
	getColumnValue(statement, 41, stream, PropertiesBitrateKey, eObjectTypeDouble);
		
	// Register the object	
	NSMapInsert(_registeredStreams, (void *)objectID, (void *)stream);
	
	return [stream autorelease];
}

#pragma mark Streams

- (BOOL) doInsertStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"insert_stream"];
	int				result			= SQLITE_OK;
	BOOL			success			= YES;
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	@try {
		// Location
		bindParameter(statement, 1, stream, StreamURLKey, eObjectTypeURL);
		bindParameter(statement, 2, stream, StreamStartingFrameKey, eObjectTypeLongLong);
		bindParameter(statement, 3, stream, StreamFrameCountKey, eObjectTypeUnsignedInt);
		
		// Statistics
		bindParameter(statement, 4, stream, StatisticsDateAddedKey, eObjectTypeDate);
		bindParameter(statement, 5, stream, StatisticsFirstPlayedDateKey, eObjectTypeDate);
		bindParameter(statement, 6, stream, StatisticsLastPlayedDateKey, eObjectTypeDate);
		bindParameter(statement, 7, stream, StatisticsLastSkippedDateKey, eObjectTypeDate);
		bindParameter(statement, 8, stream, StatisticsPlayCountKey, eObjectTypeUnsignedInt);
		bindParameter(statement, 9, stream, StatisticsSkipCountKey, eObjectTypeUnsignedInt);
		bindParameter(statement, 10, stream, StatisticsRatingKey, eObjectTypeUnsignedInt);
		
		// Metadata
		bindParameter(statement, 11, stream, MetadataTitleKey, eObjectTypeString);
		bindParameter(statement, 12, stream, MetadataAlbumTitleKey, eObjectTypeString);
		bindParameter(statement, 13, stream, MetadataArtistKey, eObjectTypeString);
		bindParameter(statement, 14, stream, MetadataAlbumArtistKey, eObjectTypeString);
		bindParameter(statement, 15, stream, MetadataGenreKey, eObjectTypeString);
		bindParameter(statement, 16, stream, MetadataComposerKey, eObjectTypeString);
		bindParameter(statement, 17, stream, MetadataDateKey, eObjectTypeString);	
		bindParameter(statement, 18, stream, MetadataCompilationKey, eObjectTypeBool);
		bindParameter(statement, 19, stream, MetadataTrackNumberKey, eObjectTypeInt);
		bindParameter(statement, 20, stream, MetadataTrackTotalKey, eObjectTypeInt);
		bindParameter(statement, 21, stream, MetadataDiscNumberKey, eObjectTypeInt);
		bindParameter(statement, 22, stream, MetadataDiscTotalKey, eObjectTypeInt);
		bindParameter(statement, 23, stream, MetadataCommentKey, eObjectTypeString);
		bindParameter(statement, 24, stream, MetadataISRCKey, eObjectTypeString);
		bindParameter(statement, 25, stream, MetadataMCNKey, eObjectTypeString);
		bindParameter(statement, 26, stream, MetadataBPMKey, eObjectTypeInt);

		bindParameter(statement, 27, stream, MetadataMusicDNSPUIDKey, eObjectTypeString);
		bindParameter(statement, 28, stream, MetadataMusicBrainzIDKey, eObjectTypeString);

		// Replay Gain
		bindParameter(statement, 29, stream, ReplayGainReferenceLoudnessKey, eObjectTypeDouble);
		bindParameter(statement, 30, stream, ReplayGainTrackGainKey, eObjectTypeDouble);
		bindParameter(statement, 31, stream, ReplayGainTrackPeakKey, eObjectTypeDouble);
		bindParameter(statement, 32, stream, ReplayGainAlbumGainKey, eObjectTypeDouble);
		bindParameter(statement, 33, stream, ReplayGainAlbumPeakKey, eObjectTypeDouble);

		// Properties
		bindParameter(statement, 34, stream, PropertiesFileTypeKey, eObjectTypeString);
		bindParameter(statement, 35, stream, PropertiesDataFormatKey, eObjectTypeString);
		bindParameter(statement, 36, stream, PropertiesFormatDescriptionKey, eObjectTypeString);
		bindParameter(statement, 37, stream, PropertiesBitsPerChannelKey, eObjectTypeUnsignedInt);
		bindParameter(statement, 38, stream, PropertiesChannelsPerFrameKey, eObjectTypeUnsignedInt);
		bindParameter(statement, 39, stream, PropertiesSampleRateKey, eObjectTypeDouble);
		bindParameter(statement, 40, stream, PropertiesTotalFramesKey, eObjectTypeLongLong);
		bindParameter(statement, 41, stream, PropertiesBitrateKey, eObjectTypeDouble);
		
		result = sqlite3_step(statement);
		NSAssert2(SQLITE_DONE == result, @"Unable to insert a record for %@ (%@).", [[NSFileManager defaultManager] displayNameAtPath:[[stream valueForKey:StreamURLKey] path]], [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		[stream initValue:[NSNumber numberWithInt:sqlite3_last_insert_rowid(_db)] forKey:ObjectIDKey];
		
		result = sqlite3_reset(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_clear_bindings(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);

		// Register the object	
		NSMapInsert(_registeredStreams, (void *)[[stream valueForKey:ObjectIDKey] unsignedIntValue], (void *)stream);
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
	NSLog(@"Stream insertion time = %f seconds", elapsed);
#endif
	
	return success;
}

- (void) doUpdateStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	NSParameterAssert(nil != [stream valueForKey:ObjectIDKey]);
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"update_stream"];
	int				result			= SQLITE_OK;
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	// ID and Location
	bindNamedParameter(statement, ":id", stream, ObjectIDKey, eObjectTypeUnsignedInt);
	bindNamedParameter(statement, ":url", stream, StreamURLKey, eObjectTypeURL);
	bindNamedParameter(statement, ":starting_frame", stream, StreamStartingFrameKey, eObjectTypeLongLong);
	bindNamedParameter(statement, ":frame_count", stream, StreamFrameCountKey, eObjectTypeUnsignedInt);
	
	// Statistics
	bindNamedParameter(statement, ":date_added", stream, StatisticsDateAddedKey, eObjectTypeDate);
	bindNamedParameter(statement, ":first_played_date", stream, StatisticsFirstPlayedDateKey, eObjectTypeDate);
	bindNamedParameter(statement, ":last_played_date", stream, StatisticsLastPlayedDateKey, eObjectTypeDate);
	bindNamedParameter(statement, ":last_skipped_date", stream, StatisticsLastSkippedDateKey, eObjectTypeDate);
	bindNamedParameter(statement, ":play_count", stream, StatisticsPlayCountKey, eObjectTypeUnsignedInt);
	bindNamedParameter(statement, ":skip_count", stream, StatisticsSkipCountKey, eObjectTypeUnsignedInt);
	bindNamedParameter(statement, ":rating", stream, StatisticsRatingKey, eObjectTypeUnsignedInt);
	
	// Metadata
	bindNamedParameter(statement, ":title", stream, MetadataTitleKey, eObjectTypeString);
	bindNamedParameter(statement, ":album_title", stream, MetadataAlbumTitleKey, eObjectTypeString);
	bindNamedParameter(statement, ":artist", stream, MetadataArtistKey, eObjectTypeString);
	bindNamedParameter(statement, ":album_artist", stream, MetadataAlbumArtistKey, eObjectTypeString);
	bindNamedParameter(statement, ":genre", stream, MetadataGenreKey, eObjectTypeString);
	bindNamedParameter(statement, ":composer", stream, MetadataComposerKey, eObjectTypeString);
	bindNamedParameter(statement, ":date", stream, MetadataDateKey, eObjectTypeString);	
	bindNamedParameter(statement, ":compilation", stream, MetadataCompilationKey, eObjectTypeBool);
	bindNamedParameter(statement, ":track_number", stream, MetadataTrackNumberKey, eObjectTypeInt);
	bindNamedParameter(statement, ":track_total", stream, MetadataTrackTotalKey, eObjectTypeInt);
	bindNamedParameter(statement, ":disc_number", stream, MetadataDiscNumberKey, eObjectTypeInt);
	bindNamedParameter(statement, ":disc_total", stream, MetadataDiscTotalKey, eObjectTypeInt);
	bindNamedParameter(statement, ":comment", stream, MetadataCommentKey, eObjectTypeString);
	bindNamedParameter(statement, ":isrc", stream, MetadataISRCKey, eObjectTypeString);
	bindNamedParameter(statement, ":mcn", stream, MetadataMCNKey, eObjectTypeString);
	bindNamedParameter(statement, ":bpm", stream, MetadataBPMKey, eObjectTypeInt);

	bindNamedParameter(statement, ":musicdns_puid", stream, MetadataMusicDNSPUIDKey, eObjectTypeString);
	bindNamedParameter(statement, ":musicbrainz_id", stream, MetadataMusicBrainzIDKey, eObjectTypeString);

	// Replay gain
	bindNamedParameter(statement, ":reference_loudness", stream, ReplayGainReferenceLoudnessKey, eObjectTypeDouble);
	bindNamedParameter(statement, ":track_replay_gain", stream, ReplayGainTrackGainKey, eObjectTypeDouble);
	bindNamedParameter(statement, ":track_peak", stream, ReplayGainTrackPeakKey, eObjectTypeDouble);
	bindNamedParameter(statement, ":album_replay_gain", stream, ReplayGainAlbumGainKey, eObjectTypeDouble);
	bindNamedParameter(statement, ":album_peak", stream, ReplayGainAlbumPeakKey, eObjectTypeDouble);
	
	// Properties
	bindNamedParameter(statement, ":file_type", stream, PropertiesFileTypeKey, eObjectTypeString);
	bindNamedParameter(statement, ":data_format", stream, PropertiesDataFormatKey, eObjectTypeString);
	bindNamedParameter(statement, ":format_description", stream, PropertiesFormatDescriptionKey, eObjectTypeString);
	bindNamedParameter(statement, ":bits_per_channel", stream, PropertiesBitsPerChannelKey, eObjectTypeUnsignedInt);
	bindNamedParameter(statement, ":channels_per_frame", stream, PropertiesChannelsPerFrameKey, eObjectTypeUnsignedInt);
	bindNamedParameter(statement, ":sample_rate", stream, PropertiesSampleRateKey, eObjectTypeDouble);
	bindNamedParameter(statement, ":total_frames", stream, PropertiesTotalFramesKey, eObjectTypeLongLong);
	bindNamedParameter(statement, ":bitrate", stream, PropertiesBitrateKey, eObjectTypeDouble);
	
	result = sqlite3_step(statement);
	NSAssert2(SQLITE_DONE == result, @"Unable to update the record for %@ (%@).", stream, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
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
	[stream synchronizeSavedValuesWithChangedValues];
}

- (void) doDeleteStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	NSParameterAssert(nil != [stream valueForKey:ObjectIDKey]);
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"delete_stream"];
	int				result			= SQLITE_OK;
	unsigned		objectID		= [[stream valueForKey:ObjectIDKey] unsignedIntValue];
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	result = sqlite3_bind_int(statement, sqlite3_bind_parameter_index(statement, ":id"), objectID);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert2(SQLITE_DONE == result, @"Unable to delete the record for %@ (%@).", stream, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
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
	NSMapRemove(_registeredStreams, (void *)objectID);
}

- (NSArray *) streamKeys
{
	@synchronized(self) {
		if(nil == _streamKeys) {
			_streamKeys	= [[NSArray alloc] initWithObjects:
				ObjectIDKey, 
				StreamURLKey,
				StreamStartingFrameKey,
				StreamFrameCountKey,
				
				StatisticsDateAddedKey,
				StatisticsFirstPlayedDateKey,
				StatisticsLastPlayedDateKey,
				StatisticsLastSkippedDateKey,
				StatisticsPlayCountKey,
				StatisticsSkipCountKey,
				StatisticsRatingKey,
				
				MetadataTitleKey,
				MetadataAlbumTitleKey,
				MetadataArtistKey,
				MetadataAlbumArtistKey,
				MetadataGenreKey,
				MetadataComposerKey,
				MetadataDateKey,
				MetadataCompilationKey,
				MetadataTrackNumberKey,
				MetadataTrackTotalKey,
				MetadataDiscNumberKey,
				MetadataDiscTotalKey,
				MetadataCommentKey,
				MetadataISRCKey,
				MetadataMCNKey,
				MetadataBPMKey,

				MetadataMusicDNSPUIDKey,
				MetadataMusicBrainzIDKey,

				ReplayGainReferenceLoudnessKey,
				ReplayGainTrackGainKey,
				ReplayGainTrackPeakKey,
				ReplayGainAlbumGainKey,
				ReplayGainAlbumPeakKey,

				PropertiesFileTypeKey,
				PropertiesDataFormatKey,
				PropertiesFormatDescriptionKey,
				PropertiesBitsPerChannelKey,
				PropertiesChannelsPerFrameKey,
				PropertiesSampleRateKey,
				PropertiesTotalFramesKey,
				PropertiesBitrateKey,
								
				nil];			
		}
	}
	return _streamKeys;
}

@end
