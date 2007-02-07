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

#import "AudioLibrary+DatabaseMethods.h"

@implementation AudioLibrary (DatabaseMethods)

- (void) prepareSQL
{
	NSError			*error				= nil;	
	NSString		*path				= nil;
	NSString		*sql				= nil;
	NSString		*filename			= nil;
	NSArray			*files				= [NSArray arrayWithObjects:@"begin_transaction", @"commit_transaction", @"rollback_transaction", 
		@"select_all_streams", @"insert_stream", @"update_stream", @"delete_stream", 
		@"select_all_playlists", @"insert_playlist", @"update_playlist", @"delete_playlist", nil];
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

- (void) connectToDatabase:(NSString *)databasePath
{
	NSParameterAssert(nil != databasePath);
	
	int result = sqlite3_open([databasePath UTF8String], &_db);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to open the sqlite database (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);	
}

- (void) disconnectFromDatabase
{
	NSAssert(NULL != _db, NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	int result = sqlite3_close(_db);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to close the sqlite database (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);	
	_db = NULL;
}

- (void) beginTransaction
{
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"begin_transaction"];
	int				result			= SQLITE_OK;
	
	NSAssert(NULL != _db, NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to begin an SQL transaction (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}

- (void) commitTransaction
{
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"commit_transaction"];
	int				result			= SQLITE_OK;
	
	NSAssert(NULL != _db, NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to commit the SQL transaction (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}

- (void) rollbackTransaction
{
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"rollback_transaction"];
	int				result			= SQLITE_OK;
	
	NSAssert(NULL != _db, NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to rollback the SQL transaction (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}

#pragma mark Table Creation

- (void) createStreamTable
{
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

- (void) createEntryTableForPlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	NSParameterAssert(nil != [playlist valueForKey:@"id"]);

	switch([playlist type]) {
		case ePlaylistTypeStaticPlaylist:	[self createEntryTableForStaticPlaylist:playlist];	break;
		case ePlaylistTypeFolderPlaylist:	[self createEntryTableForFolderPlaylist:playlist];	break;
		case ePlaylistTypeDynamicPlaylist:	[self createEntryTableForDynamicPlaylist:playlist];	break;
	}
}

- (void) createEntryTableForStaticPlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	NSParameterAssert(nil != [playlist valueForKey:@"id"]);
	NSParameterAssert(ePlaylistTypeStaticPlaylist == [playlist type]);
	
	sqlite3_stmt	*statement		= NULL;
	int				result			= SQLITE_OK;
	const char		*tail			= NULL;
	NSError			*error			= nil;
	NSString		*path			= [[NSBundle mainBundle] pathForResource:@"create_static_playlist_entry_table" ofType:@"sql"];
	NSString		*sqlTemplate	= [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	NSString		*tableName		= [playlist tableName];
	NSString		*sql			= [NSString stringWithFormat:sqlTemplate, tableName, tableName, tableName];
	
	NSAssert1(nil != sql, NSLocalizedStringFromTable(@"Unable to locate sql file \"%@\".", @"Database", @""), @"create_static_playlist_entry_table");
	
	result = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to prepare sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to create the playlist entry table (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}

- (void) createEntryTableForFolderPlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	NSParameterAssert(nil != [playlist valueForKey:@"id"]);
	NSParameterAssert(ePlaylistTypeFolderPlaylist == [playlist type]);
	
	sqlite3_stmt	*statement		= NULL;
	int				result			= SQLITE_OK;
	const char		*tail			= NULL;
	NSError			*error			= nil;
	NSString		*path			= [[NSBundle mainBundle] pathForResource:@"create_folder_playlist_entry_table" ofType:@"sql"];
	NSString		*sqlTemplate	= [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	NSString		*sql			= [NSString stringWithFormat:sqlTemplate, [playlist tableName]];
	
	NSAssert1(nil != sql, NSLocalizedStringFromTable(@"Unable to locate sql file \"%@\".", @"Database", @""), @"create_folder_playlist_entry_table");
	
	result = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to prepare sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to create the playlist entry table (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}

- (void) createEntryTableForDynamicPlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	NSParameterAssert(nil != [playlist valueForKey:@"id"]);
	NSParameterAssert(ePlaylistTypeDynamicPlaylist == [playlist type]);
	
	sqlite3_stmt	*statement		= NULL;
	int				result			= SQLITE_OK;
	const char		*tail			= NULL;
	NSError			*error			= nil;
	NSString		*path			= [[NSBundle mainBundle] pathForResource:@"create_dynamic_playlist_entry_table" ofType:@"sql"];
	NSString		*sqlTemplate	= [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	NSString		*sql			= [NSString stringWithFormat:sqlTemplate, [playlist tableName]];
	
	NSAssert1(nil != sql, NSLocalizedStringFromTable(@"Unable to locate sql file \"%@\".", @"Database", @""), @"create_dynamic_playlist_entry_table");
	
	result = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to prepare sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to create the playlist entry table (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}

- (void) dropEntryTableForPlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	NSParameterAssert(nil != [playlist valueForKey:@"id"]);

	sqlite3_stmt	*statement		= NULL;
	int				result			= SQLITE_OK;
	const char		*tail			= NULL;
	NSError			*error			= nil;
	NSString		*path			= [[NSBundle mainBundle] pathForResource:@"drop_playlist_entry_table" ofType:@"sql"];
	NSString		*sqlTemplate	= [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	NSString		*sql			= [NSString stringWithFormat:sqlTemplate, [playlist tableName]];
	
	NSAssert1(nil != sql, NSLocalizedStringFromTable(@"Unable to locate sql file \"%@\".", @"Database", @""), @"create_static_playlist_entry_table");
	
	result = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to prepare sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to drop the playlist entry table (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}

#pragma mark Data Retrieval

- (void) fetchData
{
#if SQL_DEBUG_EXTREME
	clock_t start = clock();
	unsigned i;
	for(i = 0; i < 10; ++i) {
#endif
	
	[self fetchStreams];
	[self fetchPlaylists];
	
#if SQL_DEBUG_EXTREME
	}
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Total load time was %f seconds (average %f seconds)", elapsed, elapsed / i);
#endif
}

- (void) fetchStreams
{
	// Fetch all the stream objects in the database
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"select_all_streams"];
	int				result			= SQLITE_OK;
	const char		*rawText		= NULL;
	NSString		*text			= nil;
	AudioStream		*value			= nil;
				
	NSAssert(NULL != _db, NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	[self willChangeValueForKey:@"streams"];
	
	// TODO: For performance, cache the array and update it with any changes when the view is switched
	
	// "Forget" the current streams
	[_streams removeAllObjects];
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	while(SQLITE_ROW == (result = sqlite3_step(statement))) {
		value = [[AudioStream alloc] init];
		
		// Stream ID and location
		if(SQLITE_NULL != sqlite3_column_type(statement, 0)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 0)] forKey:@"id"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 1))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:[NSURL URLWithString:text] forKey:@"url"];
		}
		
		// Statistics
		if(SQLITE_NULL != sqlite3_column_type(statement, 2)) {
			[value initValue:[NSDate dateWithTimeIntervalSinceReferenceDate:sqlite3_column_double(statement, 2)] forKey:@"dateAdded"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 3)) {
			[value initValue:[NSDate dateWithTimeIntervalSinceReferenceDate:sqlite3_column_double(statement, 3)] forKey:@"firstPlayed"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 4)) {
			[value initValue:[NSDate dateWithTimeIntervalSinceReferenceDate:sqlite3_column_double(statement, 4)] forKey:@"lastPlayed"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 5)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 5)] forKey:@"playCount"];
		}
		
		// Metadata
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 6))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"title"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 7))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"albumTitle"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 8))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"artist"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 9))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"albumArtist"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 10))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"genre"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 11))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"composer"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 12))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"date"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 13)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 13)] forKey:@"compilation"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 14)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 14)] forKey:@"trackNumber"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 15)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 15)] forKey:@"trackTotal"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 16)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 16)] forKey:@"discNumber"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 17)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 17)] forKey:@"discTotal"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 18))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"comment"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 19))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"isrc"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 20))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"mcn"];
		}
		
		// Properties
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 21))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"fileType"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 22))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"formatType"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 23)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 23)] forKey:@"bitsPerChannel"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 24)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 24)] forKey:@"channelsPerFrame"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 25)) {
			[value initValue:[NSNumber numberWithDouble:sqlite3_column_double(statement, 25)] forKey:@"sampleRate"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 26)) {
			[value initValue:[NSNumber numberWithLongLong:sqlite3_column_int64(statement, 26)] forKey:@"totalFrames"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 27)) {
			[value initValue:[NSNumber numberWithDouble:sqlite3_column_double(statement, 27)] forKey:@"duration"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 28)) {
			[value initValue:[NSNumber numberWithDouble:sqlite3_column_double(statement, 28)] forKey:@"bitrate"];
		}
		
		NSAssert(nil != [value valueForKey:@"id"], @"No id for stream!");
		
		[_streams addObject:[value autorelease]];
	}
	
	NSAssert1(SQLITE_DONE == result, @"Error while fetching streams (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Loaded %i streams in %f seconds (%i streams per second)", [_streams count], elapsed, (double)[_streams count] / elapsed);
#endif
	
	[self didChangeValueForKey:@"streams"];	
}

- (void) fetchPlaylists
{
	// Fetch all the playlist objects (of all types) in the database
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"select_all_playlists"];
	int				result			= SQLITE_OK;
	const char		*rawText		= NULL;
	NSString		*text			= nil;
	Playlist		*value			= nil;
				
	NSAssert(NULL != _db, NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	[self willChangeValueForKey:@"playlists"];
	
	// TODO: For performance, cache the array and update it with any changes when the view is switched
	
	// "Forget" the current playlists
	[_playlists removeAllObjects];
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	while(SQLITE_ROW == (result = sqlite3_step(statement))) {
		value = [[Playlist alloc] init];
		
		// Playlist ID, type and name
		if(SQLITE_NULL != sqlite3_column_type(statement, 0)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 0)] forKey:@"id"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 1)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 1)] forKey:@"type"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 2))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"name"];
		}
		
		// Statistics
		if(SQLITE_NULL != sqlite3_column_type(statement, 3)) {
			[value initValue:[NSDate dateWithTimeIntervalSinceReferenceDate:sqlite3_column_double(statement, 3)] forKey:@"dateAdded"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 4)) {
			[value initValue:[NSDate dateWithTimeIntervalSinceReferenceDate:sqlite3_column_double(statement, 4)] forKey:@"firstPlayed"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 5)) {
			[value initValue:[NSDate dateWithTimeIntervalSinceReferenceDate:sqlite3_column_double(statement, 5)] forKey:@"lastPlayed"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 6)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 6)] forKey:@"playCount"];
		}
				
		NSAssert(nil != [value valueForKey:@"id"], @"No id for playlist!");
		
		[_playlists addObject:[value autorelease]];
	}
	
	NSAssert1(SQLITE_DONE == result, @"Error while fetching playlists (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Loaded %i playlists in %f seconds (%i playlists per second)", [_playlists count], elapsed, (double)[_playlists count] / elapsed);
#endif
	
	[self didChangeValueForKey:@"playlists"];	
}

- (void) fetchStreamsForPlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	NSParameterAssert(nil != [playlist valueForKey:@"id"]);
	
	switch([playlist type]) {
		case ePlaylistTypeStaticPlaylist:	[self fetchStreamsForStaticPlaylist:playlist];	break;
		case ePlaylistTypeFolderPlaylist:	[self fetchStreamsForFolderPlaylist:playlist];	break;
		case ePlaylistTypeDynamicPlaylist:	[self fetchStreamsForDynamicPlaylist:playlist];	break;
	}
}

- (void) fetchStreamsForStaticPlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	NSParameterAssert(nil != [playlist valueForKey:@"id"]);
	NSParameterAssert(ePlaylistTypeStaticPlaylist == [playlist type]);

	sqlite3_stmt	*statement		= NULL;
	int				result			= SQLITE_OK;
	const char		*rawText		= NULL;
	NSString		*text			= nil;
	AudioStream		*value			= nil;
	const char		*tail			= NULL;
	NSError			*error			= nil;
	NSString		*path			= [[NSBundle mainBundle] pathForResource:@"select_streams_for_static_playlist" ofType:@"sql"];
	NSString		*sqlTemplate	= [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	NSString		*tableName		= [playlist tableName];
	NSString		*sql			= [NSString stringWithFormat:sqlTemplate, tableName, tableName];
	
	NSAssert1(nil != sql, NSLocalizedStringFromTable(@"Unable to locate sql file \"%@\".", @"Database", @""), @"select_streams_for_static_playlist");

	[self willChangeValueForKey:@"streams"];

	// "Forget" the current streams
	[_streams removeAllObjects];

#if SQL_DEBUG
		clock_t start = clock();
#endif
		
	result = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to prepare sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	while(SQLITE_ROW == (result = sqlite3_step(statement))) {
		value = [[AudioStream alloc] init];
		
		// Stream ID and location
		if(SQLITE_NULL != sqlite3_column_type(statement, 0)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 0)] forKey:@"id"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 1))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:[NSURL URLWithString:text] forKey:@"url"];
		}
		
		// Statistics
		if(SQLITE_NULL != sqlite3_column_type(statement, 2)) {
			[value initValue:[NSDate dateWithTimeIntervalSinceReferenceDate:sqlite3_column_double(statement, 2)] forKey:@"dateAdded"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 3)) {
			[value initValue:[NSDate dateWithTimeIntervalSinceReferenceDate:sqlite3_column_double(statement, 3)] forKey:@"firstPlayed"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 4)) {
			[value initValue:[NSDate dateWithTimeIntervalSinceReferenceDate:sqlite3_column_double(statement, 4)] forKey:@"lastPlayed"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 5)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 5)] forKey:@"playCount"];
		}
		
		// Metadata
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 6))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"title"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 7))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"albumTitle"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 8))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"artist"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 9))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"albumArtist"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 10))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"genre"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 11))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"composer"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 12))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"date"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 13)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 13)] forKey:@"compilation"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 14)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 14)] forKey:@"trackNumber"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 15)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 15)] forKey:@"trackTotal"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 16)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 16)] forKey:@"discNumber"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 17)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 17)] forKey:@"discTotal"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 18))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"comment"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 19))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"isrc"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 20))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"mcn"];
		}
		
		// Properties
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 21))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"fileType"];
		}
		if(NULL != (rawText = (const char *)sqlite3_column_text(statement, 22))) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"formatType"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 23)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 23)] forKey:@"bitsPerChannel"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 24)) {
			[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 24)] forKey:@"channelsPerFrame"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 25)) {
			[value initValue:[NSNumber numberWithDouble:sqlite3_column_double(statement, 25)] forKey:@"sampleRate"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 26)) {
			[value initValue:[NSNumber numberWithLongLong:sqlite3_column_int64(statement, 26)] forKey:@"totalFrames"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 27)) {
			[value initValue:[NSNumber numberWithDouble:sqlite3_column_double(statement, 27)] forKey:@"duration"];
		}
		if(SQLITE_NULL != sqlite3_column_type(statement, 28)) {
			[value initValue:[NSNumber numberWithDouble:sqlite3_column_double(statement, 28)] forKey:@"bitrate"];
		}
		
		// Playlist entry info
		if(SQLITE_NULL != sqlite3_column_type(statement, 31)) {
			[value initValue:[NSNumber numberWithDouble:sqlite3_column_double(statement, 31)] forKey:@"playlistPosition"];
		}
		
		NSAssert(nil != [value valueForKey:@"id"], @"No id for stream!");
		
		[_streams addObject:[value autorelease]];
	}
	
	NSAssert1(SQLITE_DONE == result, @"Error while fetching streams (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);

#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Loaded %i streams in %f seconds (%i streams per second)", [_streams count], elapsed, (double)[_streams count] / elapsed);
#endif

	[self didChangeValueForKey:@"streams"];
}

- (void) fetchStreamsForFolderPlaylist:(Playlist *)playlist
{
	
}

- (void) fetchStreamsForDynamicPlaylist:(Playlist *)playlist
{
	
}

#pragma mark Stream Management

- (AudioStream *) insertStreamForURL:(NSURL *)url streamInfo:(NSDictionary *)streamInfo
{
	NSParameterAssert(nil != url);
	NSParameterAssert(nil != streamInfo);
	
	AudioStream		*stream			= [[AudioStream alloc] init];
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"insert_stream"];
	int				result			= SQLITE_OK;
	id				value			= nil;
	
	NSAssert(NULL != _db, NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	// Store metadata and properties
	[stream initValue:url forKey:@"url"];
	
	[stream initValue:[NSDate date] forKey:@"dateAdded"];
	[stream initValue:[NSNumber numberWithUnsignedInt:0] forKey:@"playCount"];
	
	[stream initValue:[streamInfo valueForKey:@"title"] forKey:@"title"];
	[stream initValue:[streamInfo valueForKey:@"albumTitle"] forKey:@"albumTitle"];	
	[stream initValue:[streamInfo valueForKey:@"artist"] forKey:@"artist"];
	[stream initValue:[streamInfo valueForKey:@"albumArtist"] forKey:@"albumArtist"];
	[stream initValue:[streamInfo valueForKey:@"genre"] forKey:@"genre"];
	[stream initValue:[streamInfo valueForKey:@"composer"] forKey:@"composer"];
	[stream initValue:[streamInfo valueForKey:@"date"] forKey:@"date"];
	[stream initValue:[streamInfo valueForKey:@"compilation"] forKey:@"compilation"];
	[stream initValue:[streamInfo valueForKey:@"trackNumber"] forKey:@"trackNumber"];
	[stream initValue:[streamInfo valueForKey:@"trackTotal"] forKey:@"trackTotal"];
	[stream initValue:[streamInfo valueForKey:@"discNumber"] forKey:@"discNumber"];
	[stream initValue:[streamInfo valueForKey:@"discTotal"] forKey:@"discTotal"];
	[stream initValue:[streamInfo valueForKey:@"comment"] forKey:@"comment"];
	[stream initValue:[streamInfo valueForKey:@"isrc"] forKey:@"isrc"];
	[stream initValue:[streamInfo valueForKey:@"mcn"] forKey:@"mcn"];
	
	[stream initValue:[streamInfo valueForKey:@"fileType"] forKey:@"fileType"];
	[stream initValue:[streamInfo valueForKey:@"formatType"] forKey:@"formatType"];
	[stream initValue:[streamInfo valueForKey:@"bitsPerChannel"] forKey:@"bitsPerChannel"];
	[stream initValue:[streamInfo valueForKey:@"channelsPerFrame"] forKey:@"channelsPerFrame"];
	[stream initValue:[streamInfo valueForKey:@"sampleRate"] forKey:@"sampleRate"];
	[stream initValue:[streamInfo valueForKey:@"totalFrames"] forKey:@"totalFrames"];
	[stream initValue:[streamInfo valueForKey:@"duration"] forKey:@"duration"];
	[stream initValue:[streamInfo valueForKey:@"bitrate"] forKey:@"bitrate"];
	
	// If there is no real metadata set the filename as the title
	if(nil == [streamInfo valueForKey:@"title"] && nil == [streamInfo valueForKey:@"albumTitle"] && nil == [streamInfo valueForKey:@"artist"]) {
		[stream initValue:[[NSFileManager defaultManager] displayNameAtPath:[url path]] forKey:@"title"];
	}
	
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
		NSAssert2(SQLITE_DONE == result, @"Unable to insert a record for %@ (%@).", [[NSFileManager defaultManager] displayNameAtPath:[url path]], [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		[stream initValue:[NSNumber numberWithInt:sqlite3_last_insert_rowid(_db)] forKey:@"id"];
		
		result = sqlite3_reset(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_clear_bindings(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	
	@catch(NSException *exception) {
		NSLog(@"%@",exception);
		[stream release], stream = nil;
		
		// Ignore the result code, because it will always be an error in this case
		// (sqlite3_reset returns the result of the previous operation and we are in a catch block)
		/*result =*/ sqlite3_reset(statement);
	}
	
/*#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Stream insertion time = %f seconds", elapsed);
#endif*/
	
	return [stream autorelease];
}

- (void) updateStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	NSParameterAssert(nil != [stream valueForKey:@"id"]);
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"update_stream"];
	int				result			= SQLITE_OK;
	id				value			= nil;
	
	NSAssert(NULL != _db, NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	// Statistics
	if(nil != (value = [stream valueForKey:@"firstPlayed"])) {
		result = sqlite3_bind_double(statement, 1, [value timeIntervalSinceReferenceDate]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:@"lastPlayed"])) {
		result = sqlite3_bind_double(statement, 2, [value timeIntervalSinceReferenceDate]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:@"playCount"])) {
		result = sqlite3_bind_int(statement, 3, [value intValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	
	// Metadata
	if(nil != (value = [stream valueForKey:@"title"])) {
		result = sqlite3_bind_text(statement, 4, [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:@"albumTitle"])) {
		result = sqlite3_bind_text(statement, 5, [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:@"artist"])) {
		result = sqlite3_bind_text(statement, 6, [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:@"albumArtist"])) {
		result = sqlite3_bind_text(statement, 7, [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:@"genre"])) {
		result = sqlite3_bind_text(statement, 8, [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:@"composer"])) {
		result = sqlite3_bind_text(statement, 9, [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:@"date"])) {
		result = sqlite3_bind_text(statement, 10, [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:@"compilation"])) {
		result = sqlite3_bind_int(statement, 11, [value boolValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:@"trackNumber"])) {
		result = sqlite3_bind_int(statement, 12, [value unsignedIntValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:@"trackTotal"])) {
		result = sqlite3_bind_int(statement, 13, [value unsignedIntValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:@"discNumber"])) {
		result = sqlite3_bind_int(statement, 14, [value unsignedIntValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:@"discTotal"])) {
		result = sqlite3_bind_int(statement, 15, [value unsignedIntValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:@"comment"])) {
		result = sqlite3_bind_text(statement, 16, [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:@"isrc"])) {
		result = sqlite3_bind_text(statement, 17, [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [stream valueForKey:@"mcn"])) {
		result = sqlite3_bind_text(statement, 18, [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	
	// Object ID
	result = sqlite3_bind_int(statement, 19, [[stream valueForKey:@"id"] unsignedIntValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	
	result = sqlite3_step(statement);
	NSAssert2(SQLITE_DONE == result, @"Unable to update the record for %@ (%@).", [[NSFileManager defaultManager] displayNameAtPath:[[stream valueForKey:@"url"] path]], [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_clear_bindings(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Stream update time = %f seconds", elapsed);
#endif	
}

- (void) deleteStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	NSParameterAssert(nil != [stream valueForKey:@"id"]);
	
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"delete_stream"];
	int				result			= SQLITE_OK;
	
	NSAssert(NULL != _db, NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	result = sqlite3_bind_int(statement, 1, [[stream valueForKey:@"id"] unsignedIntValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert2(SQLITE_DONE == result, @"Unable to delete the record for %@ (%@).", [[NSFileManager defaultManager] displayNameAtPath:[[stream valueForKey:@"url"] path]], [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_clear_bindings(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Stream delete time = %f seconds", elapsed);
#endif	
}

#pragma mark Playlist Management

- (Playlist *) insertPlaylistOfType:(ePlaylistType)type name:(NSString *)name
{
	Playlist		*playlist		= [[Playlist alloc] init];
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"insert_playlist"];
	int				result			= SQLITE_OK;
	id				value			= nil;
	
	NSAssert(NULL != _db, NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
	// Store metadata and properties
	[playlist initValue:name forKey:@"name"];
	[playlist initValue:[NSNumber numberWithInt:ePlaylistTypeStaticPlaylist] forKey:@"type"];
	
	[playlist initValue:[NSDate date] forKey:@"dateAdded"];
	[playlist initValue:[NSNumber numberWithUnsignedInt:0] forKey:@"playCount"];

#if SQL_DEBUG
		clock_t start = clock();
#endif
	
	@try {
		// Playlist type and name
		result = sqlite3_bind_int(statement, 1, [[playlist valueForKey:@"type"] intValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		if(nil != (value = [playlist valueForKey:@"name"])) {
			result = sqlite3_bind_text(statement, 2, [value UTF8String], -1, SQLITE_TRANSIENT);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		
		// Statistics
		if(nil != (value = [playlist valueForKey:@"dateAdded"])) {
			result = sqlite3_bind_double(statement, 3, [value timeIntervalSinceReferenceDate]);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
		if(nil != (value = [playlist valueForKey:@"playCount"])) {
			result = sqlite3_bind_int(statement, 6, [value intValue]);
			NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		}
				
		result = sqlite3_step(statement);
		NSAssert1(SQLITE_DONE == result, @"Unable to insert a playlist (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		[playlist initValue:[NSNumber numberWithInt:sqlite3_last_insert_rowid(_db)] forKey:@"id"];
		
		result = sqlite3_reset(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_clear_bindings(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	
	@catch(NSException *exception) {
		NSLog(@"%@",exception);
		[playlist release], playlist = nil;
		
		// Ignore the result code, because it will always be an error in this case
		// (sqlite3_reset returns the result of the previous operation and we are in a catch block)
		/*result =*/ sqlite3_reset(statement);
	}

	@try {
		[self createEntryTableForPlaylist:playlist];
	}

	@catch(NSException *exception) {
		NSLog(@"%@",exception);
		[self deletePlaylist:playlist];
		[playlist release], playlist = nil;
	}
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Playlist insertion time = %f seconds", elapsed);
#endif
	
	return [playlist autorelease];
}

- (void) updatePlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	NSParameterAssert(nil != [playlist valueForKey:@"id"]);

	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"update_playlist"];
	int				result			= SQLITE_OK;
	id				value			= nil;
	
	NSAssert(NULL != _db, NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	// Name
	if(nil != (value = [playlist valueForKey:@"name"])) {
		result = sqlite3_bind_text(statement, 1, [value UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}

	// Statistics
	if(nil != (value = [playlist valueForKey:@"firstPlayed"])) {
		result = sqlite3_bind_double(statement, 2, [value timeIntervalSinceReferenceDate]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [playlist valueForKey:@"lastPlayed"])) {
		result = sqlite3_bind_double(statement, 3, [value timeIntervalSinceReferenceDate]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	if(nil != (value = [playlist valueForKey:@"playCount"])) {
		result = sqlite3_bind_int(statement, 4, [value intValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	
	// Object ID
	result = sqlite3_bind_int(statement, 5, [[playlist valueForKey:@"id"] unsignedIntValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to update the record (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_clear_bindings(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Playlist update time = %f seconds", elapsed);
#endif
}

- (void) deletePlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != playlist);
	NSParameterAssert(nil != [playlist valueForKey:@"id"]);

	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"delete_playlist"];
	int				result			= SQLITE_OK;
	
	NSAssert(NULL != _db, NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));
	
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	[self dropEntryTableForPlaylist:playlist];
	
	result = sqlite3_bind_int(statement, 1, [[playlist valueForKey:@"id"] unsignedIntValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to delete the record (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_reset(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_clear_bindings(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Playlist delete time = %f seconds", elapsed);
#endif	
}

- (void) addStreamIDs:(NSArray *)streamIDs toPlaylist:(Playlist *)playlist
{
	NSParameterAssert(nil != streamIDs);
	NSParameterAssert(nil != playlist);
	NSParameterAssert(nil != [playlist valueForKey:@"id"]);
	NSParameterAssert(ePlaylistTypeStaticPlaylist == [playlist type]);
	
	sqlite3_stmt	*statement		= NULL;
	int				result			= SQLITE_OK;
	const char		*tail			= NULL;
	NSError			*error			= nil;
	NSString		*path			= [[NSBundle mainBundle] pathForResource:@"insert_static_playlist_entry_table_entry" ofType:@"sql"];
	NSString		*sqlTemplate	= [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	NSString		*tableName		= [playlist tableName];
	NSString		*sql			= [NSString stringWithFormat:sqlTemplate, tableName];
	NSEnumerator	*enumerator		= [streamIDs objectEnumerator];
	NSNumber		*streamID		= nil;
	
	NSAssert1(nil != sql, NSLocalizedStringFromTable(@"Unable to locate sql file \"%@\".", @"Database", @""), @"insert_static_playlist_entry_table_entry");
		
#if SQL_DEBUG
	clock_t start = clock();
#endif
	
	result = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to prepare sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	while((streamID = [enumerator nextObject])) {

		result = sqlite3_bind_int(statement, 1, [streamID intValue]);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_step(statement);
		NSAssert1(SQLITE_DONE == result, @"Unable to insert the record (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_reset(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to reset sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_clear_bindings(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to clear sql statement bindings (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);		
	}
		
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
#if SQL_DEBUG
	clock_t end = clock();
	double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
	NSLog(@"Added %i streams to %@ in %f seconds (%i streams per second)", [streamIDs count], playlist, elapsed, (double)[streamIDs count] / elapsed);
#endif
}

@end
