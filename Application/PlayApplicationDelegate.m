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
#import "ServicesProvider.h"
#import "AudioLibrary.h"
#import "AudioScrobbler.h"
#import "AudioStream.h"
#import "AudioMetadataWriter.h"

@interface PlayApplicationDelegate (Private)
- (void) playbackDidStart:(NSNotification *)aNotification;
- (void) playbackDidStop:(NSNotification *)aNotification;
- (void) playbackDidPause:(NSNotification *)aNotification;
- (void) playbackDidResume:(NSNotification *)aNotification;
@end

@implementation PlayApplicationDelegate

+ (void) initialize
{
	NSDictionary *defaultsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:YES], @"enableAudioScrobbler",
		[NSNumber numberWithBool:YES], @"enableGrowlNotifications",
		nil];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDictionary];
}

- (AudioScrobbler *) scrobbler
{
	if(nil == _scrobbler) {
		_scrobbler = [[AudioScrobbler alloc] init];
	}
	return _scrobbler;
}

- (void) awakeFromNib
{
	[GrowlApplicationBridge setGrowlDelegate:self];
}


- (void) applicationWillFinishLaunching:(NSNotification *)aNotification
{
	[[AudioLibrary library] showWindow:self];
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Register services
	[[NSApplication sharedApplication] setServicesProvider:[[[ServicesProvider alloc] init] autorelease]];

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

	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(streamDidChange:) 
												 name:AudioStreamDidChangeNotification
											   object:nil];
}

- (void) applicationWillTerminate:(NSNotification *)aNotification
{
	// Make sure AS receives the STOP command
	[[self scrobbler] shutdown];

	// Just unregister for all notifications
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
	BOOL success = [[AudioLibrary library] addFiles:filenames];
	if(success) {
		success = [[AudioLibrary library] playFiles:filenames];
	}
	
	[[NSApplication sharedApplication] replyToOpenOrPrint:(success ? NSApplicationDelegateReplySuccess : NSApplicationDelegateReplyFailure)];
}

#pragma mark Growl

- (NSDictionary *) registrationDictionaryForGrowl
{
	NSDictionary	*registrationDictionary		= nil;
	NSArray			*defaultNotifications		= nil;
	NSArray			*allNotifications			= nil;
	
	defaultNotifications		= [NSArray arrayWithObjects:@"Stream Playback Started", nil];
	allNotifications			= [NSArray arrayWithObjects:@"Stream Playback Started", nil];
	registrationDictionary		= [NSDictionary dictionaryWithObjectsAndKeys:
		@"Play", GROWL_APP_NAME,  
		allNotifications, GROWL_NOTIFICATIONS_ALL, 
		defaultNotifications, GROWL_NOTIFICATIONS_DEFAULT,
		nil];
	
	return registrationDictionary;
}

- (void) growlNotificationWasClicked:(id)clickContext
{
	[[AudioLibrary library] jumpToNowPlaying:self];
}

#pragma mark Audio Notification Handling

- (void) playbackDidStart:(NSNotification *)aNotification
{
	AudioStream *stream = [[aNotification userInfo] objectForKey:AudioStreamObjectKey];
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableGrowlNotifications"]) {
		[GrowlApplicationBridge notifyWithTitle:[stream valueForKey:MetadataTitleKey]
									description:[stream valueForKey:MetadataAlbumTitleKey]
							   notificationName:@"Stream Playback Started" 
									   iconData:[stream valueForKey:@"albumArt"]
									   priority:0 
									   isSticky:NO 
								   clickContext:[stream valueForKey:ObjectIDKey]];
	}
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableAudioScrobbler"]) {
		[[self scrobbler] start:stream];
	}
}

- (void) playbackDidStop:(NSNotification *)aNotification
{
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableAudioScrobbler"]) {
		[[self scrobbler] stop];
	}
}

- (void) playbackDidPause:(NSNotification *)aNotification
{
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableAudioScrobbler"]) {
		[[self scrobbler] pause];
	}
}

- (void) playbackDidResume:(NSNotification *)aNotification
{
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableAudioScrobbler"]) {
		[[self scrobbler] resume];
	}
}

- (void) streamDidChange:(NSNotification *)aNotification
{
	AudioStream *stream = [[aNotification userInfo] objectForKey:AudioStreamObjectKey];
	
	NSError					*error			= nil;
	AudioMetadataWriter		*metadataWriter = [AudioMetadataWriter metadataWriterForURL:[stream valueForKey:StreamURLKey] error:&error];

	if(nil != metadataWriter) {
		BOOL					result			= [metadataWriter writeMetadata:stream error:&error];
		NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to save metadata to file.", @"Errors", @""));
	}
}

@end
