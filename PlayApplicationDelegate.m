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

#import "PlayApplicationDelegate.h"
#import "LibraryDocument.h"
#import "UtilityFunctions.h"

#import "AudioStream.h"
#import "AudioMetadata.h"

@interface PlayApplicationDelegate (Private)
- (void) playbackDidStart:(NSNotification *)aNotification;
- (void) playbackDidStop:(NSNotification *)aNotification;
- (void) playbackDidPause:(NSNotification *)aNotification;
- (void) playbackDidResume:(NSNotification *)aNotification;
@end

@implementation PlayApplicationDelegate

- (AudioScrobbler *) scrobbler
{
	if(nil == _scrobbler) {
		_scrobbler = [[AudioScrobbler alloc] init];
	}
	return _scrobbler;
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSDocumentController		*documentController;
	NSArray						*recentDocumentURLs;

	// Register for applicable audio notifications
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(playbackDidStart:) 
												 name:AudioStreamPlaybackDidStartNotification
											   object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(playbackDidStop:) 
												 name:AudioStreamPlaybackDidStopNotification
											   object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(playbackDidPause:) 
												 name:AudioStreamPlaybackDidPauseNotification
											   object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(playbackDidResume:) 
												 name:AudioStreamPlaybackDidResumeNotification
											   object:nil];
	
	// Automatically re-open the last document opened
	documentController			= [NSDocumentController sharedDocumentController];
	recentDocumentURLs			= [documentController recentDocumentURLs];
	
	if(0 == [recentDocumentURLs count]) {
		[documentController newDocument:self];
	}
	else {
		NSURL					*documentURL;
		NSDocument				*document;
		NSError					*error;
		
		error					= nil;
		documentURL				= [recentDocumentURLs objectAtIndex:0];
		document				= [documentController openDocumentWithContentsOfURL:documentURL display:YES error:&error];

		if(nil == document) {
			BOOL				errorRecoveryDone;
			
			errorRecoveryDone	= [documentController presentError:error];
		}
	}
}

- (BOOL) applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	// Don't automatically create an untitled document
	return NO;
}

- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *)sender
{
	// Make sure AS receives the STOP command
	[[self scrobbler] shutdown];
	
	return NSTerminateNow;	
}

- (void) applicationWillTerminate:(NSNotification *)aNotification
{
	// Just unregister for all notifications
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL) application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	NSDocument					*document;
	NSDocumentController		*documentController;
	NSURL						*fileURL;
	NSError						*error;
	
	// First try to open the file as one of our document types
	error						= nil;
	fileURL						= [NSURL fileURLWithPath:filename];
	documentController			= [NSDocumentController sharedDocumentController];
	document					= [documentController openDocumentWithContentsOfURL:fileURL display:YES error:&error];
	
	if(nil != document) {
		return YES;
	}
	else if([getAudioExtensions() containsObject:[filename pathExtension]]) {
		document					= [documentController currentDocument];

		if(nil == document) {
			[documentController newDocument:self];
			document				= [documentController currentDocument];
		}

		if([document isKindOfClass:[LibraryDocument class]]) {
			[(LibraryDocument *)document addURLsToLibrary:[NSArray arrayWithObject:fileURL]];
		}

		return YES;
	}		
	
	return NO;
}

- (void) awakeFromNib
{
	[GrowlApplicationBridge setGrowlDelegate:self];
}

- (NSDictionary *) registrationDictionaryForGrowl
{
	NSDictionary				*registrationDictionary;
	NSArray						*defaultNotifications;
	NSArray						*allNotifications;
	
	defaultNotifications		= [NSArray arrayWithObjects:@"Stream Playback Started", nil];
	allNotifications			= [NSArray arrayWithObjects:@"Stream Playback Started", nil];
	registrationDictionary		= [NSDictionary dictionaryWithObjectsAndKeys:
		@"Play", GROWL_APP_NAME,  
		allNotifications, GROWL_NOTIFICATIONS_ALL, 
		defaultNotifications, GROWL_NOTIFICATIONS_DEFAULT,
		nil];
	
	return registrationDictionary;
}

#pragma mark Audio Notification Handling

- (void) playbackDidStart:(NSNotification *)aNotification
{
	AudioStream		*streamObject	= [[aNotification userInfo] objectForKey:AudioStreamObjectKey];
	
	[GrowlApplicationBridge notifyWithTitle:[[streamObject metadata] title]
								description:[[streamObject metadata] artist]
						   notificationName:@"Stream Playback Started" 
								   iconData:[[streamObject metadata] albumArt] 
								   priority:0 
								   isSticky:NO 
							   clickContext:nil];
	
	[[self scrobbler] start:streamObject];
}

- (void) playbackDidStop:(NSNotification *)aNotification
{
	[[self scrobbler] stop];
}

- (void) playbackDidPause:(NSNotification *)aNotification
{
	[[self scrobbler] pause];
}

- (void) playbackDidResume:(NSNotification *)aNotification
{
	[[self scrobbler] resume];
}

@end
