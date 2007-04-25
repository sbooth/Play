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
#import "CollectionManager.h"
#import "AudioStreamManager.h"
#import "ServicesProvider.h"
#import "AudioLibrary.h"
#import "AudioScrobbler.h"
#import "AudioStream.h"
#import "AudioMetadataWriter.h"
#import "PreferencesController.h"
#import "PTHotKey.h"
#import "PTHotKeyCenter.h"
#import "PTKeyCombo.h"

@interface PlayApplicationDelegate (Private)
- (void) playbackDidStart:(NSNotification *)aNotification;
- (void) playbackDidStop:(NSNotification *)aNotification;
- (void) playbackDidPause:(NSNotification *)aNotification;
- (void) playbackDidResume:(NSNotification *)aNotification;
- (void) playbackDidComplete:(NSNotification *)aNotification;
- (void) streamDidChange:(NSNotification *)aNotification;
- (void) streamsDidChange:(NSNotification *)aNotification;
- (void) setWindowTitleForStream:(AudioStream *)stream;
@end

@implementation PlayApplicationDelegate

+ (void) initialize
{
	NSString *defaultsPath = [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"];
	if(nil == defaultsPath) {
		NSLog(@"Missing resource: Defaults.plist");
		return;
	}
	
	NSDictionary *initialValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:defaultsPath];		
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:initialValuesDictionary];
	[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:initialValuesDictionary];
}

- (AudioLibrary *) library
{
	return [AudioLibrary library];
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

	// Register hot keys
	NSDictionary *dictionary = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"playPauseHotKey"];
	if(nil != dictionary) {
		PTKeyCombo *keyCombo = [[PTKeyCombo alloc] initWithPlistRepresentation:dictionary];
		[self registerPlayPauseHotKey:keyCombo];
		[keyCombo release];
	}

	dictionary = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"nextStreamHotKey"];
	if(nil != dictionary) {
		PTKeyCombo *keyCombo = [[PTKeyCombo alloc] initWithPlistRepresentation:dictionary];
		[self registerPlayNextStreamHotKey:keyCombo];
		[keyCombo release];
	}
	
	dictionary = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"previousStreamHotKey"];
	if(nil != dictionary) {
		PTKeyCombo *keyCombo = [[PTKeyCombo alloc] initWithPlistRepresentation:dictionary];
		[self registerPlayPreviousStreamHotKey:keyCombo];
		[keyCombo release];
	}
}


- (void) applicationWillFinishLaunching:(NSNotification *)aNotification
{
	[[AudioLibrary library] showWindow:self];
	
	// Restore the play queue
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"rememberPlayQueue"]) {
		NSArray				*objectIDs		= [[NSUserDefaults standardUserDefaults] arrayForKey:@"savedPlayQueueStreams"];
		NSEnumerator		*enumerator		= [objectIDs objectEnumerator];
		NSNumber			*objectID		= nil;
		NSMutableArray		*streams		= [NSMutableArray array];
		
		while((objectID = [enumerator nextObject])) {
			[streams addObject:[[[CollectionManager manager] streamManager] streamForID:objectID]];
		}
		
		[[AudioLibrary library] addStreamsToPlayQueue:streams];
	}
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
											 selector:@selector(playbackDidComplete:) 
												 name:AudioStreamPlaybackDidCompleteNotification
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(streamDidChange:) 
												 name:AudioStreamDidChangeNotification
											   object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(streamsDidChange:) 
												 name:AudioStreamsDidChangeNotification
											   object:nil];
}

- (void) applicationWillTerminate:(NSNotification *)aNotification
{
	// Make sure AS receives the STOP command
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableAudioScrobbler"]) {
		[[self scrobbler] shutdown];
	}

	// Just unregister for all notifications
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// Save the play queue
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"rememberPlayQueue"]) {
		NSArray *objectIDs = [[AudioLibrary library] valueForKeyPath:[NSString stringWithFormat:@"%@.%@", PlayQueueKey, ObjectIDKey]];
		[[NSUserDefaults standardUserDefaults] setObject:objectIDs forKey:@"savedPlayQueueStreams"];
	}
}

- (void) application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
	BOOL success = [[AudioLibrary library] addFiles:filenames];
	if(success) {
		success = [[AudioLibrary library] playFiles:filenames];
	}
	
	[[NSApplication sharedApplication] replyToOpenOrPrint:(success ? NSApplicationDelegateReplySuccess : NSApplicationDelegateReplyFailure)];
}

- (IBAction) showPreferences:(id)sender
{
	[[PreferencesController sharedPreferences] showWindow:sender];
}

#pragma mark Hot Keys

- (void) registerPlayPauseHotKey:(PTKeyCombo *)keyCombo
{
	 [[PTHotKeyCenter sharedCenter] unregisterHotKey:[[PTHotKeyCenter sharedCenter] hotKeyWithIdentifier:@"playPause"]];
	 
	 PTHotKey *playPauseHotKey = [[PTHotKey alloc] initWithIdentifier:@"playPause" keyCombo:keyCombo];
	 
	 [playPauseHotKey setTarget:[AudioLibrary library]];
	 [playPauseHotKey setAction:@selector(playPause:)];
	 
	 [[PTHotKeyCenter sharedCenter] registerHotKey:playPauseHotKey];
	 [playPauseHotKey release];
}

- (void) registerPlayNextStreamHotKey:(PTKeyCombo *)keyCombo
{
	[[PTHotKeyCenter sharedCenter] unregisterHotKey:[[PTHotKeyCenter sharedCenter] hotKeyWithIdentifier:@"nextStream"]];
	
	PTHotKey *nextStreamHotKey = [[PTHotKey alloc] initWithIdentifier:@"nextStream" keyCombo:keyCombo];
	
	[nextStreamHotKey setTarget:[AudioLibrary library]];
	[nextStreamHotKey setAction:@selector(playNextStream:)];
	
	[[PTHotKeyCenter sharedCenter] registerHotKey:nextStreamHotKey];
	[nextStreamHotKey release];
}

- (void) registerPlayPreviousStreamHotKey:(PTKeyCombo *)keyCombo
{
	[[PTHotKeyCenter sharedCenter] unregisterHotKey:[[PTHotKeyCenter sharedCenter] hotKeyWithIdentifier:@"previousStream"]];
	
	PTHotKey *previousStreamHotKey = [[PTHotKey alloc] initWithIdentifier:@"previousStream" keyCombo:keyCombo];
	
	[previousStreamHotKey setTarget:[AudioLibrary library]];
	[previousStreamHotKey setAction:@selector(playPreviousStream:)];
	
	[[PTHotKeyCenter sharedCenter] registerHotKey:previousStreamHotKey];
	[previousStreamHotKey release];
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
	
	NSString *title		= [stream valueForKey:MetadataTitleKey];
	NSString *artist	= [stream valueForKey:MetadataArtistKey];

	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableGrowlNotifications"]) {

		NSString *notificationTitle			= (nil == title ? @"" : title);
		NSString *notificationDescription	= (nil == artist ? @"" : artist);
				
		[GrowlApplicationBridge notifyWithTitle:notificationTitle
									description:notificationDescription
							   notificationName:@"Stream Playback Started" 
									   iconData:nil/*[stream valueForKey:@"albumArt"]*/
									   priority:0 
									   isSticky:NO 
								   clickContext:[stream valueForKey:ObjectIDKey]];
	}
	
	[self setWindowTitleForStream:stream];
	
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

- (void) playbackDidComplete:(NSNotification *)aNotification
{
	// Reset window title to default
	[self setWindowTitleForStream:nil];
}

- (void) streamDidChange:(NSNotification *)aNotification
{
	AudioStream				*stream			= [[aNotification userInfo] objectForKey:AudioStreamObjectKey];
	NSError					*error			= nil;
	AudioMetadataWriter		*metadataWriter = [AudioMetadataWriter metadataWriterForURL:[stream valueForKey:StreamURLKey] error:&error];

	if([stream isPlaying]) {
		[self setWindowTitleForStream:stream];
	}

	if(nil != metadataWriter) {
		BOOL					result			= [metadataWriter writeMetadata:stream error:&error];
		NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to save metadata to file.", @"Errors", @""));
	}
}

- (void) streamsDidChange:(NSNotification *)aNotification
{
	NSArray					*streams		= [[aNotification userInfo] objectForKey:AudioStreamsObjectKey];
	NSEnumerator			*enumerator		= [streams objectEnumerator];
	AudioStream				*stream			= nil;
	NSError					*error			= nil;
	AudioMetadataWriter		*metadataWriter = nil;
	
	while((stream = [enumerator nextObject])) {
		error			= nil;
		metadataWriter	= [AudioMetadataWriter metadataWriterForURL:[stream valueForKey:StreamURLKey] error:&error];

		if([stream isPlaying]) {
			[self setWindowTitleForStream:stream];
		}
		
		if(nil != metadataWriter) {
			BOOL					result			= [metadataWriter writeMetadata:stream error:&error];
			NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to save metadata to file.", @"Errors", @""));
		}
	}
}

- (void) setWindowTitleForStream:(AudioStream *)stream
{
	NSString *title			= [stream valueForKey:MetadataTitleKey];
	NSString *artist		= [stream valueForKey:MetadataArtistKey];		
	NSString *windowTitle	= nil;
	
	if(nil != title && nil != artist) {
		windowTitle = [NSString stringWithFormat:@"%@ - %@", artist, title];
	}
	else if(nil != title) {
		windowTitle = title;
	}
	else if(nil != artist) {
		windowTitle = artist;
	}
	else {
		windowTitle = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	}
	
	[[[AudioLibrary library] window] setTitle:windowTitle];
}

@end
