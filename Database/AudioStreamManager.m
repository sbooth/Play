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
#import "AudioLibrary.h"

#import "SQLiteUtilityFunctions.h"

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

@interface AudioStreamManager (PlaylistManagerMethods)
- (NSArray *) streamsForPlaylist:(Playlist *)playlist;
@end

@interface AudioStreamManager (Private)
- (void) 			prepareSQL;
- (void) 			finalizeSQL;
- (sqlite3_stmt *) 	preparedStatementForAction:(NSString *)action;

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
		_registeredStreams	= NSCreateMapTable(NSIntMapKeyCallBacks, NSObjectMapValueCallBacks, 4096);		
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
		if(nil == _cachedStreams) {
			_cachedStreams = [[self fetchStreams] retain];
		}
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

- (AudioStream *) streamForID:(NSNumber *)objectID
{
	NSParameterAssert(nil != objectID);
	
	AudioStream *stream = (AudioStream *)NSMapGet(_registeredStreams, (void *)[objectID unsignedIntValue]);
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

- (AudioStream *) streamForURL:(NSURL *)url
{
	NSParameterAssert(nil != url);
	
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

// ========================================
// Insert
- (BOOL) insertStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);

	BOOL result;
	
	if([self updateInProgress]) {
		[_insertedStreams addObject:stream];
	}
	else {
		NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:0];

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
	
	if(NO == [stream hasChanges]) {
		return;
	}
	
	if([self updateInProgress]) {
		[_updatedStreams addObject:stream];
	}
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

	if([self updateInProgress]) {
		[_deletedStreams addObject:stream];
	}
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

	if(NO == [self updateInProgress]) {
		[self willChange:NSKeyValueChangeSetting valuesAtIndexes:indexes forKey:@"streams"];
	}

	[stream revert];
	
	if(NO == [self updateInProgress]) {
		[self didChange:NSKeyValueChangeSetting valuesAtIndexes:indexes forKey:@"streams"];
	}
}

#pragma mark Metadata support

- (id) valueForKey:(NSString *)key
{
	if([[self streamKeys] containsObject:key]) {
		NSString *keyName = [NSString stringWithFormat:@"@distinctUnionOfObjects.%@", key];
		return [[[self streams] valueForKeyPath:keyName] sortedArrayUsingSelector:@selector(compare:)];
	}
	else {
		return [super valueForKey:key];
	}
}

@end

@implementation AudioStreamManager (CollectionManagerMethods)

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
	[self willChangeValueForKey:@"streams"];
	NSResetMapTable(_registeredStreams);
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
	
	NSEnumerator 		*enumerator 	= nil;
	AudioStream 		*stream 		= nil;
	
	// ========================================
	// Process updates first
	if(0 != [_updatedStreams count]) {
		enumerator = [_updatedStreams objectEnumerator];
		while((stream = [enumerator nextObject])) {
			[self doUpdateStream:stream];
		}
	}
	
	// ========================================
	// Processes deletes next
	if(0 != [_deletedStreams count]) {
		enumerator = [_deletedStreams objectEnumerator];
		while((stream = [enumerator nextObject])) {
			[self doDeleteStream:stream];
		}
	}
	
	// ========================================
	// Finally, process inserts, removing any that fail
	if(0 != [_insertedStreams count]) {
		enumerator = [[_insertedStreams allObjects] objectEnumerator];
		while((stream = [enumerator nextObject])) {
			if(NO == [self doInsertStream:stream]) {
				[_insertedStreams removeObject:stream];
			}
		}
	}	
}

- (void) finishUpdate
{
	NSAssert(YES == _updating, @"No update in progress");

	NSEnumerator 		*enumerator 	= nil;
	AudioStream 		*stream 		= nil;
	NSMutableIndexSet 	*indexes 		= [[NSMutableIndexSet alloc] init];
	
	// ========================================
	// Broadcast the notifications
	if(0 != [_updatedStreams count]) {
		enumerator = [_updatedStreams objectEnumerator];
		while((stream = [enumerator nextObject])) {
			[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamDidChangeNotification 
																object:self 
															  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];		
		}		
	
		[_updatedStreams removeAllObjects];
	}

	// ========================================
	// Handle deletes
	if(0 != [_deletedStreams count]) {
		enumerator = [_deletedStreams objectEnumerator];
		while((stream = [enumerator nextObject])) {
			[indexes addIndex:[_cachedStreams indexOfObject:stream]];
		}

		[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"streams"];
		enumerator = [_deletedStreams objectEnumerator];
		while((stream = [enumerator nextObject])) {
			[_cachedStreams removeObject:stream];

			[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamRemovedFromLibraryNotification 
																object:self
															  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
		}
		[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"streams"];		
		
		[_deletedStreams removeAllObjects];
		[indexes removeAllIndexes];
	}

	// ========================================
	// And finally inserts
	if(0 != [_insertedStreams count]) {
		[indexes addIndexesInRange:NSMakeRange(0, [_insertedStreams count])];

		[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"streams"];
		enumerator = [[_insertedStreams allObjects] objectEnumerator];
		while((stream = [enumerator nextObject])) {
			[_cachedStreams addObject:stream];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamAddedToLibraryNotification 
																object:self 
															  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
		}
		[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"streams"];
		
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
		NSEnumerator	*enumerator 	= nil;
		AudioStream 	*stream 		= nil;
		
		enumerator = [_updatedStreams objectEnumerator];
		while((stream = [enumerator nextObject])) {
			[stream revert];
		}
	}

	[_insertedStreams removeAllObjects];
	[_updatedStreams removeAllObjects];
	[_deletedStreams removeAllObjects];
	
	_updating = NO;
}

- (void) stream:(AudioStream *)stream willChangeValueForKey:(NSString *)key
{
	id			value	= [stream valueForKey:key];
	unsigned	index	= [[self valueForKey:key] indexOfObject:value];
	
	if(NSNotFound == index) {
		[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:0] forKey:key];
	}
	else {
		[self willChange:NSKeyValueChangeSetting valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:key];
	}
}

- (void) stream:(AudioStream *)stream didChangeValueForKey:(NSString *)key
{
	id			value	= [stream valueForKey:key];
	unsigned	index	= [[self valueForKey:key] indexOfObject:value];
	
	[self saveStream:stream];
	
	if(NSNotFound == index) {
		[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:0] forKey:key];
	}
	else {
		[self didChange:NSKeyValueChangeSetting valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:key];
	}
}

@end

@implementation AudioStreamManager (PlaylistManagerMethods)

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

@end

@implementation AudioStreamManager (Private)

#pragma mark Prepared SQL Statements

- (void) prepareSQL
{
	NSError			*error				= nil;	
	NSString		*path				= nil;
	NSString		*sql				= nil;
	NSString		*filename			= nil;
	NSArray			*files				= [NSArray arrayWithObjects:
		@"select_all_streams", @"select_stream_by_id", @"select_stream_by_url", @"select_streams_for_playlist", @"insert_stream", @"update_stream", @"delete_stream", nil];
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
	NSLog(@"Loaded %i streams in %f seconds (%i per second)", [streams count], elapsed, (double)[streams count] / elapsed);
#endif
	
	return [streams autorelease];
}

- (AudioStream *) loadStream:(sqlite3_stmt *)statement
{
	AudioStream		*stream			= nil;
	unsigned		objectID;
	
	// The ID should never be NULL
	NSAssert(SQLITE_NULL != sqlite3_column_type(statement, 0), @"No ID found for stream");
	objectID = sqlite3_column_int(statement, 0);
	
	stream = (AudioStream *)NSMapGet(_registeredStreams, (void *)objectID);
	if(nil != stream) {
		return stream;
	}
	
	stream = [[AudioStream alloc] init];
	
	// Stream ID and location
	[stream initValue:[NSNumber numberWithUnsignedInt:objectID] forKey:ObjectIDKey];
//	getColumnValue(statement, 0, stream, ObjectIDKey, eObjectTypeUnsignedInteger);
	getColumnValue(statement, 1, stream, StreamURLKey, eObjectTypeURL);

	// Statistics
	getColumnValue(statement, 2, stream, StatisticsDateAddedKey, eObjectTypeDate);
	getColumnValue(statement, 3, stream, StatisticsFirstPlayedDateKey, eObjectTypeDate);
	getColumnValue(statement, 4, stream, StatisticsLastPlayedDateKey, eObjectTypeDate);
	getColumnValue(statement, 5, stream, StatisticsPlayCountKey, eObjectTypeUnsignedInteger);

	// Metadata
	getColumnValue(statement, 6, stream, MetadataTitleKey, eObjectTypeString);
	getColumnValue(statement, 7, stream, MetadataAlbumTitleKey, eObjectTypeString);
	getColumnValue(statement, 8, stream, MetadataArtistKey, eObjectTypeString);
	getColumnValue(statement, 9, stream, MetadataAlbumArtistKey, eObjectTypeString);
	getColumnValue(statement, 10, stream, MetadataGenreKey, eObjectTypeString);
	getColumnValue(statement, 11, stream, MetadataComposerKey, eObjectTypeString);
	getColumnValue(statement, 12, stream, MetadataDateKey, eObjectTypeString);	
	getColumnValue(statement, 13, stream, MetadataCompilationKey, eObjectTypeInteger);
	getColumnValue(statement, 14, stream, MetadataTrackNumberKey, eObjectTypeInteger);
	getColumnValue(statement, 15, stream, MetadataTrackTotalKey, eObjectTypeInteger);
	getColumnValue(statement, 16, stream, MetadataDiscNumberKey, eObjectTypeInteger);
	getColumnValue(statement, 17, stream, MetadataDiscTotalKey, eObjectTypeInteger);
	getColumnValue(statement, 18, stream, MetadataCommentKey, eObjectTypeString);
	getColumnValue(statement, 19, stream, MetadataISRCKey, eObjectTypeString);
	getColumnValue(statement, 20, stream, MetadataMCNKey, eObjectTypeString);
	
	// Properties
	getColumnValue(statement, 21, stream, PropertiesFileTypeKey, eObjectTypeString);
	getColumnValue(statement, 22, stream, PropertiesFormatTypeKey, eObjectTypeString);
	getColumnValue(statement, 23, stream, PropertiesBitsPerChannelKey, eObjectTypeUnsignedInteger);
	getColumnValue(statement, 24, stream, PropertiesChannelsPerFrameKey, eObjectTypeUnsignedInteger);
	getColumnValue(statement, 25, stream, PropertiesSampleRateKey, eObjectTypeDouble);
	getColumnValue(statement, 26, stream, PropertiesTotalFramesKey, eObjectTypeLongLong);
	getColumnValue(statement, 27, stream, PropertiesDurationKey, eObjectTypeDouble);
	getColumnValue(statement, 28, stream, PropertiesBitrateKey, eObjectTypeDouble);
	
	// Register the object	
	NSMapInsert(_registeredStreams, (void *)objectID, (void *)stream);
	
	return [stream autorelease];
}

#pragma mark Streams

- (BOOL) doInsertStream:(AudioStream *)stream
{
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"insert_stream"];
	int				result			= SQLITE_OK;
	BOOL			success			= YES;
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
/*#if SQL_DEBUG
	clock_t start = clock();
#endif*/
	
	@try {
		// Location
		bindParameter(statement, 1, stream, StreamURLKey, eObjectTypeURL);
		
		// Statistics
		bindParameter(statement, 2, stream, StatisticsDateAddedKey, eObjectTypeDate);
		bindParameter(statement, 3, stream, StatisticsFirstPlayedDateKey, eObjectTypeDate);
		bindParameter(statement, 4, stream, StatisticsLastPlayedDateKey, eObjectTypeDate);
		bindParameter(statement, 5, stream, StatisticsPlayCountKey, eObjectTypeUnsignedInteger);
		
		// Metadata
		bindParameter(statement, 6, stream, MetadataTitleKey, eObjectTypeString);
		bindParameter(statement, 7, stream, MetadataAlbumTitleKey, eObjectTypeString);
		bindParameter(statement, 8, stream, MetadataArtistKey, eObjectTypeString);
		bindParameter(statement, 9, stream, MetadataAlbumArtistKey, eObjectTypeString);
		bindParameter(statement, 10, stream, MetadataGenreKey, eObjectTypeString);
		bindParameter(statement, 11, stream, MetadataComposerKey, eObjectTypeString);
		bindParameter(statement, 12, stream, MetadataDateKey, eObjectTypeString);	
		bindParameter(statement, 13, stream, MetadataCompilationKey, eObjectTypeInteger);
		bindParameter(statement, 14, stream, MetadataTrackNumberKey, eObjectTypeInteger);
		bindParameter(statement, 15, stream, MetadataTrackTotalKey, eObjectTypeInteger);
		bindParameter(statement, 16, stream, MetadataDiscNumberKey, eObjectTypeInteger);
		bindParameter(statement, 17, stream, MetadataDiscTotalKey, eObjectTypeInteger);
		bindParameter(statement, 18, stream, MetadataCommentKey, eObjectTypeString);
		bindParameter(statement, 19, stream, MetadataISRCKey, eObjectTypeString);
		bindParameter(statement, 20, stream, MetadataMCNKey, eObjectTypeString);
		
		// Properties
		bindParameter(statement, 21, stream, PropertiesFileTypeKey, eObjectTypeString);
		bindParameter(statement, 22, stream, PropertiesFormatTypeKey, eObjectTypeString);
		bindParameter(statement, 23, stream, PropertiesBitsPerChannelKey, eObjectTypeUnsignedInteger);
		bindParameter(statement, 24, stream, PropertiesChannelsPerFrameKey, eObjectTypeUnsignedInteger);
		bindParameter(statement, 25, stream, PropertiesSampleRateKey, eObjectTypeDouble);
		bindParameter(statement, 26, stream, PropertiesTotalFramesKey, eObjectTypeLongLong);
		bindParameter(statement, 27, stream, PropertiesDurationKey, eObjectTypeDouble);
		bindParameter(statement, 28, stream, PropertiesBitrateKey, eObjectTypeDouble);
				
		result = sqlite3_step(statement);
		NSAssert2(SQLITE_DONE == result, @"Unable to insert a record for %@ (%@).", [[NSFileManager defaultManager] displayNameAtPath:[[stream valueForKey:StreamURLKey] path]], [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		[stream initValue:[NSNumber numberWithInt:sqlite3_last_insert_rowid(_db)] forKey:ObjectIDKey];
		
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

- (void) doUpdateStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	//	NSParameterAssert(nil != [stream valueForKey:ObjectIDKey]);
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"update_stream"];
	int				result			= SQLITE_OK;
	NSDictionary	*changes		= [stream changedValues];
	
	NSAssert([self isConnectedToDatabase], NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	NSAssert(NULL != statement, NSLocalizedStringFromTable(@"Unable to locate SQL.", @"Database", @""));
	
/*#if SQL_DEBUG
	clock_t start = clock();
#endif*/
	
	// ID and Location
	bindNamedParameter(statement, ":id", stream, ObjectIDKey, eObjectTypeUnsignedInteger);
	bindNamedParameter(statement, ":url", stream, StreamURLKey, eObjectTypeURL);
	
	// Statistics
	bindNamedParameter(statement, ":date_added", stream, StatisticsDateAddedKey, eObjectTypeDate);
	bindNamedParameter(statement, ":first_played_date", stream, StatisticsFirstPlayedDateKey, eObjectTypeDate);
	bindNamedParameter(statement, ":last_played_date", stream, StatisticsLastPlayedDateKey, eObjectTypeDate);
	bindNamedParameter(statement, ":play_count", stream, StatisticsPlayCountKey, eObjectTypeInteger);
	
	// Metadata
	bindNamedParameter(statement, ":title", stream, MetadataTitleKey, eObjectTypeString);
	bindNamedParameter(statement, ":album_title", stream, MetadataAlbumTitleKey, eObjectTypeString);
	bindNamedParameter(statement, ":artist", stream, MetadataArtistKey, eObjectTypeString);
	bindNamedParameter(statement, ":album_artist", stream, MetadataAlbumArtistKey, eObjectTypeString);
	bindNamedParameter(statement, ":genre", stream, MetadataGenreKey, eObjectTypeString);
	bindNamedParameter(statement, ":composer", stream, MetadataComposerKey, eObjectTypeString);
	bindNamedParameter(statement, ":date", stream, MetadataDateKey, eObjectTypeString);	
	bindNamedParameter(statement, ":compilation", stream, MetadataCompilationKey, eObjectTypeInteger);
	bindNamedParameter(statement, ":track_number", stream, MetadataTrackNumberKey, eObjectTypeInteger);
	bindNamedParameter(statement, ":track_total", stream, MetadataTrackTotalKey, eObjectTypeInteger);
	bindNamedParameter(statement, ":disc_number", stream, MetadataDiscNumberKey, eObjectTypeInteger);
	bindNamedParameter(statement, ":disc_total", stream, MetadataDiscTotalKey, eObjectTypeInteger);
	bindNamedParameter(statement, ":comment", stream, MetadataCommentKey, eObjectTypeString);
	bindNamedParameter(statement, ":isrc", stream, MetadataISRCKey, eObjectTypeString);
	bindNamedParameter(statement, ":mcn", stream, MetadataMCNKey, eObjectTypeString);
	
	// Properties
	bindNamedParameter(statement, ":file_type", stream, PropertiesFileTypeKey, eObjectTypeString);
	bindNamedParameter(statement, ":format_type", stream, PropertiesFormatTypeKey, eObjectTypeString);
	bindNamedParameter(statement, ":bits_per_channel", stream, PropertiesBitsPerChannelKey, eObjectTypeUnsignedInteger);
	bindNamedParameter(statement, ":channels_per_frame", stream, PropertiesChannelsPerFrameKey, eObjectTypeUnsignedInteger);
	bindNamedParameter(statement, ":sample_rate", stream, PropertiesSampleRateKey, eObjectTypeDouble);
	bindNamedParameter(statement, ":total_frames", stream, PropertiesTotalFramesKey, eObjectTypeLongLong);
	bindNamedParameter(statement, ":duration", stream, PropertiesDurationKey, eObjectTypeDouble);
	bindNamedParameter(statement, ":bitrate", stream, PropertiesBitrateKey, eObjectTypeDouble);
	
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
	NSMapRemove(_registeredStreams, (void *)objectID);
}

- (NSArray *) streamKeys
{
	@synchronized(self) {
		if(nil == _streamKeys) {
			_streamKeys	= [[NSArray alloc] initWithObjects:
				ObjectIDKey, 
				StreamURLKey,
				
				StatisticsDateAddedKey,
				StatisticsFirstPlayedDateKey,
				StatisticsLastPlayedDateKey,
				StatisticsPlayCountKey,
				
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
				
				PropertiesFileTypeKey,
				PropertiesFormatTypeKey,
				PropertiesBitsPerChannelKey,
				PropertiesChannelsPerFrameKey,
				PropertiesSampleRateKey,
				PropertiesTotalFramesKey,
				PropertiesDurationKey,
				PropertiesBitrateKey,
				
				nil];			
		}
	}
	return _streamKeys;
}

@end
