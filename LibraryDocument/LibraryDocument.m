/*
 *  $Id$
 *
 *  Copyright (C) 2006 Stephen F. Booth <me@sbooth.org>
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

#import "LibraryDocument.h"
#import "AudioPropertiesReader.h"
#import "AudioMetadataReader.h"
#import "AudioStreamDecoder.h"
#import "AudioStreamInformationSheet.h"
#import "AudioMetadataEditingSheet.h"
#import "UtilityFunctions.h"

#import "ImageAndTextCell.h"

#include "mt19937ar.h"

#import <Growl/GrowlApplicationBridge.h>

@interface LibraryDocument (Private)

- (AudioPlayer *)			player;
- (NSThread *)				thread;

- (NSManagedObject *)		fetchLibraryObject;
- (NSManagedObject *)		fetchStreamObjectForURL:(NSURL *)url error:(NSError **)error;

- (void)					playStream:(NSArray *)streams;

- (void)					updatePlayButtonState;

- (void)					setupStreamButtons;
- (void)					setupPlaylistButtons;
- (void)					setupStreamTableColumns;
- (void)					setupPlaylistTable;

- (void)					addFilesOpenPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)					showStreamInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)					showMetadataEditingSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)					saveStreamTableColumnOrder;
- (IBAction)				streamTableHeaderContextMenuSelected:(id)sender;

- (void)					scheduleURLForAddition:(NSURL *)URL;
- (void)					insertEntityForURL:(NSDictionary *)arguments;

@end

@implementation LibraryDocument

+ (void)initialize
{
	// Setup table column defaults
	NSDictionary				*visibleColumnsDictionary;
	NSDictionary				*columnSizesDictionary;
	NSDictionary				*columnOrderArray;
	NSDictionary				*streamTableDefaults;
	
	visibleColumnsDictionary	= [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:YES], @"title",
		[NSNumber numberWithBool:YES], @"artist",
		[NSNumber numberWithBool:YES], @"albumTitle",
		[NSNumber numberWithBool:YES], @"genre",
		[NSNumber numberWithBool:YES], @"track",
		[NSNumber numberWithBool:YES], @"formatName",
		[NSNumber numberWithBool:NO], @"composer",
		[NSNumber numberWithBool:YES], @"duration",
		[NSNumber numberWithBool:NO], @"playCount",
		[NSNumber numberWithBool:NO], @"lastPlayed",
		[NSNumber numberWithBool:NO], @"date",
		nil];
	
	columnSizesDictionary		= [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithFloat:186], @"title",
		[NSNumber numberWithFloat:129], @"artist",
		[NSNumber numberWithFloat:128], @"albumTitle",
		[NSNumber numberWithFloat:63], @"genre",
		[NSNumber numberWithFloat:54], @"track",
		[NSNumber numberWithFloat:88], @"formatName",
		[NSNumber numberWithFloat:99], @"composer",
		[NSNumber numberWithFloat:74], @"duration",
		[NSNumber numberWithFloat:72], @"playCount",
		[NSNumber numberWithFloat:96], @"lastPlayed",
		[NSNumber numberWithFloat:50], @"date",
		nil];
	
	columnOrderArray			= [NSArray arrayWithObjects:
		@"title", @"artist", @"albumTitle", @"genre", @"track", @"formatName", nil];
	
	streamTableDefaults			= [NSDictionary dictionaryWithObjectsAndKeys:
		visibleColumnsDictionary, @"streamTableColumnVisibility",
		columnSizesDictionary, @"streamTableColumnSizes",
		columnOrderArray, @"streamTableColumnOrder",
		nil];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:streamTableDefaults];
}	

- (id) init
{
	if((self = [super init])) {
		_player			= [[AudioPlayer alloc] init];
		[[self player] setOwner:self];
		
		// Seed random number generator
		init_genrand(time(NULL));
		
		_libraryThread	= [[NSThread currentThread] retain];
		
		return self;
	}
	
	return nil;
}

- (id) initWithType:(NSString *)type error:(NSError **)error
{
    if((self = [super initWithType:type error:error])) {
		NSManagedObjectContext	*managedObjectContext;
		NSManagedObject			*libraryObject;
		
		// Each LibraryDocument instance should contain one (and only one) Library entity
		managedObjectContext	= [self managedObjectContext];
        libraryObject			= [NSEntityDescription insertNewObjectForEntityForName:@"Library" inManagedObjectContext:managedObjectContext];

		// Disable undo registration for the create
        [managedObjectContext processPendingChanges];
        [[managedObjectContext undoManager] removeAllActions];

        [self updateChangeCount:NSChangeCleared];
		
		return self;
    }
	
    return nil;
}

- (void) dealloc
{
	[_player release],							_player = nil;
	[_streamTableVisibleColumns release],		_streamTableVisibleColumns = nil;
	[_streamTableHiddenColumns release],		_streamTableHiddenColumns = nil;
	[_streamTableHeaderContextMenu release],	_streamTableHeaderContextMenu = nil;
	[_libraryThread release],					_libraryThread = nil;
	
	[super dealloc];
}

#pragma mark NSPersistentDocument Overrides

- (NSString *) windowNibName 
{
    return @"LibraryDocument";
}

- (void) windowControllerDidLoadNib:(NSWindowController *)windowController 
{
    [super windowControllerDidLoadNib:windowController];

//	[windowController setWindowFrameAutosaveName:[NSString stringWithFormat:@"Play Library %@", @""]];	

	// Setup drag and drop
	[_streamTableView registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, @"NSURLsPboardType", NSURLPboardType, nil]];
	[_playlistTableView registerForDraggedTypes:[NSArray arrayWithObject:@"AudioStreamPboardType"]];
	
	// Set sort descriptors
	[_streamArrayController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:@"metadata.artist" ascending:YES] autorelease],
		[[[NSSortDescriptor alloc] initWithKey:@"metadata.albumTitle" ascending:YES] autorelease],
		[[[NSSortDescriptor alloc] initWithKey:@"metadata.trackNumber" ascending:YES] autorelease],
		nil]];
	[_playlistArrayController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES] autorelease],
		nil]];
	
	// Default window state
	[self updatePlayButtonState];
	[_albumArtImageView setImage:[NSImage imageNamed:@"Play"]];
	
	[self setupStreamButtons];
	[self setupPlaylistButtons];
	[self setupStreamTableColumns];
	[self setupPlaylistTable];
}

- (void) windowWillClose:(NSNotification *)aNotification
{
	[[self player] stop];
	[[self player] reset];
}

- (BOOL) validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
	if([anItem action] == @selector(playPause:)) {
		return [self playButtonEnabled];
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
	else {
		return [super validateUserInterfaceItem:anItem];
	}
}

#pragma mark Action Methods

- (IBAction) insertStaticPlaylist:(id)sender;
{
	NSManagedObjectContext		*managedObjectContext;
	NSManagedObject				*playlistObject;
	NSManagedObject				*libraryObject;
	BOOL						selectionChanged;
	
//	[_playlistDrawer open];
	
	managedObjectContext		= [self managedObjectContext];
	playlistObject				= [NSEntityDescription insertNewObjectForEntityForName:@"StaticPlaylist" inManagedObjectContext:managedObjectContext];
	libraryObject				= [self fetchLibraryObject];
	
	[playlistObject setValue:libraryObject forKey:@"library"];
	[playlistObject setValue:[NSDate date] forKey:@"dateCreated"];

	selectionChanged			= [_playlistArrayController setSelectedObjects:[NSArray arrayWithObject:playlistObject]];

	if(selectionChanged) {
		// The playlist table has only one column
		[_playlistTableView editColumn:0 row:[_playlistTableView selectedRow] withEvent:nil select:YES];	
	}
}

- (IBAction) insertDynamicPlaylist:(id)sender
{
	NSManagedObjectContext		*managedObjectContext;
	NSManagedObject				*playlistObject;
	NSManagedObject				*libraryObject;
	BOOL						selectionChanged;
	
	//	[_playlistDrawer open];
	
	managedObjectContext		= [self managedObjectContext];
	playlistObject				= [NSEntityDescription insertNewObjectForEntityForName:@"DynamicPlaylist" inManagedObjectContext:managedObjectContext];
	libraryObject				= [self fetchLibraryObject];
	
	[playlistObject setValue:libraryObject forKey:@"library"];
	[playlistObject setValue:[NSDate date] forKey:@"dateCreated"];
	
	//	[playlistObject setPredicate:[NSPredicate predicateWithFormat:@"metadata.title LIKE[c] %@", @"*nat*"]];
	//	[playlistObject setPredicate:[NSPredicate predicateWithFormat:@"%K CONTAINS[c] %@", @"metadata.title", @"nat"]];
	//	[playlistObject setPredicate:[NSPredicate predicateWithFormat:@"url LIKE[c] %@", @"*nat*"]];
	//	[playlistObject setPredicate:[NSPredicate predicateWithFormat:@"url CONTAINS[c] %@", @"nat"]];
	//	[playlistObject setPredicate:[NSPredicate predicateWithFormat:@"playCount > 0"]];
	
	selectionChanged			= [_playlistArrayController setSelectedObjects:[NSArray arrayWithObject:playlistObject]];
	
	if(selectionChanged) {
		// The playlist table has only one column
		[_playlistTableView editColumn:0 row:[_playlistTableView selectedRow] withEvent:nil select:YES];	
	}
}

- (IBAction) insertFolderPlaylist:(id)sender
{
	NSManagedObjectContext		*managedObjectContext;
	NSManagedObject				*playlistObject;
	NSManagedObject				*libraryObject;
	BOOL						selectionChanged;

	//	[_playlistDrawer open];
	
	managedObjectContext		= [self managedObjectContext];
	playlistObject				= [NSEntityDescription insertNewObjectForEntityForName:@"FolderPlaylist" inManagedObjectContext:managedObjectContext];
	libraryObject				= [self fetchLibraryObject];
	
	[playlistObject setValue:libraryObject forKey:@"library"];
	[playlistObject setValue:[NSDate date] forKey:@"dateCreated"];

	selectionChanged			= [_playlistArrayController setSelectedObjects:[NSArray arrayWithObject:playlistObject]];
	
	if(selectionChanged) {
		// The playlist table has only one column
		[_playlistTableView editColumn:0 row:[_playlistTableView selectedRow] withEvent:nil select:YES];	
	}
}

- (IBAction) insertPlaylistWithSelectedStreams:(id)sender
{
	NSManagedObjectContext		*managedObjectContext;
	NSArray						*selectedStreams;
	NSManagedObject				*playlistObject;
	NSManagedObject				*libraryObject;
	NSMutableSet				*streamsSet;
	BOOL						selectionChanged;

//	[_playlistDrawer open];

	managedObjectContext		= [self managedObjectContext];
	selectedStreams				= [_streamArrayController selectedObjects];
	playlistObject				= [NSEntityDescription insertNewObjectForEntityForName:@"StaticPlaylist" inManagedObjectContext:managedObjectContext];
	libraryObject				= [self fetchLibraryObject];
	
	[playlistObject setValue:libraryObject forKey:@"library"];
	[playlistObject setValue:[NSDate date] forKey:@"dateCreated"];
	
	streamsSet					= [playlistObject mutableSetValueForKey:@"streams"];
	
	[streamsSet addObjectsFromArray:selectedStreams];
	
	selectionChanged			= [_playlistArrayController setSelectedObjects:[NSArray arrayWithObject:playlistObject]];

	if(selectionChanged) {
		// The playlist table has only one column
		[_playlistTableView editColumn:0 row:[_playlistTableView selectedRow] withEvent:nil select:YES];	
	}
}

- (IBAction) editPlaylist:(id)sender
{
	NSLog(@"editPlaylist");
}

- (IBAction) removeAudioStreams:(id)sender
{
	NSArray						*selectedStreams;
	NSArray						*selectedPlaylists;
	
	selectedStreams				= [_streamArrayController selectedObjects];
	selectedPlaylists			= [_playlistArrayController selectedObjects];

//	NSLog(@"stream=%@",[selectedStreams objectAtIndex:0]);
//	NSLog(@"playlist=%@",[selectedPlaylists objectAtIndex:0]);
//	[_streamArrayController remove:sender];
//	NSLog(@"stream=%@",[selectedStreams objectAtIndex:0]);
//	NSLog(@"playlist=%@",[selectedPlaylists objectAtIndex:0]);
//	return;
	
	if(0 == [selectedPlaylists count]) {
		[_streamArrayController remove:sender];
	}
	else {
		NSManagedObject			*streamObject;
		NSManagedObject			*playlistObject;
		NSMutableSet			*playlistSet;
		unsigned				i, j;

		for(i = 0; i < [selectedStreams count]; ++i) {
			streamObject	= [selectedStreams objectAtIndex:i];
			playlistSet		= [streamObject mutableSetValueForKey:@"playlists"];

			for(j = 0; j < [selectedPlaylists count]; ++j) {
				playlistObject	= [selectedPlaylists objectAtIndex:j];
				[playlistSet removeObject:playlistObject];
			}
		}
	}
}

- (IBAction) showStreamInformationSheet:(id)sender
{
	NSArray						*streams;

	streams						= [_streamArrayController selectedObjects];
	
	if(0 == [streams count]) {
		return;
	}
	else if(1 == [streams count]) {
		AudioStreamInformationSheet		*streamInformationSheet;

		streamInformationSheet			= [[AudioStreamInformationSheet alloc] init];
		
		[streamInformationSheet setValue:self forKey:@"owner"];

		[[streamInformationSheet valueForKey:@"streamObjectController"] setContent:[streams objectAtIndex:0]];
		
		[[NSApplication sharedApplication] beginSheet:[streamInformationSheet sheet] 
									   modalForWindow:[self windowForSheet] 
										modalDelegate:self 
									   didEndSelector:@selector(showStreamInformationSheetDidEnd:returnCode:contextInfo:) 
										  contextInfo:streamInformationSheet];
	}
	else {
		AudioMetadataEditingSheet	*metadataEditingSheet;

		metadataEditingSheet		= [[AudioMetadataEditingSheet alloc] init];
		
		[metadataEditingSheet setValue:self forKey:@"owner"];
		
		[[metadataEditingSheet valueForKey:@"streamArrayController"] addObjects:[_streamArrayController selectedObjects]];
		
		[[NSApplication sharedApplication] beginSheet:[metadataEditingSheet sheet] 
									   modalForWindow:[self windowForSheet] 
										modalDelegate:self 
									   didEndSelector:@selector(showMetadataEditingSheetDidEnd:returnCode:contextInfo:) 
										  contextInfo:metadataEditingSheet];
	}
}

#pragma mark File Addition

- (IBAction) addFiles:(id)sender
{
	NSOpenPanel		*panel		= [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:YES];
	[panel setCanChooseDirectories:YES];
	
	[panel beginSheetForDirectory:nil file:nil types:getAudioExtensions() modalForWindow:[self windowForSheet] modalDelegate:self didEndSelector:@selector(addFilesOpenPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}



- (void) addFileToLibrary:(NSString *)path
{
	[self addURLsToLibrary:[NSArray arrayWithObject:[NSURL fileURLWithPath:path]]];	
}

- (void) addURLToLibrary:(NSURL *)URL
{
	[self addURLsToLibrary:[NSArray arrayWithObject:URL]];
}

- (void) addFilesToLibrary:(NSArray *)filenames
{
	NSAutoreleasePool			*pool;
	NSFileManager				*manager;
	NSArray						*allowedTypes;
	NSString					*path;
	NSDirectoryEnumerator		*directoryEnumerator;
	NSString					*filename;
	BOOL						result, isDir;
	unsigned					i;
	
	pool						= [[NSAutoreleasePool alloc] init];
	
	// This should never be performed on the main thread to avoid blocking the UI
	if([self thread] == [NSThread currentThread]) {
		[NSThread detachNewThreadSelector:@selector(addFilesToLibrary:) toTarget:self withObject:filenames];
		[pool release];
		return;
	}	
	
	// We don't need a high priority for file addition
	result						= [NSThread setThreadPriority:0.4];
	if(NO == result) {
		NSLog(@"Unable to set the thread priority.");
	}

	manager						= [NSFileManager defaultManager];
	allowedTypes				= getAudioExtensions();
	
	for(i = 0; i < [filenames count]; ++i) {
		path					= [filenames objectAtIndex:i];
		
		result					= [manager fileExistsAtPath:path isDirectory:&isDir];
		NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to locate the input file.", @"Exceptions", @""));
		
		if(isDir) {
			directoryEnumerator		= [manager enumeratorAtPath:path];
			
			while((filename = [directoryEnumerator nextObject])) {
				if([allowedTypes containsObject:[filename pathExtension]]) {
					[self scheduleURLForAddition:[NSURL fileURLWithPath:[path stringByAppendingPathComponent:filename]]];
				}
			}
		}
		else {
			[self scheduleURLForAddition:[NSURL fileURLWithPath:path]];
		}
	}
	
	[pool release];
}

- (void) addURLsToLibrary:(NSArray *)URLs;
{
	NSAutoreleasePool			*pool;
	NSFileManager				*manager;
	NSArray						*allowedTypes;
	NSURL						*URL;
	NSString					*path;
	NSDirectoryEnumerator		*directoryEnumerator;
	NSString					*filename;
	BOOL						result, isDir;
	unsigned					i;
	
	pool						= [[NSAutoreleasePool alloc] init];

	// This should never be performed on the main thread to avoid blocking the UI
	if([self thread] == [NSThread currentThread]) {
		[NSThread detachNewThreadSelector:@selector(addURLsToLibrary:) toTarget:self withObject:URLs];		
		[pool release];
		return;
	}
	
	// We don't need a high priority for file addition
	result						= [NSThread setThreadPriority:0.4];
	if(NO == result) {
		NSLog(@"Unable to set the thread priority.");
	}
	
	manager						= [NSFileManager defaultManager];
	allowedTypes				= getAudioExtensions();
	
	for(i = 0; i < [URLs count]; ++i) {
		URL						= [URLs objectAtIndex:i];			
		path					= [URL path];
		
		result					= [manager fileExistsAtPath:path isDirectory:&isDir];
		NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to locate the input file.", @"Exceptions", @""));
		
		if(isDir) {
			directoryEnumerator		= [manager enumeratorAtPath:path];
			
			while((filename = [directoryEnumerator nextObject])) {
				if([allowedTypes containsObject:[filename pathExtension]]) {
					[self scheduleURLForAddition:[NSURL fileURLWithPath:[path stringByAppendingPathComponent:filename]]];
				}
			}
		}
		else {
			[self scheduleURLForAddition:URL];
		}
	}
	
	[pool release];
}

#pragma mark Playback Control

- (IBAction) play:(id)sender
{
	if(NO == [[self player] hasValidStream]) {
		if([self randomizePlayback]) {
			NSArray						*streams;
			NSManagedObject				*streamObject;	
			double						randomNumber;
			unsigned					randomIndex;
			
			streams						= [_streamArrayController arrangedObjects];
			randomNumber				= genrand_real2();
			randomIndex					= (unsigned)(randomNumber * [streams count]);
			streamObject				= [streams objectAtIndex:randomIndex];
			
			[self playStream:[NSArray arrayWithObject:streamObject]];
		}
		else {
			if(0 == [[_streamArrayController selectedObjects] count]) {
				[self playStream:[_streamArrayController arrangedObjects]];
			}
			else {
				[self playStream:[_streamArrayController selectedObjects]];
			}
		}
	}
	else {
		[[self player] play];
	}

	[self updatePlayButtonState];
}

- (IBAction) playPause:(id)sender
{
	if(NO == [[self player] hasValidStream]) {
		if([self randomizePlayback]) {
			NSArray						*streams;
			NSManagedObject				*streamObject;	
			double						randomNumber;
			unsigned					randomIndex;
			
			streams						= [_streamArrayController arrangedObjects];
			randomNumber				= genrand_real2();
			randomIndex					= (unsigned)(randomNumber * [streams count]);
			streamObject				= [streams objectAtIndex:randomIndex];
			
			[self playStream:[NSArray arrayWithObject:streamObject]];
		}
		else {
			if(0 == [[_streamArrayController selectedObjects] count]) {
				[self playStream:[_streamArrayController arrangedObjects]];
			}
			else {
				[self playStream:[_streamArrayController selectedObjects]];
			}
		}
	}
	else {
		[[self player] playPause];
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
	NSManagedObjectContext		*managedObjectContext;
	NSManagedObject				*libraryObject;
	NSManagedObject				*streamObject;
	NSError						*error;
	NSArray						*streams;
	unsigned					streamIndex;
	
	error						= nil;
	managedObjectContext		= [self managedObjectContext];
	libraryObject				= [self fetchLibraryObject];
	streamObject				= [libraryObject valueForKey:@"nowPlaying"];
	
	[libraryObject setValue:nil forKey:@"nowPlaying"];
	[streamObject setValue:[NSNumber numberWithBool:NO] forKey:@"isPlaying"];

	streams						= [_streamArrayController arrangedObjects];
	
	if(nil == streamObject || 0 == [streams count]) {
		[[self player] reset];
		[self updatePlayButtonState];
	}
	else if([self randomizePlayback]) {
		double						randomNumber;
		unsigned					randomIndex;
		
		randomNumber				= genrand_real2();
		randomIndex					= (unsigned)(randomNumber * [streams count]);
		streamObject				= [streams objectAtIndex:randomIndex];
		
		[self playStream:[NSArray arrayWithObject:streamObject]];
	}
	else if([self loopPlayback]) {
		streamIndex					= [streams indexOfObject:streamObject];
		
		if(streamIndex + 1 < [streams count]) {
			streamObject				= [streams objectAtIndex:streamIndex + 1];			
		}
		else {
			streamObject				= [streams objectAtIndex:0];
		}
		
		[self playStream:[NSArray arrayWithObject:streamObject]];
	}
	else {
		streamIndex					= [streams indexOfObject:streamObject];
		
		if(streamIndex + 1 < [streams count]) {
			streamObject			= [streams objectAtIndex:streamIndex + 1];
			
			[self playStream:[NSArray arrayWithObject:streamObject]];
		}
		else {
			[[self player] reset];
			[self updatePlayButtonState];
		}
	}
}

- (IBAction) playPreviousStream:(id)sender
{
	NSManagedObjectContext		*managedObjectContext;
	NSManagedObject				*libraryObject;
	NSManagedObject				*streamObject;
	NSError						*error;
	NSArray						*streams;
	unsigned					streamIndex;
	
	error						= nil;
	managedObjectContext		= [self managedObjectContext];
	libraryObject				= [self fetchLibraryObject];
	streamObject				= [libraryObject valueForKey:@"nowPlaying"];
	
	[libraryObject setValue:nil forKey:@"nowPlaying"];
	[streamObject setValue:[NSNumber numberWithBool:NO] forKey:@"isPlaying"];
	
	streams						= [_streamArrayController arrangedObjects];
	
	if(nil == streamObject || 0 == [streams count]) {
		[[self player] reset];	
	}
	else if([self randomizePlayback]) {
		double						randomNumber;
		unsigned					randomIndex;
		
		randomNumber				= genrand_real2();
		randomIndex					= (unsigned)(randomNumber * [streams count]);
		streamObject				= [streams objectAtIndex:randomIndex];
		
		[self playStream:[NSArray arrayWithObject:streamObject]];
	}
	else if([self loopPlayback]) {
		streamIndex					= [streams indexOfObject:streamObject];
		
		if(1 <= streamIndex) {
			streamObject				= [streams objectAtIndex:streamIndex - 1];
		}
		else {
			streamObject				= [streams objectAtIndex:[streams count] - 1];
		}
		
		[self playStream:[NSArray arrayWithObject:streamObject]];
	}
	else {
		streamIndex					= [streams indexOfObject:streamObject];
		
		if(1 <= streamIndex) {
			streamObject			= [streams objectAtIndex:streamIndex - 1];
			
			[self playStream:[NSArray arrayWithObject:streamObject]];
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
	NSManagedObjectContext		*managedObjectContext;
	NSManagedObject				*libraryObject;
	NSManagedObject				*streamObject;
	NSArray						*streams;
	unsigned					streamIndex;
	BOOL						result;
	
	managedObjectContext		= [self managedObjectContext];
	libraryObject				= [self fetchLibraryObject];
	streamObject				= [libraryObject valueForKey:@"nowPlaying"];
	streams						= [_streamArrayController arrangedObjects];
	
	if(nil == streamObject || 0 == [streams count]) {
		result					= NO;
	}
	else if([self randomizePlayback]) {
		result					= YES;
	}
	else if([self loopPlayback]) {
		result					= YES;
	}
	else {
		streamIndex				= [streams indexOfObject:streamObject];
		result					= (streamIndex + 1 < [streams count]);
	}
	
	return result;
}

- (BOOL) canPlayPreviousStream
{
	NSManagedObjectContext		*managedObjectContext;
	NSManagedObject				*libraryObject;
	NSManagedObject				*streamObject;
	NSArray						*streams;
	unsigned					streamIndex;
	BOOL						result;
	
	managedObjectContext		= [self managedObjectContext];
	libraryObject				= [self fetchLibraryObject];
	streamObject				= [libraryObject valueForKey:@"nowPlaying"];
	streams						= [_streamArrayController arrangedObjects];
	
	if(nil == streamObject || 0 == [streams count]) {
		result					= NO;
	}
	else if([self randomizePlayback]) {
		result					= YES;
	}
	else if([self loopPlayback]) {
		result					= YES;
	}
	else {
		streamIndex				= [streams indexOfObject:streamObject];
		result					= (1 <= streamIndex);
	}
	
	return result;
}

#pragma mark Callbacks

- (void) streamPlaybackDidStart:(NSURL *)url
{
	NSManagedObjectContext		*managedObjectContext;
	NSManagedObject				*libraryObject;
	NSManagedObject				*streamObject;
	NSError						*error;
	NSNumber					*playCount;
	NSNumber					*newPlayCount;
	
	error						= nil;
	managedObjectContext		= [self managedObjectContext];
	libraryObject				= [self fetchLibraryObject];
	streamObject				= [libraryObject valueForKey:@"nowPlaying"];
	playCount					= [streamObject valueForKey:@"playCount"];
	newPlayCount				= [NSNumber numberWithUnsignedInt:[playCount unsignedIntValue] + 1];
	
	[streamObject setValue:[NSNumber numberWithBool:NO] forKey:@"isPlaying"];
	[streamObject setValue:[NSDate date] forKey:@"lastPlayed"];
	[streamObject setValue:newPlayCount forKey:@"playCount"];
	
	if(nil == [streamObject valueForKey:@"firstPlayed"]) {
		[streamObject setValue:[NSDate date] forKey:@"firstPlayed"];
	}

	streamObject				= [self fetchStreamObjectForURL:url error:&error];

	if(nil != streamObject) {
		[libraryObject setValue:streamObject forKey:@"nowPlaying"];		
		[streamObject setValue:[NSNumber numberWithBool:YES] forKey:@"isPlaying"];
	}
}

- (void) streamPlaybackDidComplete
{
	NSManagedObjectContext		*managedObjectContext;
	NSManagedObject				*libraryObject;
	NSManagedObject				*streamObject;
	NSError						*error;
	NSNumber					*playCount;
	NSNumber					*newPlayCount;
		
	error						= nil;
	managedObjectContext		= [self managedObjectContext];
	libraryObject				= [self fetchLibraryObject];
	streamObject				= [libraryObject valueForKey:@"nowPlaying"];
	playCount					= [streamObject valueForKey:@"playCount"];
	newPlayCount				= [NSNumber numberWithUnsignedInt:[playCount unsignedIntValue] + 1];
	
	[streamObject setValue:[NSNumber numberWithBool:NO] forKey:@"isPlaying"];
	[streamObject setValue:[NSDate date] forKey:@"lastPlayed"];
	[streamObject setValue:newPlayCount forKey:@"playCount"];

	if(nil == [streamObject valueForKey:@"firstPlayed"]) {
		[streamObject setValue:[NSDate date] forKey:@"firstPlayed"];
	}
	
	[self playNextStream:self];
}

- (void) requestNextStream
{
	NSManagedObjectContext		*managedObjectContext;
	NSManagedObject				*libraryObject;
	NSManagedObject				*streamObject;
	NSError						*error;
	NSArray						*streams;
	unsigned					streamIndex;
	NSURL						*url;
	BOOL						result;
	
	error						= nil;
	managedObjectContext		= [self managedObjectContext];
	libraryObject				= [self fetchLibraryObject];
	streamObject				= [libraryObject valueForKey:@"nowPlaying"];
		
	streams						= [_streamArrayController arrangedObjects];
	
	if(nil == streamObject || 0 == [streams count]) {
		streamObject				= nil;
	}
	else if([self randomizePlayback]) {
		double						randomNumber;
		unsigned					randomIndex;
		
		randomNumber				= genrand_real2();
		randomIndex					= (unsigned)(randomNumber * [streams count]);
		streamObject				= [streams objectAtIndex:randomIndex];
	}
	else if([self loopPlayback]) {
		streamIndex					= [streams indexOfObject:streamObject];
		
		if(streamIndex + 1 < [streams count]) {
			streamObject				= [streams objectAtIndex:streamIndex + 1];			
		}
		else {
			streamObject				= [streams objectAtIndex:0];
		}
	}
	else {
		streamIndex					= [streams indexOfObject:streamObject];
		
		if(streamIndex + 1 < [streams count]) {
			streamObject			= [streams objectAtIndex:streamIndex + 1];
		}
		else {
			streamObject				= nil;
		}
	}
	
	if(nil != streamObject) {
		url									= [NSURL URLWithString:[streamObject valueForKey:@"url"]];
		result								= [[self player] setNextStreamURL:url error:&error];
		
		if(NO == result) {
			if(nil != error) {
				
			}
		}
	}
}

@end

@implementation LibraryDocument (NSTableViewDelegateMethods)

- (void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
	if([[aNotification object] isEqual:_playlistTableView]) {
		id							bindingTarget;
		NSString					*keyPath;
		NSDictionary				*bindingOptions;
		
		// When the selected Playlist changes, update the AudioStream Array Controller's bindings
		[_streamArrayController unbind:@"contentSet"];
		[_streamArrayController setContent:nil];
		
		if(0 == [[[_playlistArrayController selection] valueForKey:@"@count"] intValue]) {
			bindingTarget			= [self fetchLibraryObject];
			keyPath					= @"streams";
			bindingOptions			= [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:NSDeletesObjectsOnRemoveBindingsOption];
		}
		else {
			bindingTarget			= _playlistArrayController;
			keyPath					= @"selection.streams";
			bindingOptions			= nil;
		}
		
		[_streamArrayController bind:@"contentSet" toObject:bindingTarget withKeyPath:keyPath options:bindingOptions];
	}
	
	[self updatePlayButtonState];
}


- (void) tableViewColumnDidMove:(NSNotification *)aNotification
{
	if([[aNotification object] isEqual:_streamTableView]) {
		[self saveStreamTableColumnOrder];
	}
}

- (void) tableViewColumnDidResize:(NSNotification *)aNotification
{
	if([[aNotification object] isEqual:_streamTableView]) {
		NSMutableDictionary		*sizes;
		NSEnumerator			*enumerator;
		id column;

		sizes					= [NSMutableDictionary dictionary];
		enumerator				= [[_streamTableView tableColumns] objectEnumerator];
		
		while((column = [enumerator nextObject])) {
			[sizes setObject:[NSNumber numberWithFloat:[column width]] forKey:[column identifier]];
		}
		
		[[NSUserDefaults standardUserDefaults] setObject:sizes forKey:@"streamTableColumnSizes"];
	}
}

- (void) tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if([aTableView isEqual:_playlistTableView] && [[aTableColumn identifier] isEqualToString:@"name"]) {
		NSDictionary			*infoForBinding;
		
		infoForBinding			= [aTableView infoForBinding:NSContentBinding];
		
		if(nil != infoForBinding) {
			NSArrayController	*arrayController;
			NSManagedObject		*playlistObject;
			
			arrayController		= [infoForBinding objectForKey:NSObservedObjectKey];
			playlistObject		= [[arrayController arrangedObjects] objectAtIndex:rowIndex];
			
			[aCell setImage:[playlistObject valueForKey:@"image"]];
		}
	}
}

@end

@implementation LibraryDocument (Private)

- (AudioPlayer *) player
{
	return _player;
}

- (NSThread *) thread
{
	return _libraryThread;
}

- (NSManagedObject *) fetchLibraryObject
{
	NSManagedObjectContext		*managedObjectContext;
	NSEntityDescription			*libraryEntityDescription;
	NSManagedObject				*libraryObject;
	NSFetchRequest				*fetchRequest;
	NSError						*error;
	NSArray						*fetchResult;

	// Fetch the Library entity from the store
	managedObjectContext		= [self managedObjectContext];
	libraryEntityDescription	= [NSEntityDescription entityForName:@"Library" inManagedObjectContext:managedObjectContext];
	fetchRequest				= [[[NSFetchRequest alloc] init] autorelease];
	error						= nil;
	
	[fetchRequest setEntity:libraryEntityDescription];
	
	fetchResult					= [managedObjectContext executeFetchRequest:fetchRequest error:&error];
	
	if(nil == fetchResult) {
		BOOL					errorRecoveryDone;
		
		errorRecoveryDone		= [self presentError:error];
		return nil;
	}
	
	// There should always be one (and only one!) Library entity in the store
	NSAssert(1 == [fetchResult count], @"More than one Library entity returned!");
	
	libraryObject				= [fetchResult objectAtIndex:0];

	return [[libraryObject retain] autorelease];
}

- (NSManagedObject *) fetchStreamObjectForURL:(NSURL *)url error:(NSError **)error
{
	NSString					*absoluteURL;
	NSManagedObjectContext		*managedObjectContext;
	NSEntityDescription			*streamEntityDescription;
	NSFetchRequest				*fetchRequest;
	NSPredicate					*predicate;
	NSArray						*fetchResult;
	
	managedObjectContext		= [self managedObjectContext];
	
	// Convert the URL to a string for storage and comparison
	absoluteURL					= [url absoluteString];
	
	// ========================================
	// Verify that the requested AudioStream does not already exist in this Library, as identified by URL
	streamEntityDescription		= [NSEntityDescription entityForName:@"AudioStream" inManagedObjectContext:managedObjectContext];
	fetchRequest				= [[[NSFetchRequest alloc] init] autorelease];
	predicate					= [NSPredicate predicateWithFormat:@"url = %@", absoluteURL];
	
	[fetchRequest setEntity:streamEntityDescription];
	[fetchRequest setPredicate:predicate];
	
	fetchResult					= [managedObjectContext executeFetchRequest:fetchRequest error:error];
	
	return (nil != fetchResult && 0 < [fetchResult count] ? [fetchResult objectAtIndex:0] : nil);
}

- (void) playStream:(NSArray *)streams
{
	NSParameterAssert(nil != streams);
	
	NSManagedObjectContext		*managedObjectContext;
	NSManagedObject				*libraryObject;
	NSManagedObject				*streamObject;
	NSURL						*url;
	BOOL						result;
	NSError						*error;
	
	if(0 == [streams count]) {
		return;
	}
	
	[[self player] stop];
	
	error						= nil;
	managedObjectContext		= [self managedObjectContext];
	libraryObject				= [self fetchLibraryObject];
	streamObject				= [libraryObject valueForKey:@"nowPlaying"];
	
	if(nil != streamObject) {
		[streamObject setValue:[NSNumber numberWithBool:NO] forKey:@"isPlaying"];
		
		[libraryObject setValue:nil forKey:@"nowPlaying"];
	}
	
	streamObject				= [streams objectAtIndex:0];
	url							= [NSURL URLWithString:[streamObject valueForKey:@"url"]];
	result						= [[self player] setStreamURL:url error:&error];
	
	if(NO == result) {
		BOOL					errorRecoveryDone;
		
		errorRecoveryDone		= [self presentError:error];
		return;
	}
	
	[streamObject setValue:[NSNumber numberWithBool:YES] forKey:@"isPlaying"];
	
	[libraryObject setValue:streamObject forKey:@"nowPlaying"];
	
	[GrowlApplicationBridge notifyWithTitle:[streamObject valueForKeyPath:@"metadata.title"]
								description:[streamObject valueForKeyPath:@"metadata.artist"]
						   notificationName:@"Stream Playback Started" 
								   iconData:[streamObject valueForKeyPath:@"metadata.albumArt"] 
								   priority:0 
								   isSticky:NO 
							   clickContext:nil];
	
	if(nil == [streamObject valueForKeyPath:@"metadata.albumArt"]) {
		[_albumArtImageView setImage:[NSImage imageNamed:@"Play"]];
	}
	
	[[self player] play];
	
	[self updatePlayButtonState];
}

- (void) updatePlayButtonState
{
	NSString						*buttonImagePath, *buttonAlternateImagePath;
	NSImage							*buttonImage, *buttonAlternateImage;
	
	if([[self player] isPlaying]) {		
		buttonImagePath				= [[NSBundle mainBundle] pathForResource:@"player_play" ofType:@"png"];
		buttonAlternateImagePath	= [[NSBundle mainBundle] pathForResource:@"player_pause" ofType:@"png"];
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

		[self setPlayButtonEnabled:(0 != [[_streamArrayController arrangedObjects] count])];
	}
	else {
		buttonImagePath				= [[NSBundle mainBundle] pathForResource:@"player_pause" ofType:@"png"];
		buttonAlternateImagePath	= [[NSBundle mainBundle] pathForResource:@"player_play" ofType:@"png"];		
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
				   toObject:_streamArrayController
				withKeyPath:@"canInsert"
					options:nil];
	[_addStreamsButton setAction:@selector(addFiles:)];
	[_addStreamsButton setTarget:self];
	
	[_removeStreamsButton setToolTip:@"Remove the selected audio streams from the library"];
	[_removeStreamsButton bind:@"enabled"
					  toObject:_streamArrayController
				   withKeyPath:@"canRemove"
					   options:nil];
	[_removeStreamsButton setAction:@selector(removeAudioStreams:)];
	[_removeStreamsButton setTarget:self];

	[_streamInfoButton setToolTip:@"Show information on the selected streams"];
	[_streamInfoButton bind:@"enabled"
					 toObject:_streamArrayController
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
					toObject:_playlistArrayController
				 withKeyPath:@"canInsert"
					 options:nil];
	
	buttonMenu			= [[NSMenu alloc] init];
	
	buttonMenuItem		= [[NSMenuItem alloc] init];
	[buttonMenuItem setTitle:@"New Playlist"];
	//	[buttonMenuItem setImage:[NSImage imageNamed:@"StaticPlaylist"]];
	[buttonMenuItem setTarget:self];
	[buttonMenuItem setAction:@selector(insertStaticPlaylist:)];
	[buttonMenu addItem:buttonMenuItem];
	[buttonMenuItem bind:@"enabled"
				toObject:_playlistArrayController
			 withKeyPath:@"canInsert"
				 options:nil];
	[buttonMenuItem release];
	
	buttonMenuItem		= [[NSMenuItem alloc] init];
	[buttonMenuItem setTitle:@"New Playlist with Selection"];
	//	[buttonMenuItem setImage:[NSImage imageNamed:@"StaticPlaylist"]];
	[buttonMenuItem setTarget:self];
	[buttonMenuItem setAction:@selector(insertPlaylistWithSelectedStreams:)];
	[buttonMenu addItem:buttonMenuItem];
	[buttonMenuItem bind:@"enabled"
				toObject:_streamArrayController
			 withKeyPath:@"selectedObjects.@count"
				 options:nil];
	[buttonMenuItem release];
	
	buttonMenuItem		= [[NSMenuItem alloc] init];
	[buttonMenuItem setTitle:@"New Dynamic Playlist"];
	//	[buttonMenuItem setImage:[NSImage imageNamed:@"DynamicPlaylist"]];
	[buttonMenuItem setTarget:self];
	[buttonMenuItem setAction:@selector(insertDynamicPlaylist:)];
	[buttonMenu addItem:buttonMenuItem];
	[buttonMenuItem release];
	
	buttonMenuItem		= [[NSMenuItem alloc] init];
	[buttonMenuItem setTitle:@"New Folder Playlist"];
	//	[buttonMenuItem setImage:[NSImage imageNamed:@"FolderPlaylist"]];
	[buttonMenuItem setTarget:self];
	[buttonMenuItem setAction:@selector(insertFolderPlaylist:)];
	[buttonMenu addItem:buttonMenuItem];
	[buttonMenuItem release];
	
	[_addPlaylistButton setMenu:buttonMenu];
	[buttonMenu release];
	
	[_removePlaylistsButton setToolTip:@"Remove the selected playlists from the library"];
	[_removePlaylistsButton bind:@"enabled"
						toObject:_playlistArrayController
					 withKeyPath:@"canRemove"
						 options:nil];
	[_removePlaylistsButton setAction:@selector(remove:)];
	[_removePlaylistsButton setTarget:_playlistArrayController];
	
	[_playlistInfoButton setToolTip:@"Show information on the selected playlist"];
	[_playlistInfoButton bind:@"enabled"
						toObject:_playlistArrayController
					 withKeyPath:@"selectedObjects.@count"
						 options:nil];
	[_playlistInfoButton setAction:@selector(showPlaylistInformationSheet:)];
	[_playlistInfoButton setTarget:self];
}

- (void) setupStreamTableColumns
{
	NSDictionary	*visibleDictionary;
	NSDictionary	*sizesDictionary;
	NSArray			*orderArray, *tableColumns;
	NSEnumerator	*enumerator;
	id <NSMenuItem> contextMenuItem;	
	id				obj;
	int				menuIndex, i;

	// Setup stream table columns
	visibleDictionary					= [[NSUserDefaults standardUserDefaults] objectForKey:@"streamTableColumnVisibility"];
	sizesDictionary						= [[NSUserDefaults standardUserDefaults] objectForKey:@"streamTableColumnSizes"];
	orderArray							= [[NSUserDefaults standardUserDefaults] objectForKey:@"streamTableColumnOrder"];
	
	tableColumns						= [_streamTableView tableColumns];
	enumerator							= [tableColumns objectEnumerator];
	
	_streamTableVisibleColumns			= [[NSMutableSet alloc] init];
	_streamTableHiddenColumns			= [[NSMutableSet alloc] init];
	_streamTableHeaderContextMenu		= [[NSMenu alloc] initWithTitle:@"Stream Table Header Context Menu"];
	
	[[_streamTableView headerView] setMenu:_streamTableHeaderContextMenu];
	
	// Keep our changes from generating notifications to ourselves
	[_streamTableView setDelegate:nil];
	
	while((obj = [enumerator nextObject])) {
		menuIndex						= 0;
		
		while(menuIndex < [_streamTableHeaderContextMenu numberOfItems] 
			  && NSOrderedDescending == [[[obj headerCell] title] localizedCompare:[[_streamTableHeaderContextMenu itemAtIndex:menuIndex] title]]) {
			menuIndex++;
		}
		
		contextMenuItem					= [_streamTableHeaderContextMenu insertItemWithTitle:[[obj headerCell] title] action:@selector(streamTableHeaderContextMenuSelected:) keyEquivalent:@"" atIndex:menuIndex];
		
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
			[_streamTableView removeTableColumn:obj];
		}
	}
	
	i									= 0;
	enumerator							= [orderArray objectEnumerator];
	while((obj = [enumerator nextObject])) {
		[_streamTableView moveColumn:[_streamTableView columnWithIdentifier:obj] toColumn:i];
		++i;
	}
	
	[_streamTableView setDelegate:self];
}

- (void) setupPlaylistTable
{
	NSTableColumn	*tableColumn;
	NSCell			*dataCell;
	
	// Setup playlist table
	tableColumn							= [_playlistTableView tableColumnWithIdentifier:@"name"];
	dataCell							= [[ImageAndTextCell alloc] init];
	
	[tableColumn setDataCell:dataCell];
	[tableColumn bind:@"value" toObject:_playlistArrayController withKeyPath:@"arrangedObjects.name" options:nil];
	[dataCell release];	
}

- (void) addFilesOpenPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if(NSOKButton == returnCode) {
		[self addURLsToLibrary:[panel URLs]];
	}
}

- (void) showStreamInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	AudioStreamInformationSheet		*streamInformationSheet;
	
	streamInformationSheet			= (AudioStreamInformationSheet *)contextInfo;
	
	[sheet orderOut:self];
	
	if(NSOKButton == returnCode) {
		[_streamArrayController rearrangeObjects];			
	}
	else if(NSCancelButton == returnCode) {
	}
	
	[streamInformationSheet release];
}

- (void) showMetadataEditingSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	AudioMetadataEditingSheet		*metadataEditingSheet;
	
	metadataEditingSheet			= (AudioMetadataEditingSheet *)contextInfo;
	
	[sheet orderOut:self];
	
	if(NSOKButton == returnCode) {
		[_streamArrayController rearrangeObjects];			
	}
	else if(NSCancelButton == returnCode) {
	}
	
	[metadataEditingSheet release];
}

#pragma mark Stream Table Management

- (void) saveStreamTableColumnOrder
{
	NSMutableArray		*identifiers;
	NSEnumerator		*enumerator;
	id					obj;
	
	identifiers			= [NSMutableArray array];
	enumerator			= [[_streamTableView tableColumns] objectEnumerator];
	
	while((obj = [enumerator nextObject])) {
		[identifiers addObject:[obj identifier]];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:identifiers forKey:@"streamTableColumnOrder"];
	//	[[NSUserDefaults standardUserDefaults] synchronize];
}	

- (IBAction) streamTableHeaderContextMenuSelected:(id)sender
{
	NSMutableDictionary		*visibleDictionary;
	NSEnumerator			*enumerator;
	id						obj;
	
	if(NSOnState == [sender state]) {
		[sender setState:NSOffState];
		[_streamTableHiddenColumns addObject:[sender representedObject]];
		[_streamTableVisibleColumns removeObject:[sender representedObject]];
		[_streamTableView removeTableColumn:[sender representedObject]];
	}
	else {
		[sender setState:NSOnState];
		[_streamTableView addTableColumn:[sender representedObject]];
		[_streamTableVisibleColumns addObject:[sender representedObject]];
		[_streamTableHiddenColumns removeObject:[sender representedObject]];
	}
	
	visibleDictionary	= [NSMutableDictionary dictionary];
	enumerator			= [_streamTableVisibleColumns objectEnumerator];
	
	while((obj = [enumerator nextObject])) {
		[visibleDictionary setObject:[NSNumber numberWithBool:YES] forKey:[obj identifier]];
	}
	
	enumerator			= [_streamTableHiddenColumns objectEnumerator];
	while((obj = [enumerator nextObject])) {
		[visibleDictionary setObject:[NSNumber numberWithBool:NO] forKey:[obj identifier]];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:visibleDictionary forKey:@"streamTableColumnVisibility"];
	
	[self saveStreamTableColumnOrder];
}

#pragma mark File Addition

- (void) scheduleURLForAddition:(NSURL *)URL
{
	NSParameterAssert([URL isFileURL]);
	
	NSError						*error;
	AudioPropertiesReader		*propertiesReader;
	AudioMetadataReader			*metadataReader;
	NSDictionary				*callbackArguments;
	BOOL						result;
	
	// First read the properties
	error						= nil;
	propertiesReader			= [AudioPropertiesReader propertiesReaderForURL:URL error:&error];
	
	if(nil == propertiesReader) {
		[self performSelectorOnMainThread:@selector(presentError:) withObject:error waitUntilDone:NO];
		return;
	}
	
	result						= [propertiesReader readProperties:&error];
	
	if(NO == result) {
		[self performSelectorOnMainThread:@selector(presentError:) withObject:error waitUntilDone:NO];
		return;
	}
	
	// Now read the metadata
	metadataReader				= [AudioMetadataReader metadataReaderForURL:URL error:&error];
	
	if(nil == metadataReader) {		
		[self performSelectorOnMainThread:@selector(presentError:) withObject:error waitUntilDone:NO];
		return;
	}
	
	result						= [metadataReader readMetadata:&error];
	
	if(NO == result) {
		[self performSelectorOnMainThread:@selector(presentError:) withObject:error waitUntilDone:NO];
		return;
	}
	
	callbackArguments		= [NSDictionary dictionaryWithObjectsAndKeys:
		URL, @"url", 
		[propertiesReader valueForKey:@"properties"], @"properties", 
		[metadataReader valueForKey:@"metadata"], @"metadata", 
		nil]; 
	
	[self performSelectorOnMainThread:@selector(insertEntityForURL:) withObject:callbackArguments waitUntilDone:NO];
}

- (void) insertEntityForURL:(NSDictionary *)arguments
{
	NSURL						*URL;
	NSDictionary				*properties;
	NSDictionary				*metadata;
	NSString					*absoluteURL;
	NSManagedObject				*streamObject;
	NSManagedObjectContext		*managedObjectContext;
	NSManagedObject				*libraryObject;
	NSManagedObject				*propertiesObject;
	NSManagedObject				*metadataObject;
	NSError						*error;
	NSMutableSet				*playlistSet;
	BOOL						result;
	
	managedObjectContext		= [self managedObjectContext];
	URL							= [arguments valueForKey:@"url"];
	properties					= [arguments valueForKey:@"properties"];
	metadata					= [arguments valueForKey:@"metadata"];
	
	// Convert the URL to a string for storage and comparison
	absoluteURL					= [URL absoluteString];
	
	// ========================================
	// Verify that the requested AudioStream does not already exist in this Library
	error						= nil;
	streamObject				= [self fetchStreamObjectForURL:URL error:&error];
	
	if(nil == streamObject && nil != error) {
		result					= [self presentError:error];
		return;
	}
	
	// ========================================
	// If the AudioStream does exist in the Library, just add it to any playlists that are selected
	if(nil != streamObject) {
		playlistSet			= [streamObject mutableSetValueForKey:@"playlists"];
		[playlistSet addObjectsFromArray:[_playlistArrayController selectedObjects]];
		
		return;
	}
	
	// ========================================
	// Now that we know the AudioStream isn't in the Library, add it
	streamObject				= [NSEntityDescription insertNewObjectForEntityForName:@"AudioStream" inManagedObjectContext:managedObjectContext];
	
	// Fetch the Library entity from the store
	libraryObject				= [self fetchLibraryObject];
	
	// ========================================
	// Fill in properties and relationships
	[streamObject setValue:absoluteURL forKey:@"url"];
	[streamObject setValue:libraryObject forKey:@"library"];
	[streamObject setValue:[NSDate date] forKey:@"dateAdded"];
	
	playlistSet					= [streamObject mutableSetValueForKey:@"playlists"];
	[playlistSet addObjectsFromArray:[_playlistArrayController selectedObjects]];
	
	// ========================================
	// Set properties	
	propertiesObject				= [NSEntityDescription insertNewObjectForEntityForName:@"AudioProperties" inManagedObjectContext:managedObjectContext];
	
	[propertiesObject setValue:[properties valueForKey:@"bitrate"] forKey:@"bitrate"];
	[propertiesObject setValue:[properties valueForKey:@"bitsPerChannel"] forKey:@"bitsPerChannel"];
	[propertiesObject setValue:[properties valueForKey:@"channelsPerFrame"] forKey:@"channelsPerFrame"];
	[propertiesObject setValue:[properties valueForKey:@"duration"] forKey:@"duration"];
	[propertiesObject setValue:[properties valueForKey:@"formatName"] forKey:@"formatName"];
	//	[propertiesObject setValue:[properties valueForKey:@"isVBR"] forKey:@"isVBR"];
	[propertiesObject setValue:[properties valueForKey:@"sampleRate"] forKey:@"sampleRate"];
	[propertiesObject setValue:[properties valueForKey:@"totalFrames"] forKey:@"totalFrames"];
	
	[streamObject setValue:propertiesObject forKey:@"properties"];
	
	// ========================================
	// Set metadata
	metadataObject				= [NSEntityDescription insertNewObjectForEntityForName:@"AudioMetadata" inManagedObjectContext:managedObjectContext];
	
	[metadataObject setValue:[metadata valueForKey:@"albumArt"] forKey:@"albumArt"];
	[metadataObject setValue:[metadata valueForKey:@"albumArtist"] forKey:@"albumArtist"];
	[metadataObject setValue:[metadata valueForKey:@"albumTitle"] forKey:@"albumTitle"];
	[metadataObject setValue:[metadata valueForKey:@"artist"] forKey:@"artist"];
	[metadataObject setValue:[metadata valueForKey:@"comment"] forKey:@"comment"];
	[metadataObject setValue:[metadata valueForKey:@"composer"] forKey:@"composer"];
	[metadataObject setValue:[metadata valueForKey:@"date"] forKey:@"date"];
	[metadataObject setValue:[metadata valueForKey:@"discNumber"] forKey:@"discNumber"];
	[metadataObject setValue:[metadata valueForKey:@"discTotal"] forKey:@"discTotal"];
	[metadataObject setValue:[metadata valueForKey:@"genre"] forKey:@"genre"];
	[metadataObject setValue:[metadata valueForKey:@"isrc"] forKey:@"isrc"];
	[metadataObject setValue:[metadata valueForKey:@"mcn"] forKey:@"mcn"];
	[metadataObject setValue:[metadata valueForKey:@"partOfCompilation"] forKey:@"partOfCompilation"];
	[metadataObject setValue:[metadata valueForKey:@"title"] forKey:@"title"];
	[metadataObject setValue:[metadata valueForKey:@"trackNumber"] forKey:@"trackNumber"];
	[metadataObject setValue:[metadata valueForKey:@"trackTotal"] forKey:@"trackTotal"];
	
	[streamObject setValue:metadataObject forKey:@"metadata"];
	
	// If no metadata was found, set the title to the filename
	if(0 == [[metadata valueForKey:@"@count"] unsignedIntValue]) {
		[metadataObject setValue:[[[URL path] lastPathComponent] stringByDeletingPathExtension] forKey:@"title"];
	}
}

@end