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
#import "iScrobbler.h"
#import "AudioStream.h"
#import "AudioMetadataWriter.h"
#import "PreferencesController.h"
#import "PTHotKey.h"
#import "PTHotKeyCenter.h"
#import "PTKeyCombo.h"
#import "AppleRemote.h"
#import "IntegerToDoubleRoundingValueTransformer.h"

#import <SFBCrashReporter/SFBCrashReporter.h>

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
	[NSDateFormatter setDefaultFormatterBehavior:NSDateFormatterBehavior10_4];
	[NSNumberFormatter setDefaultFormatterBehavior:NSNumberFormatterBehavior10_4];
	
	IntegerToDoubleRoundingValueTransformer *rounder = [[IntegerToDoubleRoundingValueTransformer alloc] init];
	[NSValueTransformer setValueTransformer:rounder forName:@"IntegerToDoubleRoundingValueTransformer"];
	[rounder release];

	NSString *defaultsPath = [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"];
	if(nil != defaultsPath) {
		NSDictionary *initialValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:defaultsPath];		
		
		[[NSUserDefaults standardUserDefaults] registerDefaults:initialValuesDictionary];
		[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:initialValuesDictionary];
	}
	else
		NSLog(@"Missing file: Defaults.plist");
}

- (AudioLibrary *) library
{
	return [AudioLibrary library];
}

- (AudioScrobbler *) audioScrobbler
{
	@synchronized(self) {
		if(nil == _audioScrobbler)
			_audioScrobbler = [[AudioScrobbler alloc] init];
	}
	return _audioScrobbler;
}

- (iScrobbler *) iScrobbler
{
	@synchronized(self) {
		if(nil == _iScrobbler)
			_iScrobbler = [[iScrobbler alloc] init];
	}
	return _iScrobbler;
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

	dictionary = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"playNextStreamHotKey"];
	if(nil != dictionary) {
		PTKeyCombo *keyCombo = [[PTKeyCombo alloc] initWithPlistRepresentation:dictionary];
		[self registerPlayNextStreamHotKey:keyCombo];
		[keyCombo release];
	}
	
	dictionary = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"playPreviousStreamHotKey"];
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
		NSMutableArray		*streams		= [NSMutableArray array];
		AudioStream			*stream			= nil;
		
		for(NSNumber *objectID in objectIDs) {
			stream = [[[CollectionManager manager] streamManager] streamForID:objectID];
			if(nil != stream)
				[streams addObject:stream];
		}
		
		[[AudioLibrary library] addStreamsToPlayQueue:streams];
	}
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Register services
	[[NSApplication sharedApplication] setServicesProvider:[[[ServicesProvider alloc] init] autorelease]];

	// Start listening for remote control events
	_remoteControl = [[AppleRemote alloc] initWithDelegate:self];

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

	// Check for and send crash reports
	[SFBCrashReporter checkForNewCrashes];
}

- (void) applicationWillTerminate:(NSNotification *)aNotification
{
	// Make sure AS receives the STOP command
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableAudioScrobbler"])
		[[self audioScrobbler] shutdown];

//	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableiScrobbler"])
//		[[self iScrobbler] shutdown];

	// Just unregister for all notifications
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// Stop listening for remote control events
	[_remoteControl stopListening:aNotification];
	[_remoteControl release], _remoteControl = nil;
	
	// Save the play queue
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"rememberPlayQueue"]) {
		NSArray *objectIDs = [[AudioLibrary library] valueForKeyPath:[NSString stringWithFormat:@"%@.%@", PlayQueueKey, ObjectIDKey]];
		[[NSUserDefaults standardUserDefaults] setObject:objectIDs forKey:@"savedPlayQueueStreams"];
	}
	
	// Save player state
	[[AudioLibrary library] saveStateToDefaults];
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}

- (void) applicationWillBecomeActive:(NSNotification *)aNotification
{
	[_remoteControl startListening:self];
}

- (void) applicationWillResignActive:(NSNotification *)aNotification
{
	[_remoteControl stopListening:self];
}

- (void) application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
	BOOL success = [[AudioLibrary library] addFiles:filenames];
	if(success)
		success = [[AudioLibrary library] playFiles:filenames];
	
	[[NSApplication sharedApplication] replyToOpenOrPrint:(success ? NSApplicationDelegateReplySuccess : NSApplicationDelegateReplyFailure)];
}

- (BOOL) application:(NSApplication *)sender delegateHandlesKey:(NSString *)key
{
	return [key isEqualToString:@"library"];
}

- (IBAction) showPreferences:(id)sender
{
	[[PreferencesController sharedPreferences] showWindow:sender];
}

#pragma mark Growl

- (NSDictionary *) registrationDictionaryForGrowl
{
	NSDictionary	*registrationDictionary		= nil;
	NSArray			*defaultNotifications		= nil;
	NSArray			*allNotifications			= nil;
	
	defaultNotifications		= [NSArray arrayWithObject:@"Track Playback Started"];
	allNotifications			= [NSArray arrayWithObject:@"Track Playback Started"];
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

@end

@implementation PlayApplicationDelegate (HotKeyMethods)

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

@end

// These exist solely for the dock menu
@implementation PlayApplicationDelegate (LibraryWrapperMethods)

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if([menuItem action] == @selector(playPause:)) {
		[menuItem setTitle:([[AudioLibrary library] isPlaying] ? NSLocalizedStringFromTable(@"Pause", @"Menus", @"") : NSLocalizedStringFromTable(@"Play", @"Menus", @""))];
		return [[AudioLibrary library] playButtonEnabled];
	}
	else if([menuItem action] == @selector(playNextStream:))
		return [[AudioLibrary library] canPlayNextStream];
	else if([menuItem action] == @selector(playPreviousStream:))
		return [[AudioLibrary library] canPlayPreviousStream];
	
	return YES;
}

- (IBAction) playPause:(id)sender
{
	[[AudioLibrary library] playPause:sender];
}

- (IBAction) playNextStream:(id)sender
{
	[[AudioLibrary library] playNextStream:sender];
}

- (IBAction) playPreviousStream:(id)sender
{
	[[AudioLibrary library] playPreviousStream:sender];
}

@end

@implementation PlayApplicationDelegate (RemoteControlWrapperDelegateMethods)

- (void) sendRemoteButtonEvent:(RemoteControlEventIdentifier)event pressedDown:(BOOL)pressedDown remoteControl:(RemoteControl *)remoteControl
{
	switch(event) {
		case kRemoteButtonPlus:
			break;
			
		case kRemoteButtonMinus:
			break;
			
		case kRemoteButtonMenu:
			break;
			
		case kRemoteButtonPlay:
			[[self library] playPause:remoteControl];
			break;
			
		case kRemoteButtonRight:
			[[self library] playNextStream:remoteControl];
			break;
			
		case kRemoteButtonLeft:
			[[self library] playPreviousStream:remoteControl];
			break;

		default:
			break;

	}
}

@end

@implementation PlayApplicationDelegate (Private)

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
							   notificationName:@"Track Playback Started" 
									   iconData:nil/*[stream valueForKey:@"albumArt"]*/
									   priority:0 
									   isSticky:NO 
								   clickContext:[stream valueForKey:ObjectIDKey]];
	}
	
	[self setWindowTitleForStream:stream];
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableAudioScrobbler"])
		[[self audioScrobbler] start:stream];

	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableiScrobbler"])
		[[self iScrobbler] playbackDidStartForStream:stream];
}

- (void) playbackDidStop:(NSNotification *)aNotification
{
	AudioStream *stream = [[aNotification userInfo] objectForKey:AudioStreamObjectKey];

	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableAudioScrobbler"])
		[[self audioScrobbler] stop];

	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableiScrobbler"])
		[[self iScrobbler] playbackDidPauseForStream:stream];
	
	[self setWindowTitleForStream:nil];
}

- (void) playbackDidPause:(NSNotification *)aNotification
{
	AudioStream *stream = [[aNotification userInfo] objectForKey:AudioStreamObjectKey];

	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableAudioScrobbler"])
		[[self audioScrobbler] pause];

	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableiScrobbler"])
		[[self iScrobbler] playbackDidPauseForStream:stream];
}

- (void) playbackDidResume:(NSNotification *)aNotification
{
	AudioStream *stream = [[aNotification userInfo] objectForKey:AudioStreamObjectKey];

	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableAudioScrobbler"])
		[[self audioScrobbler] resume];

	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableiScrobbler"])
		[[self iScrobbler] playbackDidResumeForStream:stream];
}

- (void) playbackDidComplete:(NSNotification *)aNotification
{
	// Reset window title to default
	[self setWindowTitleForStream:nil];
}

- (void) streamDidChange:(NSNotification *)aNotification
{
	AudioStream *stream = [[aNotification userInfo] objectForKey:AudioStreamObjectKey];

	if([stream isPlaying])
		[self setWindowTitleForStream:stream];
}

- (void) streamsDidChange:(NSNotification *)aNotification
{
	for(AudioStream *stream in [[aNotification userInfo] objectForKey:AudioStreamsObjectKey]) {
		if([stream isPlaying])
			[self setWindowTitleForStream:stream];
	}
}

- (void) setWindowTitleForStream:(AudioStream *)stream
{
	NSURL		*url					= [stream valueForKey:StreamURLKey];
	NSString	*title					= [stream valueForKey:MetadataTitleKey];
	NSString	*artist					= [stream valueForKey:MetadataArtistKey];		
	NSString	*windowTitle			= nil;
	NSString	*representedFilename	= @"";
	
	if(nil != url && [url isFileURL])
		representedFilename = [url path];
	
	if(nil != title && nil != artist)
		windowTitle = [NSString stringWithFormat:@"%@ - %@", artist, title];
	else if(nil != title)
		windowTitle = title;
	else if(nil != artist)
		windowTitle = artist;
	else
		windowTitle = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	
	[[[AudioLibrary library] window] setTitle:windowTitle];
	[[[AudioLibrary library] window] setRepresentedFilename:representedFilename];
}

@end

#pragma mark Scripting

@implementation NSApplication (ScriptingAdditions)

- (void) handlePlayPauseScriptCommand:(NSScriptCommand *)command
{
	[[[self delegate] library] playPause:command];
}

- (void) handlePlayScriptCommand:(NSScriptCommand *)command
{
	[[[self delegate] library] play:command];
}

- (void) handleStopScriptCommand:(NSScriptCommand *)command
{
	[[[self delegate] library] stop:command];
}

- (void) handleSkipForwardScriptCommand:(NSScriptCommand *)command
{
	[[[self delegate] library] skipForward:command];
}

- (void) handleSkipBackwardScriptCommand:(NSScriptCommand *)command
{
	[[[self delegate] library] skipBackward:command];
}

- (void) handlePlayNextTrackScriptCommand:(NSScriptCommand *)command
{
	[[[self delegate] library] playNextStream:command];
}

- (void) handlePlayPreviousTrackScriptCommand:(NSScriptCommand *)command
{
	[[[self delegate] library] playPreviousStream:command];
}

- (void) handleEnqueueScriptCommand:(NSScriptCommand *)command
{
	id directParameter = [command directParameter];
	
	if([directParameter isKindOfClass:[NSArray class]]) {
		NSArray				*trackSpecifiers	= (NSArray *)directParameter;
		NSMutableArray		*tracksToAdd		= [NSMutableArray array];
		
		for(NSScriptObjectSpecifier *specifier in trackSpecifiers) {
			AudioStream *evaluatedObject = [specifier objectsByEvaluatingSpecifier];
			if(nil != evaluatedObject)
				[tracksToAdd addObject:evaluatedObject];
		}
		
		[[[self delegate] library] addStreamsToPlayQueue:tracksToAdd];
	}
	else
		[command setScriptErrorNumber:NSArgumentsWrongScriptError];
}

- (void) handleAddScriptCommand:(NSScriptCommand *)command
{
	id directParameter = [command directParameter];
	// for now, the "ToLocation" argument is ignored

	if([directParameter isKindOfClass:[NSString class]])
		[[[self delegate] library] addFile:directParameter];
	else if([directParameter isKindOfClass:[NSURL class]])
		[[[self delegate] library] addFile:[directParameter path]];
	else
		[command setScriptErrorNumber:NSArgumentsWrongScriptError];
}

@end
