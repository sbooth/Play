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

/*
 * Special thanks to Michael Ash for the code to dynamically show and hide
 * table columns.  Some of the code in the windowControllerDidLoadNib: method,
 * and most of the code in the tableViewColumnDidMove:, tableViewColumnDidResize:, 
 * saveStreamTableColumnOrder:, and streamTableHeaderContextMenuSelected: methods come from his
 * Creatures source code.  The copyright for those portions is:
 *
 * Copyright (c) 2005, Michael Ash
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of the author nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "AudioLibrary.h"
#import "AudioPlayer.h"
#import "AudioStream.h"
#import "Playlist.h"

#import "AudioPropertiesReader.h"
#import "AudioMetadataReader.h"
#import "AudioMetadataWriter.h"

#import "AudioStreamInformationSheet.h"
#import "AudioMetadataEditingSheet.h"

//#import "ImageAndTextCell.h"

#include "sfmt19937.h"

// ========================================
// The global instance
// ========================================
static AudioLibrary *defaultLibrary = nil;

// ========================================
// Notification names
// ========================================
NSString * const	AudioStreamAddedToLibraryNotification		= @"org.sbooth.Play.LibraryDocument.AudioStreamAddedToLibraryNotification";
NSString * const	AudioStreamDeletedFromLibraryNotification	= @"org.sbooth.Play.LibraryDocument.AudioStreamDeletedFromLibraryNotification";
NSString * const	AudioStreamPlaybackDidStartNotification		= @"org.sbooth.Play.LibraryDocument.AudioStreamPlaybackDidStartNotification";
NSString * const	AudioStreamPlaybackDidStopNotification		= @"org.sbooth.Play.LibraryDocument.AudioStreamPlaybackDidStopNotification";
NSString * const	AudioStreamPlaybackDidPauseNotification		= @"org.sbooth.Play.LibraryDocument.AudioStreamPlaybackDidPauseNotification";
NSString * const	AudioStreamPlaybackDidResumeNotification	= @"org.sbooth.Play.LibraryDocument.AudioStreamPlaybackDidResumeNotification";

// ========================================
// Notification keys
// ========================================
NSString * const	AudioStreamObjectKey						= @"org.sbooth.Play.AudioStream";

// ========================================
// Callback Methods (for sheets, etc.)
// ========================================
@interface AudioLibrary (CallbackMethods)
- (void) openDocumentSheetDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void *)contextInfo;
- (void) showStreamInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void) showMetadataEditingSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end

// ========================================
// Database Methods
// To support moving to a different datastore in the future,
// all access to the database is done in these methods.
// ========================================
@interface AudioLibrary (DatabaseMethods)

- (void) prepareSQL;
- (void) finalizeSQL;
- (sqlite3_stmt *) preparedStatementForAction:(NSString *)action;

- (void) connectToDatabase:(NSString *)databasePath;
- (void) disconnectFromDatabase;

- (void) beginTransaction;
- (void) commitTransaction;
- (void) rollbackTransaction;

- (void) createStreamTable;
- (void) createPlaylistTable;

- (void) fetchData;

- (void) fetchStreams;
- (void) fetchStreamsForPlaylist:(Playlist *)playlist;
- (void) fetchPlaylists;

// Stream manipulation
- (AudioStream *) insertStreamForURL:(NSURL *)url streamInfo:(NSDictionary *)streamInfo;
- (void) updateStream:(AudioStream *)stream;
- (void) deleteStream:(AudioStream *)stream;

- (void) updatePlaylist:(Playlist *)playlist;

@end

// ========================================
// Private Methods
// ========================================
@interface AudioLibrary (Private)

- (AudioPlayer *) player;

- (void) playStream:(AudioStream *)stream;

- (void) updatePlayButtonState;

- (void) setupStreamButtons;
- (void) setupPlaylistButtons;
- (void) setupStreamTableColumns;
- (void) setupPlaylistTable;

- (void) saveStreamTableColumnOrder;
- (IBAction) streamTableHeaderContextMenuSelected:(id)sender;

@end

@implementation AudioLibrary

+ (void)initialize
{
	// Setup table column defaults
	NSDictionary *visibleColumnsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:NO], @"id",
		[NSNumber numberWithBool:YES], @"title",
		[NSNumber numberWithBool:YES], @"albumTitle",
		[NSNumber numberWithBool:YES], @"artist",
		[NSNumber numberWithBool:NO], @"albumArtist",
		[NSNumber numberWithBool:YES], @"genre",
		[NSNumber numberWithBool:YES], @"track",
		[NSNumber numberWithBool:NO], @"fileType",
		[NSNumber numberWithBool:YES], @"formatType",
		[NSNumber numberWithBool:NO], @"composer",
		[NSNumber numberWithBool:YES], @"duration",
		[NSNumber numberWithBool:NO], @"playCount",
		[NSNumber numberWithBool:NO], @"lastPlayed",
		[NSNumber numberWithBool:NO], @"date",
		[NSNumber numberWithBool:NO], @"compilation",
		nil];
	
	NSDictionary *columnSizesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithFloat:50], @"id",
		[NSNumber numberWithFloat:186], @"title",
		[NSNumber numberWithFloat:128], @"albumTitle",
		[NSNumber numberWithFloat:129], @"artist",
		[NSNumber numberWithFloat:129], @"albumArtist",
		[NSNumber numberWithFloat:63], @"genre",
		[NSNumber numberWithFloat:54], @"track",
		[NSNumber numberWithFloat:88], @"fileType",
		[NSNumber numberWithFloat:88], @"formatType",
		[NSNumber numberWithFloat:99], @"composer",
		[NSNumber numberWithFloat:74], @"duration",
		[NSNumber numberWithFloat:72], @"playCount",
		[NSNumber numberWithFloat:96], @"lastPlayed",
		[NSNumber numberWithFloat:50], @"date",
		[NSNumber numberWithFloat:70], @"compilation",
		nil];
	
	NSDictionary *columnOrderArray = [NSArray arrayWithObjects:
		@"title", @"artist", @"albumTitle", @"genre", @"track", @"formatType", nil];
	
	NSDictionary *streamTableDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
		visibleColumnsDictionary, @"streamTableColumnVisibility",
		columnSizesDictionary, @"streamTableColumnSizes",
		columnOrderArray, @"streamTableColumnOrder",
		nil];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:streamTableDefaults];
}	

+ (AudioLibrary *) defaultLibrary
{
	@synchronized(self) {
		if(nil == defaultLibrary) {
			defaultLibrary = [[self alloc] init];
		}
	}
	return defaultLibrary;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == defaultLibrary) {
            return [super allocWithZone:zone];
        }
    }
    return defaultLibrary;
}

- (id) init
{
	if((self = [super initWithWindowNibName:@"AudioLibrary"])) {
		
		// Seed random number generator
		init_gen_rand(time(NULL));

		_streams	= [[NSMutableArray alloc] init];
		_playlists	= [[NSMutableArray alloc] init];
		_sql		= [[NSMutableDictionary alloc] init];
		
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
		NSAssert(nil != paths, NSLocalizedStringFromTable(@"Unable to locate the \"Application Support\" folder.", @"General", @""));
		
		NSString *applicationName			= [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
		NSString *applicationSupportFolder	= [[paths objectAtIndex:0] stringByAppendingPathComponent:applicationName];
		
		if(NO == [[NSFileManager defaultManager] fileExistsAtPath:applicationSupportFolder]) {
			BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:applicationSupportFolder attributes:nil];
			NSAssert(YES == success, NSLocalizedStringFromTable(@"Unable to create the \"Application Support\" folder.", @"General", @""));
		}
		
		NSString *databasePath = [applicationSupportFolder stringByAppendingPathComponent:@"Library.sqlite3"];
		
		[self connectToDatabase:databasePath];
		
		[self createStreamTable];
		[self createPlaylistTable];
		
		[self prepareSQL];

		return self;
	}
	return nil;
}

- (void) dealloc
{
	[self finalizeSQL];
	[self disconnectFromDatabase];

	[_player release], _player = nil;

	[_streamTableVisibleColumns release], _streamTableVisibleColumns = nil;
	[_streamTableHiddenColumns release], _streamTableHiddenColumns = nil;
	[_streamTableHeaderContextMenu release], _streamTableHeaderContextMenu = nil;

	[_nowPlaying release], _nowPlaying = nil;

	[_sql release], _sql = nil;
	[_streams release], _streams = nil;
	[_playlists release], _playlists = nil;
	[_undoManager release], _undoManager = nil;
	
	[super dealloc];
}

- (void) awakeFromNib
{
	[self fetchData];
	
	// Setup drag and drop
	[_streamTable registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, NSURLPboardType, nil]];
	[_playlistTable registerForDraggedTypes:[NSArray arrayWithObject:@"AudioStreamPboardType"]];
	
	// Set sort descriptors
	[_streamController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:@"albumTitle" ascending:YES] autorelease],
		[[[NSSortDescriptor alloc] initWithKey:@"trackNumber" ascending:YES] autorelease],
		[[[NSSortDescriptor alloc] initWithKey:@"artist" ascending:YES] autorelease],
		nil]];
	[_playlistController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES] autorelease],
		nil]];
	
	// Default window state
	[self updatePlayButtonState];
	[_albumArtImageView setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
	
	[self setupStreamButtons];
	[self setupPlaylistButtons];
	[self setupStreamTableColumns];
	[self setupPlaylistTable];	
}

- (void) windowDidLoad
{
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Library"];
	[[self window] setExcludedFromWindowsMenu:YES];
}

- (void) windowWillClose:(NSNotification *)aNotification
{
	[self stop:self];	
}

- (BOOL) validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
	if([anItem action] == @selector(playPause:)) {
		return [self playButtonEnabled];
	}
	else if([anItem action] == @selector(addFiles:)) {
		return [_streamController canAdd];
	}
	else if([anItem action] == @selector(showStreamInformationSheet:)) {
		return (0 != [[_streamController selectedObjects] count]);
	}
	else if([anItem action] == @selector(showPlaylistInformationSheet:)) {
		return (0 != [[_playlistController selectedObjects] count]);
	}
	else if([anItem action] == @selector(skipForward:) 
			|| [anItem action] == @selector(skipBackward:) 
			|| [anItem action] == @selector(skipToEnd:) 
			|| [anItem action] == @selector(skipToBeginning:)) {
		return [[self player] hasValidStream];
	}
	else if([anItem action] == @selector(playNextStream:)) {
		return [self canPlayNextStream];
	}
	else if([anItem action] == @selector(playPreviousStream:)) {
		return [self canPlayPreviousStream];
	}
	else if([anItem action] == @selector(nextPlaylist:)) {
		return [_playlistController canSelectNext];
	}
	else if([anItem action] == @selector(previousPlaylist:)) {
		return [_playlistController canSelectPrevious];
	}
	else if([anItem action] == @selector(insertStaticPlaylist:)
			|| [anItem action] == @selector(insertDynamicPlaylist:)
			|| [anItem action] == @selector(insertFolderPlaylist:)) {
		return [_playlistController canInsert];
	}
	else if([anItem action] == @selector(insertPlaylistWithSelectedStreams:)) {
		return (0 != [[_streamController selectedObjects] count]);
	}
	else if([anItem action] == @selector(scrollNowPlayingToVisible:)) {
		return (nil != [self nowPlaying] && [[_streamController arrangedObjects] containsObject:[self nowPlaying]]);
	}
	else if([anItem action] == @selector(undo:)) {
		return [[self undoManager] canUndo];
	}
	else if([anItem action] == @selector(redo:)) {
		return [[self undoManager] canRedo];
	}

	return YES;
}

#pragma mark Action Methods

- (IBAction) openDocument:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:YES];
	[panel setCanChooseDirectories:YES];
	
	[panel beginSheetForDirectory:nil 
							 file:nil 
							types:nil 
				   modalForWindow:[self window] 
					modalDelegate:self 
				   didEndSelector:@selector(openDocumentSheetDidEnd:returnCode:contextInfo:)
					  contextInfo:nil];
}

- (IBAction) scrollNowPlayingToVisible:(id)sender
{
	AudioStream *stream = [self nowPlaying];
	if(nil != stream && [[_streamController arrangedObjects] containsObject:stream]) {
		[_streamTable scrollRowToVisible:[[_streamController arrangedObjects] indexOfObject:stream]];
	}
}

- (IBAction) showStreamInformationSheet:(id)sender
{
	NSArray *streams = [_streamController selectedObjects];
		
	if(0 == [streams count]) {
		return;
	}
	else if(1 == [streams count]) {
		AudioStreamInformationSheet *streamInformationSheet = [[AudioStreamInformationSheet alloc] init];
		
		[streamInformationSheet setValue:[streams objectAtIndex:0] forKey:@"stream"];
		[streamInformationSheet setValue:self forKey:@"owner"];
		
//		[self beginTransaction];
		
		[[NSApplication sharedApplication] beginSheet:[streamInformationSheet sheet] 
									   modalForWindow:[self window] 
										modalDelegate:self 
									   didEndSelector:@selector(showStreamInformationSheetDidEnd:returnCode:contextInfo:) 
										  contextInfo:streamInformationSheet];
	}
	else {
		AudioMetadataEditingSheet *metadataEditingSheet = [[AudioMetadataEditingSheet alloc] init];
		
		[metadataEditingSheet setValue:[_streamController selection] forKey:@"streams"];
		[metadataEditingSheet setValue:self forKey:@"owner"];

//		[self beginTransaction];

		[[NSApplication sharedApplication] beginSheet:[metadataEditingSheet sheet] 
									   modalForWindow:[self window] 
										modalDelegate:self 
									   didEndSelector:@selector(showMetadataEditingSheetDidEnd:returnCode:contextInfo:) 
										  contextInfo:metadataEditingSheet];
	}
}

- (IBAction) newPlaylist:(id)sender
{
/*	Playlist		*playlist			= [[Playlist alloc] init];
	sqlite3_stmt	*statement			= NULL;
	int				result				= SQLITE_OK;
	const char		*tail				= NULL;
	
	[playlist initValue:@"Untitled" forKey:@"name"];
	
	// Create the entry for the playist in the playlist table
	result = sqlite3_prepare_v2(_db, "INSERT INTO playlists (name) VALUES (?)", -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, @"Unable to prepare sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_bind_text(statement, 1, [[playlist valueForKey:@"name"] UTF8String], -1, SQLITE_TRANSIENT);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to insert a record (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, @"Unable to finalize sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	[playlist initValue:[NSNumber numberWithInt:sqlite3_last_insert_rowid(_db)] forKey:@"id"];
	
	// Create the table for the playlist
	NSString *tableName = [NSString stringWithFormat:@"_playlist_%@", [playlist valueForKey:@"id"]];
	NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS '%@' ('id' INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, 'stream_id' INTEGER UNIQUE, 'index' INTEGER)", tableName];
	result = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, @"Unable to prepare sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to create a playlist table (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, @"Unable to finalize sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	[_playlistController addObject:playlist];
	
	[playlist release];*/
}

#pragma mark File Addition

- (BOOL) addFile:(NSString *)filename
{
	AudioStream				*stream				= nil;
	NSError					*error				= nil;
	
	// First read the properties
	AudioPropertiesReader *propertiesReader = [AudioPropertiesReader propertiesReaderForURL:[NSURL fileURLWithPath:filename] error:&error];
	if(nil == propertiesReader) {
		return NO;
	}
	
	BOOL result = [propertiesReader readProperties:&error];
	if(NO == result) {
		return NO;
	}
	
	// Now read the metadata
	AudioMetadataReader *metadataReader	= [AudioMetadataReader metadataReaderForURL:[NSURL fileURLWithPath:filename] error:&error];
	if(nil == metadataReader) {		
		return NO;
	}
	
	result = [metadataReader readMetadata:&error];
	if(NO == result) {
		return NO;
	}
		
	NSDictionary *properties = [propertiesReader valueForKey:@"properties"];
	NSDictionary *metadata = [metadataReader valueForKey:@"metadata"];
	NSMutableDictionary *streamInfo = [NSMutableDictionary dictionary];
	[streamInfo addEntriesFromDictionary:properties];
	[streamInfo addEntriesFromDictionary:metadata];
	
	stream = [self insertStreamForURL:[NSURL fileURLWithPath:filename] streamInfo:streamInfo];
	
	if(nil != stream) {
		[_streamController addObject:stream];
	}
	
	return (nil != stream);
}

- (BOOL) addFiles:(NSArray *)filenames
{
	NSString				*filename				= nil;
	NSString				*path					= nil;
	NSFileManager			*fileManager			= [NSFileManager defaultManager];
	NSEnumerator			*filesEnumerator		= [filenames objectEnumerator];
	NSDirectoryEnumerator	*directoryEnumerator	= nil;
	BOOL					isDirectory				= NO;
	BOOL					openSuccessful			= NO;
	
	while((filename = [filesEnumerator nextObject])) {
		
		// Perform a deep search for directories
		if([fileManager fileExistsAtPath:filename isDirectory:&isDirectory] && isDirectory) {
			directoryEnumerator	= [fileManager enumeratorAtPath:filename];
			
			while((path = [directoryEnumerator nextObject])) {
				openSuccessful &= [self addFile:[filename stringByAppendingPathComponent:path]];
			}
		}
		else {
			openSuccessful = [self addFile:filename];
		}
	}
	
	return openSuccessful;
}

#pragma mark Playback Control

- (IBAction) play:(id)sender
{
	if(NO == [[self player] hasValidStream]) {
		if([self randomizePlayback]) {
			NSArray				*streams;
			AudioStream			*stream;	
			double				randomNumber;
			unsigned			randomIndex;
			
			streams				= [_streamController arrangedObjects];
			randomNumber		= genrand_real2();
			randomIndex			= (unsigned)(randomNumber * [streams count]);
			stream				= [streams objectAtIndex:randomIndex];
			
			[self playStream:stream];
		}
		else {
			[self playSelection:sender];
		}
	}
	else {
		[[self player] play];
		[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidResumeNotification 
															object:self 
														  userInfo:nil];
	}
	
	[self updatePlayButtonState];
}

- (IBAction) playPause:(id)sender
{
	if(NO == [[self player] hasValidStream]) {
		[self play:sender];
	}
	else {
		[[self player] playPause];
		
		if([[self player] isPlaying]) {
			[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidResumeNotification 
																object:self
															  userInfo:nil];
		}
		else {
			[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidPauseNotification
																object:self
															  userInfo:nil];
		}
	}
	
	[self updatePlayButtonState];
}

- (IBAction) playSelection:(id)sender
{
	if(0 == [[_streamController selectedObjects] count]) {
		[self playStream:[[_streamController arrangedObjects] objectAtIndex:0]];
	}
	else {
		[self playStream:[[_streamController selectedObjects] objectAtIndex:0]];
	}
	
	[self updatePlayButtonState];
}

- (IBAction) stop:(id)sender
{
	if([[self player] hasValidStream]) {
		[[self player] stop];
		[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidStopNotification 
															object:self
														  userInfo:nil];
	}
	
	[self updatePlayButtonState];
}

- (IBAction) skipForward:(id)sender
{
	[[self player] skipForward];
}

- (IBAction) skipBackward:(id)sender
{
	[[self player] skipBackward];
}

- (IBAction) skipToEnd:(id)sender
{
	[[self player] skipToEnd];
}

- (IBAction) skipToBeginning:(id)sender
{
	[[self player] skipToBeginning];
}

- (IBAction) playNextStream:(id)sender
{
	AudioStream		*stream			= [self nowPlaying];
	unsigned		streamIndex;
	
	[self setNowPlaying:nil];
	[stream setIsPlaying:NO];
	
	NSArray *streams = [_streamController arrangedObjects];
	
	if(nil == stream || 0 == [streams count]) {
		[[self player] reset];
		[self updatePlayButtonState];
	}
	else if([self randomizePlayback]) {
		double			randomNumber;
		unsigned		randomIndex;
		
		randomNumber	= genrand_real2();
		randomIndex		= (unsigned)(randomNumber * [streams count]);
		stream			= [streams objectAtIndex:randomIndex];
		
		[self playStream:stream];
	}
	else if([self loopPlayback]) {
		streamIndex = [streams indexOfObject:stream];
		
		if(streamIndex + 1 < [streams count]) {
			stream = [streams objectAtIndex:streamIndex + 1];			
		}
		else {
			stream = [streams objectAtIndex:0];
		}
		
		[self playStream:stream];
	}
	else {
		streamIndex = [streams indexOfObject:stream];
		
		if(streamIndex + 1 < [streams count]) {
			stream = [streams objectAtIndex:streamIndex + 1];
			[self playStream:stream];
		}
		else {
			[[self player] reset];
			[self updatePlayButtonState];
		}
	}
}

- (IBAction) playPreviousStream:(id)sender
{
	AudioStream		*stream			= [self nowPlaying];
	unsigned		streamIndex;
	
	[self setNowPlaying:nil];
	[stream setIsPlaying:NO];
	
	NSArray *streams = [_streamController arrangedObjects];
	
	if(nil == stream || 0 == [streams count]) {
		[[self player] reset];	
	}
	else if([self randomizePlayback]) {
		double			randomNumber;
		unsigned		randomIndex;
		
		randomNumber	= genrand_real2();
		randomIndex		= (unsigned)(randomNumber * [streams count]);
		stream			= [streams objectAtIndex:randomIndex];
		
		[self playStream:stream];
	}
	else if([self loopPlayback]) {
		streamIndex = [streams indexOfObject:stream];
		
		if(1 <= streamIndex) {
			stream = [streams objectAtIndex:streamIndex - 1];
		}
		else {
			stream = [streams objectAtIndex:[streams count] - 1];
		}
		
		[self playStream:stream];
	}
	else {
		streamIndex = [streams indexOfObject:stream];
		
		if(1 <= streamIndex) {
			stream = [streams objectAtIndex:streamIndex - 1];
			[self playStream:stream];
		}
		else {
			[[self player] reset];	
		}
	}
}

#pragma mark Properties

- (BOOL)		randomizePlayback									{ return _randomizePlayback; }
- (void)		setRandomizePlayback:(BOOL)randomizePlayback		{ _randomizePlayback = randomizePlayback; }

- (BOOL)		loopPlayback										{ return _loopPlayback; }
- (void)		setLoopPlayback:(BOOL)loopPlayback					{ _loopPlayback = loopPlayback; }

- (BOOL)		playButtonEnabled									{ return _playButtonEnabled; }
- (void)		setPlayButtonEnabled:(BOOL)playButtonEnabled		{ _playButtonEnabled = playButtonEnabled; }

- (BOOL) canPlayNextStream
{
	AudioStream		*stream		= [self nowPlaying];
	NSArray			*streams	= [_streamController arrangedObjects];
	BOOL			result;
	
	if(nil == stream || 0 == [streams count]) {
		result = NO;
	}
	else if([self randomizePlayback]) {
		result = YES;
	}
	else if([self loopPlayback]) {
		result = YES;
	}
	else {
		unsigned streamIndex = [streams indexOfObject:stream];
		result = (streamIndex + 1 < [streams count]);
	}
	
	return result;
}

- (BOOL) canPlayPreviousStream
{
	AudioStream		*stream		= [self nowPlaying];
	NSArray			*streams	= [_streamController arrangedObjects];
	BOOL			result;
	
	if(nil == stream || 0 == [streams count]) {
		result = NO;
	}
	else if([self randomizePlayback]) {
		result = YES;
	}
	else if([self loopPlayback]) {
		result = YES;
	}
	else {
		unsigned streamIndex = [streams indexOfObject:stream];
		result = (1 <= streamIndex);
	}
	
	return result;
}

- (AudioStream *) nowPlaying
{
	return _nowPlaying;
}

- (void) setNowPlaying:(AudioStream *)nowPlaying
{
	[_nowPlaying release];
	_nowPlaying = [nowPlaying retain];
	
	// Update window title
	NSString *title			= [[self nowPlaying] valueForKey:@"title"];
	NSString *artist		= [[self nowPlaying] valueForKey:@"artist"];
	NSString *windowTitle	= [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	
	if(nil != title && nil != artist) {
		windowTitle = [NSString stringWithFormat:@"%@ - %@", artist, title];
	}
	else if(nil != title) {
		windowTitle = title;
	}
	else if(nil != artist) {
		windowTitle = artist;
	}
			
	[[self window] setTitle:windowTitle];
}

- (NSUndoManager *) undoManager
{
	if(nil == _undoManager) {
		_undoManager = [[NSUndoManager alloc] init];
	}
	return _undoManager;
}

#pragma mark Stream KVC Accessor Methods

- (unsigned int) countOfStreams
{
	return [_streams count];
}

- (id) objectInStreamsAtIndex:(unsigned int)index
{
	// The stream in question already exists in the database if it is in the array
	return [_streams objectAtIndex:index];
}

- (void) getStreams:(id *)buffer range:(NSRange)aRange
{
	// The streams in question already exist in the database if they are in the array
	return [_streams getObjects:buffer range:aRange];
}

#pragma mark Stream KVC Mutator Methods

- (void) insertObject:(id)stream inStreamsAtIndex:(unsigned int)index
{
	// The stream represented must already be added to the database	
	[_streams insertObject:stream atIndex:index];

	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamAddedToLibraryNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
}

- (void) removeObjectFromStreamsAtIndex:(unsigned int)index
{
	// To keep the database and in-memory representation in sync, remove the 
	// stream from the database first and then from the array if the removal
	// was successful
	[self deleteStream:[_streams objectAtIndex:index]];		
	[_streams removeObjectAtIndex:index];

//	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamDeletedFromLibraryNotification 
//														object:self 
//													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
}

#pragma mark Playlist KVC Accessor Methods

- (unsigned int) countOfPlaylists
{
	return [_playlists count];
}

- (id) objectInPlaylistsAtIndex:(unsigned int)index
{
	// The playlist in question already exists in the database if it is in the array
	return [_playlists objectAtIndex:index];
}

- (void) getPlaylists:(id *)buffer range:(NSRange)aRange
{
	// The playlists in question already exist in the database if they are in the array
	return [_playlists getObjects:buffer range:aRange];
}

#pragma mark Playlist KVC Mutator Methods

- (void) insertObject:(id)stream inPlaylistsAtIndex:(unsigned int)index
{
	// The playlist represented must already be added to the database	
	[_playlists insertObject:stream atIndex:index];
}

- (void) removeObjectFromPlaylistsAtIndex:(unsigned int)index
{
	// To keep the database and in-memory representation in sync, remove the 
	// playlist from the database first and then from the array if the removal
	// was successful
	Playlist		*playlist			= [_playlists objectAtIndex:index];
	sqlite3_stmt	*statement			= NULL;
	int				result				= SQLITE_OK;
	const char		*tail				= NULL;
	
	// TODO: Move prepared statement to an ivar
	result = sqlite3_prepare_v2(_db, "DELETE FROM playlists WHERE id == ?", -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, @"Unable to prepare sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_bind_int(statement, 1, [[playlist valueForKey:@"id"] intValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to delete the record (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);		
	
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, @"Unable to finalize sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	NSString *tableName = [NSString stringWithFormat:@"_playlist_%@", [playlist valueForKey:@"id"]];
	NSString *sql = [NSString stringWithFormat:@"DROP TABLE %@", tableName];
	result = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, @"Unable to prepare sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to delete the playlist table (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, @"Unable to finalize sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	[_playlists removeObjectAtIndex:index];
}

#pragma mark AudioPlayer Callbacks

- (void) streamPlaybackDidStart:(NSURL *)url
{
	AudioStream		*stream		= [self nowPlaying];
	NSNumber		*playCount;
	NSNumber		*newPlayCount;

	playCount		= [stream valueForKey:@"playCount"];
	newPlayCount	= [NSNumber numberWithUnsignedInt:[playCount unsignedIntValue] + 1];
	
	[stream setIsPlaying:NO];

	[self beginTransaction];
	
	[stream setValue:[NSDate date] forKey:@"lastPlayed"];
	[stream setValue:newPlayCount forKey:@"playCount"];
	
	if(nil == [stream valueForKey:@"firstPlayed"]) {
		[stream setValue:[NSDate date] forKey:@"firstPlayed"];
	}
	
	[self commitTransaction];
	
	NSArray *filtered = [_streams filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"url == %@", url]];
	
	if(0 < [filtered count]) {
		stream = [filtered objectAtIndex:0];
		[stream setIsPlaying:YES];
		[self setNowPlaying:stream];
		[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidStartNotification 
															object:self 
														  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
	}
}

- (void) streamPlaybackDidComplete
{
	AudioStream		*stream		= [self nowPlaying];
	NSNumber		*playCount;
	NSNumber		*newPlayCount;
	
	playCount		= [stream valueForKey:@"playCount"];
	newPlayCount	= [NSNumber numberWithUnsignedInt:[playCount unsignedIntValue] + 1];
	
	[stream setIsPlaying:NO];

	[self beginTransaction];
	
	[stream setValue:[NSDate date] forKey:@"lastPlayed"];
	[stream setValue:newPlayCount forKey:@"playCount"];
	
	if(nil == [stream valueForKey:@"firstPlayed"]) {
		[stream setValue:[NSDate date] forKey:@"firstPlayed"];
	}
	
	[self commitTransaction];
	
	[self playNextStream:self];
}

- (void) requestNextStream
{
	AudioStream		*stream			= [self nowPlaying];
	unsigned		streamIndex;
	
	NSArray *streams = [_streamController arrangedObjects];
	
	if(nil == stream || 0 == [streams count]) {
		stream = nil;
	}
	else if([self randomizePlayback]) {
		double			randomNumber;
		unsigned		randomIndex;
		
		randomNumber	= genrand_real2();
		randomIndex		= (unsigned)(randomNumber * [streams count]);
		stream			= [streams objectAtIndex:randomIndex];
	}
	else if([self loopPlayback]) {
		streamIndex = [streams indexOfObject:stream];
		
		if(streamIndex + 1 < [streams count]) {
			stream = [streams objectAtIndex:streamIndex + 1];			
		}
		else {
			stream = [streams objectAtIndex:0];
		}
	}
	else {
		streamIndex = [streams indexOfObject:stream];
		
		if(streamIndex + 1 < [streams count]) {
			stream = [streams objectAtIndex:streamIndex + 1];
		}
		else {
			stream = nil;
		}
	}
	
	if(nil != stream) {
		NSError		*error		= nil;
		BOOL		result		= [[self player] setNextStreamURL:[stream valueForKey:@"url"] error:&error];
		
		if(NO == result) {
			if(nil != error) {
				
			}
		}
	}
}

#pragma mark Changed Object Callbacks

- (void) audioStreamDidChange:(AudioStream *)stream
{
	[self updateStream:stream];
	
	NSError					*error			= nil;
	AudioMetadataWriter		*metadataWriter = [AudioMetadataWriter metadataWriterForURL:[stream valueForKey:@"url"] error:&error];
	BOOL					result			= [metadataWriter writeMetadata:stream error:&error];
	NSAssert(YES == result, @"Unable to save metadata to file.");
}

- (void) playlistDidChange:(Playlist *)playlist
{
	[self updatePlaylist:playlist];
}

@end

@implementation AudioLibrary (NSTableViewDelegateMethods)

- (void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
	if([[aNotification object] isEqual:_playlistTable]) {
		
		unsigned count = [[_playlistController selectedObjects] count];
		
		if(0 == count) {
			[self fetchStreams];
		}
		else if(1 == count) {
			[self fetchStreamsForPlaylist:[[_playlistController selectedObjects] objectAtIndex:0]];
			
		}
		else {
			// SELECT [...] FROM streams WHERE id IN (SELECT stream_id FROM _playlist_9) OR id IN (SELECT stream_id FROM _playlist_10)
		}		
	}
}

- (NSString *) tableView:(NSTableView *)aTableView toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(int)row mouseLocation:(NSPoint)mouseLocation
{
    if([aCell isKindOfClass:[NSTextFieldCell class]]) {
        if([[aCell attributedStringValue] size].width > rect->size.width) {
            return [aCell stringValue];
        }
    }
	
    return nil;
}

- (void) tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
/*	if([aTableView isEqual:_playlistTableView] && [[aTableColumn identifier] isEqualToString:@"name"]) {
		NSDictionary			*infoForBinding;
		
		infoForBinding			= [aTableView infoForBinding:NSContentBinding];
		
		if(nil != infoForBinding) {
			NSArrayController	*arrayController;
			Playlist			*playlistObject;
			
			arrayController		= [infoForBinding objectForKey:NSObservedObjectKey];
			playlistObject		= [[arrayController arrangedObjects] objectAtIndex:rowIndex];
			
			[aCell setImage:[playlistObject imageScaledToSize:NSMakeSize(16.0, 16.0)]];
		}
	}
	else*/ if([aTableView isEqual:_streamTable]) {
		NSDictionary *infoForBinding = [aTableView infoForBinding:NSContentBinding];
		
		if(nil != infoForBinding && [aCell respondsToSelector:@selector(setDrawsBackground:)]) {
			NSArrayController	*arrayController	= [infoForBinding objectForKey:NSObservedObjectKey];
			AudioStream			*stream				= [[arrayController arrangedObjects] objectAtIndex:rowIndex];
			
			// Highlight the currently playing stream (doesn't work for NSButtonCell)
			if([stream isPlaying]) {
				[aCell setDrawsBackground:YES];
				
				// Emacs "NavajoWhite" -> 255, 222, 173
				//				[aCell setBackgroundColor:[NSColor colorWithCalibratedRed:(255/255.f) green:(222/255.f) blue:(173/255.f) alpha:1.0]];
				// Emacs "LightSteelBlue" -> 176, 196, 222
				[aCell setBackgroundColor:[NSColor colorWithCalibratedRed:(176/255.f) green:(196/255.f) blue:(222/255.f) alpha:1.0]];
			}
			else {
				[aCell setDrawsBackground:NO];
			}
		}
	}
}

- (void) tableViewColumnDidMove:(NSNotification *)aNotification
{
	if([[aNotification object] isEqual:_streamTable]) {
		[self saveStreamTableColumnOrder];
	}
}

- (void) tableViewColumnDidResize:(NSNotification *)aNotification
{
	if([[aNotification object] isEqual:_streamTable]) {
		NSMutableDictionary		*sizes			= [NSMutableDictionary dictionary];
		NSEnumerator			*enumerator		= [[_streamTable tableColumns] objectEnumerator];
		id						column;
		
		while((column = [enumerator nextObject])) {
			[sizes setObject:[NSNumber numberWithFloat:[column width]] forKey:[column identifier]];
		}
		
		[[NSUserDefaults standardUserDefaults] setObject:sizes forKey:@"streamTableColumnSizes"];
	}
}

@end

@implementation AudioLibrary (CallbackMethods)

- (void) openDocumentSheetDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void *)contextInfo
{	
	if(NSOKButton == returnCode) {
#if SQL_DEBUG
		unsigned startCount = [_streams count];
		clock_t start = clock();
#endif
		
		[self beginTransaction];
		[self addFiles:[panel filenames]];
		[self commitTransaction];

#if SQL_DEBUG
		clock_t end = clock();
		unsigned endCount = [_streams count];
		unsigned filesAdded = endCount - startCount;
		double elapsed = (end - start) / (double)CLOCKS_PER_SEC;
		NSLog(@"Added %i files in %f seconds (%i files per second)", filesAdded, elapsed, (double)filesAdded / elapsed);
#endif
	}
}

- (void) showStreamInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	AudioStreamInformationSheet *streamInformationSheet = (AudioStreamInformationSheet *)contextInfo;
	
	[sheet orderOut:self];
	
	if(NSOKButton == returnCode) {
//		[self commitTransaction];
		[_streamController rearrangeObjects];
	}
	else if(NSCancelButton == returnCode) {
//		[self rollbackTransaction];
		// TODO: refresh affected objects
	}
	
	[streamInformationSheet release];
}

- (void) showMetadataEditingSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	AudioMetadataEditingSheet *metadataEditingSheet = (AudioMetadataEditingSheet *)contextInfo;
	
	[sheet orderOut:self];
	
	if(NSOKButton == returnCode) {
//		[self commitTransaction];
		[_streamController rearrangeObjects];
	}
	else if(NSCancelButton == returnCode) {
//		[self rollbackTransaction];
		// TODO: refresh affected objects
	}
	
	[metadataEditingSheet release];
}

@end

@implementation AudioLibrary (NSWindowDelegateMethods)

- (void) windowWillClose:(NSNotification *)aNotification
{
	[self stop:self];
	[[self player] reset];
}

- (NSUndoManager *) windowWillReturnUndoManager:(NSWindow *)sender
{
	return [self undoManager];
}

@end

@implementation AudioLibrary (DatabaseMethods)

- (void) prepareSQL
{
	NSError			*error				= nil;	
	NSString		*path				= nil;
	NSString		*sql				= nil;
	NSString		*filename			= nil;
	NSArray			*files				= [NSArray arrayWithObjects:@"begin_transaction", @"commit_transaction", @"rollback_transaction", @"select_all_streams", @"insert_stream", @"update_stream", @"delete_stream", nil];
	NSEnumerator	*enumerator			= [files objectEnumerator];
	sqlite3_stmt	*statement			= NULL;
	int				result				= SQLITE_OK;
	const char		*tail				= NULL;
	
	while((filename = [enumerator nextObject])) {
		path 	= [[NSBundle mainBundle] pathForResource:filename ofType:@"sql"];
		sql 	= [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
		NSAssert1(nil != sql, NSLocalizedStringFromTable(@"Unable to locate sql file \"%@\".", @"Database", @""), filename);
		
		result = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, &tail);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to prepare sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
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
	
	NSAssert(NULL != _db, NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));

	// Create the playlists table
	result = sqlite3_prepare_v2(_db, "CREATE TABLE IF NOT EXISTS 'playlists' ('id' INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, 'name' TEXT)", -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to prepare sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to create the playlists table (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}

#pragma mark Data Retrieval

- (void) fetchData
{
	[self fetchStreams];
	[self fetchPlaylists];
}

- (void) fetchStreams
{
	// Fetch all the objects in the database
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
	NSLog(@"Loaded %i files in %f seconds (%i files per second)", [_streams count], elapsed, (double)[_streams count] / elapsed);
#endif

	[self didChangeValueForKey:@"streams"];	
}

- (void) fetchStreamsForPlaylist:(Playlist *)playlist
{
	// Fetch the appropriate streams from the database
	sqlite3_stmt	*statement			= NULL;
	int				result				= SQLITE_OK;
	const char		*tail				= NULL;
	const char		*rawText			= NULL;
	NSString		*text				= nil;
	AudioStream		*value				= nil;
	NSString		*sql				= nil;
	
	NSAssert(NULL != _db, NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));

	[self willChangeValueForKey:@"streams"];
	
	// "Forget" the current streams
	[_streams removeAllObjects];
	
	sql = [NSString stringWithFormat:@"SELECT id, filename, title, artist, album_title FROM streams WHERE id IN (SELECT stream_id FROM %@)", [NSString stringWithFormat:@"_playlist_%@", [playlist valueForKey:@"id"]]];
	
	result = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to prepare sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	while(SQLITE_ROW == (result = sqlite3_step(statement))) {
		value = [[AudioStream alloc] init];
		
		[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 0)] forKey:@"id"];
		
		rawText = (const char *)sqlite3_column_text(statement, 1);
		if(NULL != rawText) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:[NSURL URLWithString:text] forKey:@"url"];
		}
		rawText = (const char *)sqlite3_column_text(statement, 2);
		if(NULL != rawText) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"title"];
		}
		rawText = (const char *)sqlite3_column_text(statement, 3);
		if(NULL != rawText) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"artist"];
		}
		rawText = (const char *)sqlite3_column_text(statement, 4);
		if(NULL != rawText) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"albumTitle"];
		}
		
		[_streams addObject:[value autorelease]];
	}
	
	NSAssert1(SQLITE_DONE == result, @"Error while fetching streams (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);

	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);

	[self didChangeValueForKey:@"streams"];
}

- (void) fetchPlaylists
{
	// Fetch all the objects in the database
	sqlite3_stmt	*statement			= NULL;
	int				result				= SQLITE_OK;
	const char		*tail				= NULL;
	const char		*rawText			= NULL;
	NSString		*text				= nil;
	Playlist		*value				= nil;
				
	NSAssert(NULL != _db, NSLocalizedStringFromTable(@"Not connected to database", @"Database", @""));

	[self willChangeValueForKey:@"playlists"];
	
	// "Forget" the current playlists
	[_playlists removeAllObjects];
	
	// TODO: Move prepared statement to an ivar
	result = sqlite3_prepare_v2(_db, "SELECT id, name FROM playlists", -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to prepare sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	while(SQLITE_ROW == (result = sqlite3_step(statement))) {
		value = [[Playlist alloc] init];
		
		[value initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, 0)] forKey:@"id"];
		
		rawText = (const char *)sqlite3_column_text(statement, 1);
		if(NULL != rawText) {
			text = [NSString stringWithCString:rawText encoding:NSUTF8StringEncoding];
			[value initValue:text forKey:@"name"];
		}
		
		[_playlists addObject:[value autorelease]];
	}
	
	NSAssert1(SQLITE_DONE == result, @"Error while fetching playlists (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);

	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);

	[self didChangeValueForKey:@"playlists"];
}

#pragma mark Stream Management

- (AudioStream *) insertStreamForURL:(NSURL *)url streamInfo:(NSDictionary *)streamInfo
{
	AudioStream		*stream			= [[AudioStream alloc] init];
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"insert_stream"];
	int				result			= SQLITE_OK;
	id				value			= nil;
	
	NSParameterAssert(nil != url);
	NSParameterAssert(nil != streamInfo);
	
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
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"update_stream"];
	int				result			= SQLITE_OK;
	id				value			= nil;
	
	NSParameterAssert(nil != stream);
	NSParameterAssert(nil != [stream valueForKey:@"id"]);

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
	sqlite3_stmt	*statement		= [self preparedStatementForAction:@"delete_stream"];
	int				result			= SQLITE_OK;
	
	NSParameterAssert(nil != stream);
	NSParameterAssert(nil != [stream valueForKey:@"id"]);
	
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

- (void) updatePlaylist:(Playlist *)playlist
{
	sqlite3_stmt	*statement			= NULL;
	int				result				= SQLITE_OK;
	const char		*tail				= NULL;
	
	// TODO: Move prepared statement to an ivar
	result = sqlite3_prepare_v2(_db, "UPDATE playlists SET name = ? WHERE id == ?", -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, @"Unable to prepare sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_bind_text(statement, 1, [[playlist valueForKey:@"name"] UTF8String], -1, SQLITE_TRANSIENT);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_bind_int(statement, 2, [[playlist valueForKey:@"id"] intValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to update the record (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}


/*- (AudioStream *) insertStreamForFile:(NSString *)filename streamInfo:(NSDictionary *)streamInfo
{
	AudioStream		*stream				= [[AudioStream alloc] init];
	sqlite3_stmt	*statement			= NULL;
	int				result				= SQLITE_OK;
	const char		*tail				= NULL;
	
	// Store metadata and properties
	[stream initValue:filename forKey:@"filename"];
	[stream initValue:[streamInfo valueForKey:@"title"] forKey:@"title"];
	[stream initValue:[streamInfo valueForKey:@"artist"] forKey:@"artist"];
	[stream initValue:[streamInfo valueForKey:@"albumTitle"] forKey:@"albumTitle"];	
	
	@try {
		// TODO: Move prepared statement to an ivar
		result = sqlite3_prepare_v2(_db, "INSERT INTO streams (filename, title, artist, album_title) VALUES (?, ?, ?, ?)", -1, &statement, &tail);
		NSAssert1(SQLITE_OK == result, @"Unable to prepare sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_bind_text(statement, 1, [[stream valueForKey:@"filename"] UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_bind_text(statement, 2, [[stream valueForKey:@"title"] UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_bind_text(statement, 3, [[stream valueForKey:@"artist"] UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_bind_text(statement, 4, [[stream valueForKey:@"albumTitle"] UTF8String], -1, SQLITE_TRANSIENT);
		NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		result = sqlite3_step(statement);
		NSAssert1(SQLITE_DONE == result, @"Unable to insert a record (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
		
		[stream initValue:[NSNumber numberWithInt:sqlite3_last_insert_rowid(_db)] forKey:@"id"];
		
		result = sqlite3_finalize(statement);
		NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	}
	
	@catch(NSException *exception) {
		NSLog(@"Caught:%@",exception);
		[stream release], stream = nil;
	}
	
	return [stream autorelease];
}

- (void) updateStream:(AudioStream *)stream
{
	sqlite3_stmt	*statement			= NULL;
	int				result				= SQLITE_OK;
	const char		*tail				= NULL;
	
	// TODO: Move prepared statement to an ivar
	result = sqlite3_prepare_v2(_db, "UPDATE streams SET title = ?, artist = ?, album_title = ? WHERE id == ?", -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, @"Unable to prepare sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_bind_text(statement, 1, [[stream valueForKey:@"title"] UTF8String], -1, SQLITE_TRANSIENT);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_bind_text(statement, 2, [[stream valueForKey:@"artist"] UTF8String], -1, SQLITE_TRANSIENT);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_bind_text(statement, 3, [[stream valueForKey:@"albumTitle"] UTF8String], -1, SQLITE_TRANSIENT);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_bind_int(statement, 4, [[stream valueForKey:@"id"] intValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to update the record (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);		
	
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}

- (void) deleteStream:(AudioStream *)stream
{
	sqlite3_stmt	*statement			= NULL;
	int				result				= SQLITE_OK;
	const char		*tail				= NULL;
	
	// TODO: Move prepared statement to an ivar
	result = sqlite3_prepare_v2(_db, "DELETE FROM streams WHERE id == ?", -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, @"Unable to prepare sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_bind_int(statement, 1, [[stream valueForKey:@"id"] intValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to delete the record (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);		
	
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}

- (void) updatePlaylist:(Playlist *)playlist
{
	sqlite3_stmt	*statement			= NULL;
	int				result				= SQLITE_OK;
	const char		*tail				= NULL;
	
	// TODO: Move prepared statement to an ivar
	result = sqlite3_prepare_v2(_db, "UPDATE playlists SET name = ? WHERE id == ?", -1, &statement, &tail);
	NSAssert1(SQLITE_OK == result, @"Unable to prepare sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_bind_text(statement, 1, [[playlist valueForKey:@"name"] UTF8String], -1, SQLITE_TRANSIENT);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_bind_int(statement, 2, [[playlist valueForKey:@"id"] intValue]);
	NSAssert1(SQLITE_OK == result, @"Unable to bind parameter to sql statement (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_step(statement);
	NSAssert1(SQLITE_DONE == result, @"Unable to update the record (%@).", [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
	
	result = sqlite3_finalize(statement);
	NSAssert1(SQLITE_OK == result, NSLocalizedStringFromTable(@"Unable to finalize sql statement (%@).", @"Database", @""), [NSString stringWithUTF8String:sqlite3_errmsg(_db)]);
}*/

@end

@implementation AudioLibrary (Private)

- (AudioPlayer *) player
{
	if(nil == _player) {
		_player = [[AudioPlayer alloc] init];
		[_player setOwner:self];
	}
	return _player;
}

- (void) playStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	
	AudioStream *currentStream = [self nowPlaying];
	
	[[self player] stop];
	
	if(nil != currentStream) {
		[currentStream setIsPlaying:NO];
		[self setNowPlaying:nil];
	}
	
	NSError		*error		= nil;
	BOOL		result		= [[self player] setStreamURL:[stream valueForKey:@"url"] error:&error];
	
	if(NO == result) {
		/*BOOL errorRecoveryDone =*/ [self presentError:error];
		return;
	}
	
	[stream setIsPlaying:YES];	
	[self setNowPlaying:stream];
	
	if(nil == [stream valueForKey:@"albumArt"]) {
		[_albumArtImageView setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
	}
	
	[[self player] play];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioStreamPlaybackDidStartNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:stream forKey:AudioStreamObjectKey]];
	
	[self updatePlayButtonState];
}

- (void) updatePlayButtonState
{
	NSString						*buttonImagePath, *buttonAlternateImagePath;
	NSImage							*buttonImage, *buttonAlternateImage;
	
	if([[self player] isPlaying]) {		
		buttonImagePath				= [[NSBundle mainBundle] pathForResource:@"player_pause" ofType:@"png"];
		buttonAlternateImagePath	= [[NSBundle mainBundle] pathForResource:@"player_play" ofType:@"png"];
		buttonImage					= [[NSImage alloc] initWithContentsOfFile:buttonImagePath];
		buttonAlternateImage		= [[NSImage alloc] initWithContentsOfFile:buttonAlternateImagePath];
		
		[_playPauseButton setState:NSOnState];
		[_playPauseButton setImage:buttonImage];
		[_playPauseButton setAlternateImage:buttonAlternateImage];
		[_playPauseButton setToolTip:@"Pause playback"];
		
		[self setPlayButtonEnabled:YES];
	}
	else if(NO == [[self player] hasValidStream]) {
		buttonImagePath				= [[NSBundle mainBundle] pathForResource:@"player_play" ofType:@"png"];
		buttonImage					= [[NSImage alloc] initWithContentsOfFile:buttonImagePath];
		
		[_playPauseButton setImage:buttonImage];
		[_playPauseButton setAlternateImage:nil];		
		[_playPauseButton setToolTip:@"Play"];
		
		[self setPlayButtonEnabled:(0 != [[_streamController arrangedObjects] count])];
	}
	else {
		buttonImagePath				= [[NSBundle mainBundle] pathForResource:@"player_play" ofType:@"png"];
		buttonAlternateImagePath	= [[NSBundle mainBundle] pathForResource:@"player_pause" ofType:@"png"];		
		buttonImage					= [[NSImage alloc] initWithContentsOfFile:buttonImagePath];
		buttonAlternateImage		= [[NSImage alloc] initWithContentsOfFile:buttonAlternateImagePath];
		
		[_playPauseButton setState:NSOffState];
		[_playPauseButton setImage:buttonImage];
		[_playPauseButton setAlternateImage:buttonAlternateImage];
		[_playPauseButton setToolTip:@"Resume playback"];
		
		[self setPlayButtonEnabled:YES];
	}
}

- (void) setupStreamButtons
{
	// Bind stream addition/removal button actions and state
	[_addStreamsButton setToolTip:@"Add audio streams to the library"];
	[_addStreamsButton bind:@"enabled"
				   toObject:_streamController
				withKeyPath:@"canInsert"
					options:nil];
	[_addStreamsButton setAction:@selector(openDocument:)];
	[_addStreamsButton setTarget:self];
	
	[_removeStreamsButton setToolTip:@"Remove the selected audio streams from the library"];
	[_removeStreamsButton bind:@"enabled"
					  toObject:_streamController
				   withKeyPath:@"canRemove"
					   options:nil];
	[_removeStreamsButton setAction:@selector(remove:)];
	[_removeStreamsButton setTarget:_streamController];
	
	[_streamInfoButton setToolTip:@"Show information on the selected streams"];
	[_streamInfoButton bind:@"enabled"
				   toObject:_streamController
				withKeyPath:@"selectedObjects.@count"
					options:nil];
	[_streamInfoButton setAction:@selector(showStreamInformationSheet:)];
	[_streamInfoButton setTarget:self];
}

- (void) setupPlaylistButtons
{
	NSMenu			*buttonMenu;
	NSMenuItem		*buttonMenuItem;
	
	// Bind playlist addition/removal button actions and state
	[_addPlaylistButton setToolTip:@"Add a new playlist to the library"];
	[_addPlaylistButton bind:@"enabled"
					toObject:_playlistController
				 withKeyPath:@"canInsert"
					 options:nil];
	
	buttonMenu			= [[NSMenu alloc] init];
	
	buttonMenuItem		= [[NSMenuItem alloc] init];
	[buttonMenuItem setTitle:@"New Playlist"];
	//	[buttonMenuItem setImage:[NSImage imageNamed:@"StaticPlaylist.png"]];
	[buttonMenuItem setTarget:self];
	[buttonMenuItem setAction:@selector(insertStaticPlaylist:)];
	[buttonMenu addItem:buttonMenuItem];
	[buttonMenuItem bind:@"enabled"
				toObject:_playlistController
			 withKeyPath:@"canInsert"
				 options:nil];
	[buttonMenuItem release];
	
	buttonMenuItem		= [[NSMenuItem alloc] init];
	[buttonMenuItem setTitle:@"New Playlist with Selection"];
	//	[buttonMenuItem setImage:[NSImage imageNamed:@"StaticPlaylist.png"]];
	[buttonMenuItem setTarget:self];
	[buttonMenuItem setAction:@selector(insertPlaylistWithSelectedStreams:)];
	[buttonMenu addItem:buttonMenuItem];
	[buttonMenuItem bind:@"enabled"
				toObject:_streamController
			 withKeyPath:@"selectedObjects.@count"
				 options:nil];
	[buttonMenuItem release];
	
	buttonMenuItem		= [[NSMenuItem alloc] init];
	[buttonMenuItem setTitle:@"New Dynamic Playlist"];
	//	[buttonMenuItem setImage:[NSImage imageNamed:@"DynamicPlaylist.png"]];
	[buttonMenuItem setTarget:self];
	[buttonMenuItem setAction:@selector(insertDynamicPlaylist:)];
	[buttonMenu addItem:buttonMenuItem];
	[buttonMenuItem release];
	
	buttonMenuItem		= [[NSMenuItem alloc] init];
	[buttonMenuItem setTitle:@"New Folder Playlist"];
	//	[buttonMenuItem setImage:[NSImage imageNamed:@"FolderPlaylist.png"]];
	[buttonMenuItem setTarget:self];
	[buttonMenuItem setAction:@selector(insertFolderPlaylist:)];
	[buttonMenu addItem:buttonMenuItem];
	[buttonMenuItem release];
	
	[_addPlaylistButton setMenu:buttonMenu];
	[buttonMenu release];
	
	[_removePlaylistsButton setToolTip:@"Remove the selected playlists from the library"];
	[_removePlaylistsButton bind:@"enabled"
						toObject:_playlistController
					 withKeyPath:@"canRemove"
						 options:nil];
	[_removePlaylistsButton setAction:@selector(remove:)];
	[_removePlaylistsButton setTarget:_playlistController];
	
	[_playlistInfoButton setToolTip:@"Show information on the selected playlist"];
	[_playlistInfoButton bind:@"enabled"
					 toObject:_playlistController
				  withKeyPath:@"selectedObjects.@count"
					  options:nil];
	[_playlistInfoButton setAction:@selector(showPlaylistInformationSheet:)];
	[_playlistInfoButton setTarget:self];
}

- (void) setupStreamTableColumns
{
	id <NSMenuItem> contextMenuItem;	
	id				obj;
	int				menuIndex, i;
	
	// Setup stream table columns
	NSDictionary	*visibleDictionary	= [[NSUserDefaults standardUserDefaults] objectForKey:@"streamTableColumnVisibility"];
	NSDictionary	*sizesDictionary	= [[NSUserDefaults standardUserDefaults] objectForKey:@"streamTableColumnSizes"];
	NSArray			*orderArray			= [[NSUserDefaults standardUserDefaults] objectForKey:@"streamTableColumnOrder"];
	
	NSArray			*tableColumns		= [_streamTable tableColumns];
	NSEnumerator	*enumerator			= [tableColumns objectEnumerator];
	
	_streamTableVisibleColumns			= [[NSMutableSet alloc] init];
	_streamTableHiddenColumns			= [[NSMutableSet alloc] init];
	_streamTableHeaderContextMenu		= [[NSMenu alloc] initWithTitle:@"Stream Table Header Context Menu"];
	
	[[_streamTable headerView] setMenu:_streamTableHeaderContextMenu];
	
	// Keep our changes from generating notifications to ourselves
	[_streamTable setDelegate:nil];
	
	while((obj = [enumerator nextObject])) {
		menuIndex = 0;
		
		while(menuIndex < [_streamTableHeaderContextMenu numberOfItems] 
			  && NSOrderedDescending == [[[obj headerCell] title] localizedCompare:[[_streamTableHeaderContextMenu itemAtIndex:menuIndex] title]]) {
			menuIndex++;
		}
		
		contextMenuItem = [_streamTableHeaderContextMenu insertItemWithTitle:[[obj headerCell] title] action:@selector(streamTableHeaderContextMenuSelected:) keyEquivalent:@"" atIndex:menuIndex];
		
		[contextMenuItem setTarget:self];
		[contextMenuItem setRepresentedObject:obj];
		[contextMenuItem setState:([[visibleDictionary objectForKey:[obj identifier]] boolValue] ? NSOnState : NSOffState)];
		
		//		NSLog(@"setting width of %@ to %f", [obj identifier], [[sizesDictionary objectForKey:[obj identifier]] floatValue]);
		[obj setWidth:[[sizesDictionary objectForKey:[obj identifier]] floatValue]];
		
		if([[visibleDictionary objectForKey:[obj identifier]] boolValue]) {
			[_streamTableVisibleColumns addObject:obj];
		}
		else {
			[_streamTableHiddenColumns addObject:obj];
			[_streamTable removeTableColumn:obj];
		}
	}
	
	i = 0;
	enumerator = [orderArray objectEnumerator];
	while((obj = [enumerator nextObject])) {
		[_streamTable moveColumn:[_streamTable columnWithIdentifier:obj] toColumn:i];
		++i;
	}
	
	[_streamTable setDelegate:self];
}

- (void) setupPlaylistTable
{
/*	// Setup playlist table
	NSTableColumn	*tableColumn	= [_playlistTable tableColumnWithIdentifier:@"name"];
	NSCell			*dataCell		= [[ImageAndTextCell alloc] init];
	
	[tableColumn setDataCell:dataCell];
	[tableColumn bind:@"value" toObject:_playlistController withKeyPath:@"arrangedObjects.name" options:nil];
	[dataCell release];	*/
}

#pragma mark Stream Table Management

- (void) saveStreamTableColumnOrder
{
	NSMutableArray	*identifiers	= [NSMutableArray array];
	NSEnumerator	*enumerator		= [[_streamTable tableColumns] objectEnumerator];
	id				obj;
	
	while((obj = [enumerator nextObject])) {
		[identifiers addObject:[obj identifier]];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:identifiers forKey:@"streamTableColumnOrder"];
	//	[[NSUserDefaults standardUserDefaults] synchronize];
}	

- (IBAction) streamTableHeaderContextMenuSelected:(id)sender
{
	if(NSOnState == [sender state]) {
		[sender setState:NSOffState];
		[_streamTableHiddenColumns addObject:[sender representedObject]];
		[_streamTableVisibleColumns removeObject:[sender representedObject]];
		[_streamTable removeTableColumn:[sender representedObject]];
	}
	else {
		[sender setState:NSOnState];
		[_streamTable addTableColumn:[sender representedObject]];
		[_streamTableVisibleColumns addObject:[sender representedObject]];
		[_streamTableHiddenColumns removeObject:[sender representedObject]];
	}
	
	NSMutableDictionary	*visibleDictionary	= [NSMutableDictionary dictionary];
	NSEnumerator		*enumerator			= [_streamTableVisibleColumns objectEnumerator];
	id					obj;
	
	while((obj = [enumerator nextObject])) {
		[visibleDictionary setObject:[NSNumber numberWithBool:YES] forKey:[obj identifier]];
	}
	
	enumerator = [_streamTableHiddenColumns objectEnumerator];
	while((obj = [enumerator nextObject])) {
		[visibleDictionary setObject:[NSNumber numberWithBool:NO] forKey:[obj identifier]];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:visibleDictionary forKey:@"streamTableColumnVisibility"];
	
	[self saveStreamTableColumnOrder];
}

@end
