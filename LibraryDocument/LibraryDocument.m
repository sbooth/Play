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

#import "Library.h"
#import "AudioStream.h"

#import "AudioMetadata.h"

#import "StaticPlaylist.h"
#import "DynamicPlaylist.h"
#import "FolderPlaylist.h"

#import "AudioPropertiesReader.h"
#import "AudioMetadataReader.h"

#import "AudioStreamDecoder.h"

#import "AudioStreamInformationSheet.h"
#import "AudioMetadataEditingSheet.h"

#import "StaticPlaylistInformationSheet.h"
#import "DynamicPlaylistInformationSheet.h"
#import "FolderPlaylistInformationSheet.h"

#import "NewFolderPlaylistSheet.h"

#import "ImageAndTextCell.h"
#import "UtilityFunctions.h"

#include "mt19937ar.h"

#import <Growl/GrowlApplicationBridge.h>

@interface LibraryDocument (Private)

- (AudioPlayer *)			player;
- (NSThread *)				thread;
- (UKKQueue *)				kq;

- (Library *)				libraryObject;

- (void)					playStream:(NSArray *)streams;

- (void)					processFolderPlaylists:(id)arg;

- (void)					updatePlayButtonState;

- (void)					setupStreamButtons;
- (void)					setupPlaylistButtons;
- (void)					setupStreamTableColumns;
- (void)					setupPlaylistTable;

- (void)					addFilesOpenPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)					showStreamInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)					showMetadataEditingSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)					showStaticPlaylistInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)					showDynamicPlaylistInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)					showFolderPlaylistInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)					showNewFolderPlaylistSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)					saveStreamTableColumnOrder;
- (IBAction)				streamTableHeaderContextMenuSelected:(id)sender;

- (void)					scheduleURLForAddition:(NSURL *)URL;
- (void)					insertEntityForURL:(NSDictionary *)arguments;

-(void)						updateStreamsUnderURL:(NSURL *)URL;

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
		[NSNumber numberWithBool:NO], @"partOfCompilation",
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
		[NSNumber numberWithFloat:70], @"partOfCompilation",
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
		
		_kq = [[UKKQueue alloc] init];
		[_kq setDelegate:self];
		
		// Core Data does not populate our data until after init is called
		[self performSelector:@selector(processFolderPlaylists:) withObject:nil afterDelay:0.0];
		
		return self;
	}
	
	return nil;
}

- (id) initWithType:(NSString *)type error:(NSError **)error
{
    if((self = [super initWithType:type error:error])) {
		NSManagedObjectContext	*managedObjectContext;
		
		// Each LibraryDocument instance should contain one (and only one) Library entity
		managedObjectContext	= [self managedObjectContext];
		_libraryObject			= [NSEntityDescription insertNewObjectForEntityForName:@"Library" inManagedObjectContext:managedObjectContext];

		// Disable undo registration for the create
        [managedObjectContext processPendingChanges];
        [[managedObjectContext undoManager] removeAllActions];

        [self updateChangeCount:NSChangeCleared];

		[_libraryObject retain];
		
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
	[_kq release],								_kq = nil;
	[_libraryObject release],					_libraryObject = nil;
	
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
	else if([anItem action] == @selector(addFiles:)) {
		return [_streamArrayController canAdd];
	}
	else if([anItem action] == @selector(showStreamInformationSheet:)) {
		return (0 != [[_streamArrayController selectedObjects] count]);
	}
	else if([anItem action] == @selector(showPlaylistInformationSheet:)) {
		return (0 != [[_playlistArrayController selectedObjects] count]);
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
		return [_playlistArrayController canSelectNext];
	}
	else if([anItem action] == @selector(previousPlaylist:)) {
		return [_playlistArrayController canSelectPrevious];
	}
	else if([anItem action] == @selector(insertStaticPlaylist:)
			|| [anItem action] == @selector(insertDynamicPlaylist:)
			|| [anItem action] == @selector(insertFolderPlaylist:)) {
		return [_playlistArrayController canInsert];
	}
	else if([anItem action] == @selector(insertPlaylistWithSelectedStreams:)) {
		return (0 != [[_streamArrayController selectedObjects] count]);
	}
	else {
		return [super validateUserInterfaceItem:anItem];
	}
}

#pragma mark Action Methods

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

#pragma mark File Removal

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

- (void) removeFileFromLibrary:(NSString *)path
{
	[self removeURLsFromLibrary:[NSArray arrayWithObject:[NSURL fileURLWithPath:path]]];	
}

- (void) removeURLFromLibrary:(NSURL *)URL
{
	[self removeURLsFromLibrary:[NSArray arrayWithObject:URL]];
}

- (void) removeFilesFromLibrary:(NSArray *)filenames
{
	NSManagedObjectContext		*managedObjectContext;
	NSFetchRequest				*fetchRequest;
	NSArray						*fetchResults;
	NSError						*error;
	unsigned					i;
	NSMutableArray				*URLs;
	
	// Create an array of the string representations of the URLs to remove
	URLs						= [NSMutableArray array];
	
	for(i = 0; i < [filenames count]; ++i) {
		[URLs addObject:[[NSURL fileURLWithPath:[filenames objectAtIndex:i]] absoluteString]];
	}
	
	// Fetch AudioStreams for the URLs to be removed
	managedObjectContext		= [self managedObjectContext];
	fetchRequest				= [[[NSFetchRequest alloc] init] autorelease];
	error						= nil;
	
	[fetchRequest setEntity:[NSEntityDescription entityForName:@"AudioStream" inManagedObjectContext:managedObjectContext]];
	[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"url IN %@", URLs]];
	
	fetchResults				= [managedObjectContext executeFetchRequest:fetchRequest error:&error];
	
	if(nil == fetchResults) {
		if(nil != error) {
			[self presentError:error];
		}
		
		return;
	}
	
	// Now delete the requested objects
	for(i = 0; i < [fetchResults count]; ++i) {
		[managedObjectContext deleteObject:[fetchResults objectAtIndex:i]];
	}
}

- (void) removeURLsFromLibrary:(NSArray *)URLs
{
	NSManagedObjectContext		*managedObjectContext;
	NSFetchRequest				*fetchRequest;
	NSArray						*fetchResults;
	NSError						*error;
	unsigned					i;
	NSMutableArray				*URLStrings;
	
	// Create an array of the string representations of the URLs to remove
	URLStrings					= [NSMutableArray array];
	
	for(i = 0; i < [URLs count]; ++i) {
		[URLStrings addObject:[[URLs objectAtIndex:i] absoluteString]];
	}
	
	// Fetch AudioStreams for the URLs to be removed
	managedObjectContext		= [self managedObjectContext];
	fetchRequest				= [[[NSFetchRequest alloc] init] autorelease];
	error						= nil;
	
	[fetchRequest setEntity:[NSEntityDescription entityForName:@"AudioStream" inManagedObjectContext:managedObjectContext]];
	[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"url IN %@", URLStrings]];
	
	fetchResults				= [managedObjectContext executeFetchRequest:fetchRequest error:&error];
	
	if(nil == fetchResults) {
		if(nil != error) {
			[self presentError:error];
		}
		
		return;
	}

	// Now delete the requested objects
	for(i = 0; i < [fetchResults count]; ++i) {
		[managedObjectContext deleteObject:[fetchResults objectAtIndex:i]];
	}
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
	Library						*libraryObject;
	AudioStream					*streamObject;
	NSError						*error;
	NSArray						*streams;
	unsigned					streamIndex;
	
	error						= nil;
	managedObjectContext		= [self managedObjectContext];
	libraryObject				= [self libraryObject];
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
	Library						*libraryObject;
	NSManagedObject				*streamObject;
	NSError						*error;
	NSArray						*streams;
	unsigned					streamIndex;
	
	error						= nil;
	managedObjectContext		= [self managedObjectContext];
	libraryObject				= [self libraryObject];
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

#pragma mark Playlists

- (IBAction) insertStaticPlaylist:(id)sender;
{
	NSManagedObjectContext		*managedObjectContext;
	StaticPlaylist				*playlistObject;
	Library						*libraryObject;
	BOOL						selectionChanged;
	
	//	[_playlistDrawer open];
	
	managedObjectContext		= [self managedObjectContext];
	playlistObject				= [NSEntityDescription insertNewObjectForEntityForName:@"StaticPlaylist" inManagedObjectContext:managedObjectContext];
	libraryObject				= [self libraryObject];
	
	[playlistObject setLibrary:libraryObject];
	
	selectionChanged			= [_playlistArrayController setSelectedObjects:[NSArray arrayWithObject:playlistObject]];
	
	if(selectionChanged) {
		// The playlist table has only one column
		[_playlistTableView editColumn:0 row:[_playlistTableView selectedRow] withEvent:nil select:YES];	
	}
}

- (IBAction) insertDynamicPlaylist:(id)sender
{
	NSManagedObjectContext		*managedObjectContext;
	DynamicPlaylist				*playlistObject;
	Library						*libraryObject;
	BOOL						selectionChanged;

//	[_playlistDrawer open];

	managedObjectContext		= [self managedObjectContext];
	playlistObject				= [NSEntityDescription insertNewObjectForEntityForName:@"DynamicPlaylist" inManagedObjectContext:managedObjectContext];
	libraryObject				= [self libraryObject];

	[playlistObject setLibrary:libraryObject];

//	[playlistObject setPredicate:[NSPredicate predicateWithFormat:@"metadata.title LIKE[c] %@", @"*nat*"]];
//	[playlistObject setPredicate:[NSPredicate predicateWithFormat:@"%K CONTAINS[c] %@", @"metadata.title", @"nat"]];
//	[playlistObject setPredicate:[NSPredicate predicateWithFormat:@"url LIKE[c] %@", @"*nat*"]];
//	[playlistObject setPredicate:[NSPredicate predicateWithFormat:@"url CONTAINS[c] %@", @"nat"]];
//	[playlistObject setPredicate:[NSPredicate predicateWithFormat:@"playCount > 0"]];

	selectionChanged			= [_playlistArrayController setSelectedObjects:[NSArray arrayWithObject:playlistObject]];

	if(selectionChanged) {
		// The playlist table has only one column
//		[_playlistTableView editColumn:0 row:[_playlistTableView selectedRow] withEvent:nil select:YES];	
	}
}

- (IBAction) insertFolderPlaylist:(id)sender
{
	NewFolderPlaylistSheet		*newPlaylistSheet;
	
	newPlaylistSheet			= [[NewFolderPlaylistSheet alloc] initWithOwner:self];
		
	[[NSApplication sharedApplication] beginSheet:[newPlaylistSheet sheet] 
								   modalForWindow:[self windowForSheet] 
									modalDelegate:self 
								   didEndSelector:@selector(showNewFolderPlaylistSheetDidEnd:returnCode:contextInfo:) 
									  contextInfo:newPlaylistSheet];
}

- (IBAction) insertPlaylistWithSelectedStreams:(id)sender
{
	NSManagedObjectContext		*managedObjectContext;
	NSArray						*selectedStreams;
	StaticPlaylist				*playlistObject;
	Library						*libraryObject;
	NSMutableSet				*streamsSet;
	BOOL						selectionChanged;
	
	//	[_playlistDrawer open];
	
	managedObjectContext		= [self managedObjectContext];
	selectedStreams				= [_streamArrayController selectedObjects];
	playlistObject				= [NSEntityDescription insertNewObjectForEntityForName:@"StaticPlaylist" inManagedObjectContext:managedObjectContext];
	libraryObject				= [self libraryObject];
	
	[playlistObject setLibrary:libraryObject];
	
	streamsSet					= [playlistObject mutableSetValueForKey:@"streams"];
	
	[streamsSet addObjectsFromArray:selectedStreams];
	
	selectionChanged			= [_playlistArrayController setSelectedObjects:[NSArray arrayWithObject:playlistObject]];
	
	if(selectionChanged) {
		// The playlist table has only one column
		[_playlistTableView editColumn:0 row:[_playlistTableView selectedRow] withEvent:nil select:YES];	
	}
}

- (IBAction) nextPlaylist:(id)sender
{
	[_playlistArrayController selectNext:self];
}

- (IBAction) previousPlaylist:(id)sender
{
	[_playlistArrayController selectPrevious:self];
}

- (IBAction) showPlaylistInformationSheet:(id)sender
{
	NSArray						*playlists;
	
	playlists					= [_playlistArrayController selectedObjects];
	
	if(0 == [playlists count]) {
		return;
	}
	else if(1 == [playlists count]) {
		NSManagedObject			*playlist;
		
		playlist				= [playlists objectAtIndex:0];
		
		if([[[playlist entity] name] isEqualToString:@"StaticPlaylist"]) {
			StaticPlaylistInformationSheet	*playlistInformationSheet;
			
			playlistInformationSheet		= [[StaticPlaylistInformationSheet alloc] initWithOwner:self];
			
			[[playlistInformationSheet valueForKey:@"playlistObjectController"] setContent:playlist];
			
			[[NSApplication sharedApplication] beginSheet:[playlistInformationSheet sheet] 
										   modalForWindow:[self windowForSheet] 
											modalDelegate:self 
										   didEndSelector:@selector(showStaticPlaylistInformationSheetDidEnd:returnCode:contextInfo:) 
											  contextInfo:playlistInformationSheet];
		}
		else if([[[playlist entity] name] isEqualToString:@"DynamicPlaylist"]) {
			DynamicPlaylistInformationSheet	*playlistInformationSheet;
			
			playlistInformationSheet		= [[DynamicPlaylistInformationSheet alloc] initWithOwner:self];
			
			[[playlistInformationSheet valueForKey:@"playlistObjectController"] setContent:playlist];
			
			[[NSApplication sharedApplication] beginSheet:[playlistInformationSheet sheet] 
										   modalForWindow:[self windowForSheet] 
											modalDelegate:self 
										   didEndSelector:@selector(showDynamicPlaylistInformationSheetDidEnd:returnCode:contextInfo:) 
											  contextInfo:playlistInformationSheet];
		}
		else if([[[playlist entity] name] isEqualToString:@"FolderPlaylist"]) {
			FolderPlaylistInformationSheet	*playlistInformationSheet;
			
			playlistInformationSheet		= [[FolderPlaylistInformationSheet alloc] initWithOwner:self];
			
			[playlistInformationSheet setValue:self forKey:@"owner"];
			
			[[playlistInformationSheet valueForKey:@"playlistObjectController"] setContent:playlist];
			
			[[NSApplication sharedApplication] beginSheet:[playlistInformationSheet sheet] 
										   modalForWindow:[self windowForSheet] 
											modalDelegate:self 
										   didEndSelector:@selector(showDynamicPlaylistInformationSheetDidEnd:returnCode:contextInfo:) 
											  contextInfo:playlistInformationSheet];
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
	Library						*libraryObject;
	AudioStream					*streamObject;
	NSArray						*streams;
	unsigned					streamIndex;
	BOOL						result;
	
	managedObjectContext		= [self managedObjectContext];
	libraryObject				= [self libraryObject];
	streamObject				= [libraryObject nowPlaying];
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
	Library						*libraryObject;
	AudioStream					*streamObject;
	NSArray						*streams;
	unsigned					streamIndex;
	BOOL						result;
	
	managedObjectContext		= [self managedObjectContext];
	libraryObject				= [self libraryObject];
	streamObject				= [libraryObject nowPlaying];
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
	Library						*libraryObject;
	AudioStream					*streamObject;
	NSError						*error;
	NSNumber					*playCount;
	NSNumber					*newPlayCount;
	
	error						= nil;
	managedObjectContext		= [self managedObjectContext];
	libraryObject				= [self libraryObject];
	streamObject				= [libraryObject nowPlaying];
	playCount					= [streamObject playCount];
	newPlayCount				= [NSNumber numberWithUnsignedInt:[playCount unsignedIntValue] + 1];
	
	[streamObject setIsPlaying:[NSNumber numberWithBool:NO]];
	[streamObject setLastPlayed:[NSDate date]];
	[streamObject setPlayCount:newPlayCount];
	
	if(nil == [streamObject firstPlayed]) {
		[streamObject setFirstPlayed:[NSDate date]];
	}

	streamObject				= [libraryObject streamObjectForURL:url error:&error];

	if(nil != streamObject) {
		[libraryObject setNowPlaying:streamObject];
		[streamObject setIsPlaying:[NSNumber numberWithBool:YES]];
	}
}

- (void) streamPlaybackDidComplete
{
	NSManagedObjectContext		*managedObjectContext;
	Library						*libraryObject;
	AudioStream					*streamObject;
	NSError						*error;
	NSNumber					*playCount;
	NSNumber					*newPlayCount;
		
	error						= nil;
	managedObjectContext		= [self managedObjectContext];
	libraryObject				= [self libraryObject];
	streamObject				= [libraryObject nowPlaying];
	playCount					= [streamObject playCount];
	newPlayCount				= [NSNumber numberWithUnsignedInt:[playCount unsignedIntValue] + 1];
	
	[streamObject setIsPlaying:[NSNumber numberWithBool:NO]];
	[streamObject setLastPlayed:[NSDate date]];
	[streamObject setPlayCount:newPlayCount];

	if(nil == [streamObject firstPlayed]) {
		[streamObject setFirstPlayed:[NSDate date]];
	}
	
	[self playNextStream:self];
}

- (void) requestNextStream
{
	NSManagedObjectContext		*managedObjectContext;
	Library						*libraryObject;
	AudioStream					*streamObject;
	NSError						*error;
	NSArray						*streams;
	unsigned					streamIndex;
	NSURL						*url;
	BOOL						result;
	
	error						= nil;
	managedObjectContext		= [self managedObjectContext];
	libraryObject				= [self libraryObject];
	streamObject				= [libraryObject nowPlaying];
		
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
		url									= [NSURL URLWithString:[streamObject url]];
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
		
		if(0 == [[_playlistArrayController selectedObjects] count]) {
			bindingTarget			= [self libraryObject];
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
			Playlist			*playlistObject;
			
			arrayController		= [infoForBinding objectForKey:NSObservedObjectKey];
			playlistObject		= [[arrayController arrangedObjects] objectAtIndex:rowIndex];
			
			[aCell setImage:[playlistObject imageScaledToSize:NSMakeSize(16.0, 16.0)]];
		}
	}
	else if([aTableView isEqual:_streamTableView]) {
		NSDictionary			*infoForBinding;
		
		infoForBinding			= [aTableView infoForBinding:NSContentBinding];
		
		if(nil != infoForBinding) {
			NSArrayController	*arrayController;
			AudioStream			*streamObject;
			
			arrayController		= [infoForBinding objectForKey:NSObservedObjectKey];
			streamObject		= [[arrayController arrangedObjects] objectAtIndex:rowIndex];

			// Highlight the currently playing stream
			if([[streamObject isPlaying] boolValue]) {
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

@end

@implementation LibraryDocument (UKKQueueDelegateMethods)

-(void) watcher:(id<UKFileWatcher>)kq receivedNotification:(NSString*)nm forPath:(NSString*)fpath
{
	if(UKFileWatcherRenameNotification != nm
	   && UKFileWatcherWriteNotification != nm
	   && UKFileWatcherDeleteNotification != nm) {
		return;
	}
	
	[self updateStreamsUnderURL:[NSURL fileURLWithPath:fpath]];
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

- (UKKQueue *) kq
{
	return _kq;
}

- (Library *) libraryObject
{
	if(nil == _libraryObject) {
		NSManagedObjectContext		*managedObjectContext;
		NSEntityDescription			*libraryEntityDescription;
		NSFetchRequest				*fetchRequest;
		NSError						*error;
		NSArray						*fetchResult;
		
		// Fetch the Library entity from the store
		managedObjectContext		= [self managedObjectContext];
		libraryEntityDescription	= [NSEntityDescription entityForName:@"Library" inManagedObjectContext:managedObjectContext];
		fetchRequest				= [[NSFetchRequest alloc] init];
		error						= nil;
		
		[fetchRequest setEntity:libraryEntityDescription];
		
		fetchResult					= [managedObjectContext executeFetchRequest:fetchRequest error:&error];
		
		[fetchRequest release];
		
		if(nil == fetchResult) {
			BOOL					errorRecoveryDone;
			
			errorRecoveryDone		= [self presentError:error];
			return nil;
		}
		
		// There should always be one (and only one!) Library entity in the store
		NSAssert1(1 == [fetchResult count], @"Found %i Library entities!", [fetchResult count]);
		
		_libraryObject				= [[fetchResult lastObject] retain];		
	}
	
	return _libraryObject;
}

- (void) playStream:(NSArray *)streams
{
	NSParameterAssert(nil != streams);

	NSManagedObjectContext		*managedObjectContext;
	Library						*libraryObject;
	AudioStream					*streamObject;
	NSURL						*url;
	BOOL						result;
	NSError						*error;
	
	if(0 == [streams count]) {
		return;
	}
	
	[[self player] stop];
	
	error						= nil;
	managedObjectContext		= [self managedObjectContext];
	libraryObject				= [self libraryObject];
	streamObject				= [libraryObject nowPlaying];
	
	if(nil != streamObject) {
		[streamObject setIsPlaying:[NSNumber numberWithBool:NO]];
		
		[libraryObject setNowPlaying:nil];
	}
	
	streamObject				= [streams objectAtIndex:0];
	url							= [NSURL URLWithString:[streamObject valueForKey:@"url"]];
	result						= [[self player] setStreamURL:url error:&error];
	
	if(NO == result) {
		BOOL					errorRecoveryDone;
		
		errorRecoveryDone		= [self presentError:error];
		return;
	}
	
	[streamObject setIsPlaying:[NSNumber numberWithBool:YES]];

	[libraryObject setNowPlaying:streamObject];

	[GrowlApplicationBridge notifyWithTitle:[[streamObject metadata] title]
								description:[[streamObject metadata] artist]
						   notificationName:@"Stream Playback Started" 
								   iconData:[[streamObject metadata] albumArt] 
								   priority:0 
								   isSticky:NO 
							   clickContext:nil];
	
	if(nil == [[streamObject metadata] albumArt]) {
		[_albumArtImageView setImage:[NSImage imageNamed:@"Play"]];
	}
	
	[[self player] play];
	
	[self updatePlayButtonState];
}

- (void) processFolderPlaylists:(id)arg
{
	NSManagedObjectContext		*managedObjectContext;
	NSEntityDescription			*playlistEntityDescription;
	NSFetchRequest				*fetchRequest;
	NSArray						*fetchResult;
	NSError						*error;
	unsigned					i;
	FolderPlaylist				*playlist;
	
	managedObjectContext		= [self managedObjectContext];
	
	// ========================================
	// Fetch all folder playlists and start observing their paths
	error						= nil;
	playlistEntityDescription	= [NSEntityDescription entityForName:@"FolderPlaylist" inManagedObjectContext:managedObjectContext];
	fetchRequest				= [[[NSFetchRequest alloc] init] autorelease];
	
	[fetchRequest setEntity:playlistEntityDescription];
	
	fetchResult					= [managedObjectContext executeFetchRequest:fetchRequest error:&error];
	
	if(nil == fetchResult) {
		if(nil != error) {
			[self presentError:error];	
		}
		
		return;	
	}
	
	for(i = 0; i < [fetchResult count]; ++i) {
		playlist				= [fetchResult objectAtIndex:i];
		
		// Sync the library's streams with those actually on disk
		[self updateStreamsUnderURL:[NSURL URLWithString:[playlist url]]];
		
		[playlist setKq:[self kq]];
	}
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

#pragma mark Sheet Callbacks

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

- (void) showStaticPlaylistInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	StaticPlaylistInformationSheet	*playlistInformationSheet;
	
	playlistInformationSheet		= (StaticPlaylistInformationSheet *)contextInfo;
	
	[sheet orderOut:self];
	
	if(NSOKButton == returnCode) {
		[_playlistArrayController rearrangeObjects];			
	}
	else if(NSCancelButton == returnCode) {
	}
	
	[playlistInformationSheet release];
}

- (void) showDynamicPlaylistInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	DynamicPlaylistInformationSheet	*playlistInformationSheet;
	
	playlistInformationSheet		= (DynamicPlaylistInformationSheet *)contextInfo;
	
	[sheet orderOut:self];
	
	if(NSOKButton == returnCode) {
		[_playlistArrayController rearrangeObjects];			
	}
	else if(NSCancelButton == returnCode) {
	}
	
	[playlistInformationSheet release];
}

- (void) showFolderPlaylistInformationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	FolderPlaylistInformationSheet	*playlistInformationSheet;
	
	playlistInformationSheet		= (FolderPlaylistInformationSheet *)contextInfo;
	
	[sheet orderOut:self];
	
	if(NSOKButton == returnCode) {
		[_playlistArrayController rearrangeObjects];			
	}
	else if(NSCancelButton == returnCode) {
	}
	
	[playlistInformationSheet release];
}

- (void) showNewFolderPlaylistSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NewFolderPlaylistSheet			*newPlaylistSheet;

	newPlaylistSheet				= (NewFolderPlaylistSheet *)contextInfo;

	[sheet orderOut:self];
	
	if(NSOKButton == returnCode) {		
		id							newPlaylist;
		NSManagedObjectContext		*managedObjectContext;
		Library						*libraryObject;
		FolderPlaylist				*playlistObject;
		BOOL						selectionChanged;
		
		newPlaylist					= [[newPlaylistSheet valueForKey:@"playlistObjectController"] selection];
		managedObjectContext		= [self managedObjectContext];
		playlistObject				= [NSEntityDescription insertNewObjectForEntityForName:@"FolderPlaylist" inManagedObjectContext:managedObjectContext];
		libraryObject				= [self libraryObject];
		
		[playlistObject setLibrary:libraryObject];
		
		[playlistObject setName:[newPlaylist valueForKey:@"name"]];
		[playlistObject setUrl:[newPlaylist valueForKey:@"url"]];

		[self updateStreamsUnderURL:[NSURL URLWithString:[newPlaylist valueForKey:@"url"]]];

		[playlistObject setKq:[self kq]];
		
		selectionChanged			= [_playlistArrayController setSelectedObjects:[NSArray arrayWithObject:playlistObject]];
		
		if(selectionChanged) {
			[_playlistArrayController rearrangeObjects];
		}
	}
	else if(NSCancelButton == returnCode) {
	}
	
	[[newPlaylistSheet valueForKey:@"playlistObjectController"] setContent:nil];
	[[newPlaylistSheet managedObjectContext] reset];

	[newPlaylistSheet release];
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
	AudioStream					*streamObject;
	NSManagedObjectContext		*managedObjectContext;
	Library						*libraryObject;
	NSManagedObject				*propertiesObject;
	AudioMetadata				*metadataObject;
	unsigned					i;
	NSArray						*selectedPlaylists;
	Playlist					*playlistObject;
	NSError						*error;
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
	streamObject				= [[self libraryObject] streamObjectForURL:URL error:&error];
	
	if(nil == streamObject && nil != error) {
		result					= [self presentError:error];
		return;
	}
	
	// ========================================
	// If the AudioStream does exist in the Library, just add it to any playlists that are selected
	if(nil != streamObject) {
		selectedPlaylists		= [_playlistArrayController selectedObjects];

		for(i = 0; i < [selectedPlaylists count]; ++i) {
			playlistObject		= [selectedPlaylists objectAtIndex:i];
			
			if([[[playlistObject entity] name] isEqualToString:@"StaticPlaylist"]) {
				[streamObject addPlaylistsObject:(StaticPlaylist *)playlistObject];
			}
		}
		
		return;
	}
	
	// ========================================
	// Now that we know the AudioStream isn't in the Library, add it
	streamObject				= [NSEntityDescription insertNewObjectForEntityForName:@"AudioStream" inManagedObjectContext:managedObjectContext];
	
	// Fetch the Library entity from the store
	libraryObject				= [self libraryObject];
	
	// ========================================
	// Fill in properties and relationships
	[streamObject setUrl:absoluteURL];
	[streamObject setLibrary:libraryObject];
	
	selectedPlaylists			= [_playlistArrayController selectedObjects];
	
	for(i = 0; i < [selectedPlaylists count]; ++i) {
		playlistObject			= [selectedPlaylists objectAtIndex:i];
		
		if([[[playlistObject entity] name] isEqualToString:@"StaticPlaylist"]) {
			[streamObject addPlaylistsObject:(StaticPlaylist *)playlistObject];
		}
	}
	
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
	[metadataObject setAlbumArtist:[metadata valueForKey:@"albumArtist"]];
	[metadataObject setAlbumTitle:[metadata valueForKey:@"albumTitle"]];
	[metadataObject setArtist:[metadata valueForKey:@"artist"]];
	[metadataObject setComment:[metadata valueForKey:@"comment"]];
	[metadataObject setComposer:[metadata valueForKey:@"composer"]];
	[metadataObject setDate:[metadata valueForKey:@"date"]];
	[metadataObject setDiscNumber:[metadata valueForKey:@"discNumber"]];
	[metadataObject setDiscTotal:[metadata valueForKey:@"discTotal"]];
	[metadataObject setGenre:[metadata valueForKey:@"genre"]];
	[metadataObject setIsrc:[metadata valueForKey:@"isrc"]];
	[metadataObject setMcn:[metadata valueForKey:@"mcn"]];
	[metadataObject setPartOfCompilation:[metadata valueForKey:@"partOfCompilation"]];
	[metadataObject setTitle:[metadata valueForKey:@"title"]];
	[metadataObject setTrackNumber:[metadata valueForKey:@"trackNumber"]];
	[metadataObject setTrackTotal:[metadata valueForKey:@"trackTotal"]];
	
	[streamObject setMetadata:metadataObject];
	
	// If no metadata was found, set the title to the filename
	if(0 == [[metadata valueForKey:@"@count"] unsignedIntValue]) {
		[metadataObject setValue:[[[URL path] lastPathComponent] stringByDeletingPathExtension] forKey:@"title"];
	}
}

-(void) updateStreamsUnderURL:(NSURL *)URL
{
	NSManagedObjectContext		*managedObjectContext;
	NSFetchRequest				*fetchRequest;
	NSArray						*fetchResults;
	NSError						*error;
	NSMutableSet				*libraryStreams;
	NSMutableSet				*physicalStreams;
	NSMutableSet				*removedStreams;
	NSMutableSet				*addedStreams;
	NSFileManager				*manager;
	NSArray						*allowedTypes;
	NSMutableArray				*URLs;
	NSString					*path;
	NSDirectoryEnumerator		*directoryEnumerator;
	NSEnumerator				*enumerator;
	AudioStream					*stream;
	NSString					*filename;
	BOOL						result, isDir;
	
	// First fetch all AudioStreams that are in the directory that changed
	managedObjectContext		= [self managedObjectContext];
	fetchRequest				= [[[NSFetchRequest alloc] init] autorelease];
	error						= nil;
	
	[fetchRequest setEntity:[NSEntityDescription entityForName:@"AudioStream" inManagedObjectContext:managedObjectContext]];
	[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"url BEGINSWITH %@", [URL absoluteString]]];
	
	fetchResults				= [managedObjectContext executeFetchRequest:fetchRequest error:&error];
	
	if(nil == fetchResults) {
		if(nil != error) {
			[self presentError:error];
		}
		
		return;
	}
	
	libraryStreams				= [NSMutableSet set];
	
	enumerator = [fetchResults objectEnumerator];
	while((stream = [enumerator nextObject])) {
		[libraryStreams addObject:[NSURL URLWithString:[stream url]]];
	}
	
	// Now iterate through and see what is actually in the directory
	URLs						= [NSMutableArray array];
	manager						= [NSFileManager defaultManager];
	allowedTypes				= getAudioExtensions();
	path						= [URL path];
	
	result						= [manager fileExistsAtPath:path isDirectory:&isDir];
	
	if(NO == result || NO == isDir) {
		NSLog(@"Unable to locate folder \"%@\".", path);
		return;
	}
	
	directoryEnumerator			= [manager enumeratorAtPath:path];
	
	while((filename = [directoryEnumerator nextObject])) {
		if([allowedTypes containsObject:[filename pathExtension]]) {
			[URLs addObject:[NSURL fileURLWithPath:[path stringByAppendingPathComponent:filename]]];
		}
	}
	
	physicalStreams				= [NSMutableSet setWithArray:URLs];
	
	// Determine if any files were deleted
	removedStreams				= [NSMutableSet setWithSet:libraryStreams];
	[removedStreams minusSet:physicalStreams];
	
	// Determine if any files were added
	addedStreams				= [NSMutableSet setWithSet:physicalStreams];
	[addedStreams minusSet:libraryStreams];
	
	[self addURLsToLibrary:[addedStreams allObjects]];
	[self removeURLsFromLibrary:[removedStreams allObjects]];		
}

@end