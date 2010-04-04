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

#import "AudioPlayer.h"
#import "AudioScheduler.h"
#import "ScheduledAudioRegion.h"
#import "AudioLibrary.h"
#import "AudioStream.h"

#include <CoreServices/CoreServices.h>
#include <CoreAudio/CoreAudio.h>

// ========================================
// Utility functions
// ========================================
static BOOL
channelLayoutsAreEqual(AudioChannelLayout *layoutA,
					   AudioChannelLayout *layoutB)
{
	// First check if the tags are equal
	if(layoutA->mChannelLayoutTag != layoutB->mChannelLayoutTag)
		return NO;
	
	// If the tags are equal, check for special values
	if(kAudioChannelLayoutTag_UseChannelBitmap == layoutA->mChannelLayoutTag)
		return (layoutA->mChannelBitmap == layoutB->mChannelBitmap);

	if(kAudioChannelLayoutTag_UseChannelDescriptions == layoutA->mChannelLayoutTag) {
		if(layoutA->mNumberChannelDescriptions != layoutB->mNumberChannelDescriptions)
			return NO;
		
		unsigned bytesToCompare = layoutA->mNumberChannelDescriptions * sizeof(AudioChannelDescription);
		return (0 == memcmp(&layoutA->mChannelDescriptions, &layoutB->mChannelDescriptions, bytesToCompare));
	}
	
	return YES;
}

// ========================================
// Constants
// ========================================
NSString * const	AUTypeKey								= @"componentType";
NSString * const	AUSubTypeKey							= @"componentSubType";
NSString * const	AUManufacturerKey						= @"componentManufacturer";
NSString * const	AUNameStringKey							= @"name";
NSString * const	AUManufacturerStringKey					= @"manufacturer";
NSString * const	AUNameAndManufacturerStringKey			= @"nameAndManufacturer";
NSString * const	AUInformationStringKey					= @"information";
NSString * const	AUIconKey								= @"icon";
NSString * const	AUClassDataKey							= @"classData";
NSString * const	AUNodeKey								= @"AUNode";

NSString *const		AudioPlayerErrorDomain					= @"org.sbooth.Play.ErrorDomain.AudioPlayer";

// ========================================
// AUGraph manipulation
// ========================================
@interface AudioPlayer (AUGraphMethods)
- (AUGraph) auGraph;
- (OSStatus) setupAUGraph;
- (OSStatus) teardownAUGraph;
- (OSStatus) resetAUGraph;
- (OSStatus) startAUGraph;
- (OSStatus) stopAUGraph;
- (OSStatus) getAUGraphLatency:(Float64 *)graphLatency;
- (OSStatus) getAUGraphTailTime:(Float64 *)graphTailTime;
- (OSStatus) setAUGraphFormat:(AudioStreamBasicDescription)format;
- (OSStatus) setAUGraphChannelLayout:(AudioChannelLayout)channelLayout;
- (OSStatus) setPropertyOnAUGraphNodes:(AudioUnitPropertyID)propertyID data:(const void *)propertyData dataSize:(UInt32)propertyDataSize;
- (AUNode) limiterNode;
- (AUNode) outputNode;
- (void) saveEffectsToDefaults;
- (void) restoreEffectsFromDefaults;
@end

// ========================================
// Private methods
// ========================================
@interface AudioPlayer (Private)
- (AudioScheduler *) scheduler;

- (BOOL) canPlay;
- (void) uiTimerFireMethod:(NSTimer *)theTimer;

- (NSRunLoop *) runLoop;

- (void) setPlaying:(BOOL)playing;

// Accessor is public
- (void) setTotalFrames:(SInt64)totalFrames;

- (SInt64) startingFrame;
- (void) setStartingFrame:(SInt64)startingFrame;

- (SInt64) playingFrame;
- (void) setPlayingFrame:(SInt64)playingFrame;

- (void) setOutputDeviceUID:(NSString *)deviceUID;
- (OSStatus) setOutputDeviceSampleRate:(Float64)sampleRate;

- (BOOL) outputDeviceIsHogged;
- (OSStatus) startHoggingOutputDevice;
- (OSStatus) stopHoggingOutputDevice;

- (OSStatus) startListeningForSampleRateChangesOnOutputDevice;
- (OSStatus) stopListeningForSampleRateChangesOnOutputDevice;
- (void) outputDeviceSampleRateChanged;

- (void) setHasReplayGain:(BOOL)hasReplayGain;
- (void) setReplayGain:(float)replayGain;

- (void) prepareToPlayStream:(AudioStream *)stream;
- (NSNumber *) setReplayGainForStream:(AudioStream *)stream;

- (void) setFormat:(AudioStreamBasicDescription)format;
- (void) setChannelLayout:(AudioChannelLayout)channelLayout;
@end

// ========================================
// AUEventListener callbacks
// ========================================
static void 
myAUEventListenerProc(void						*inCallbackRefCon,
					  void						*inObject,
					  const AudioUnitEvent		*inEvent,
					  UInt64					inEventHostTime,
					  Float32					inParameterValue)
{
//	AudioPlayer *myself = (AudioPlayer *)inCallbackRefCon;
	
	if(kAudioUnitEvent_ParameterValueChange == inEvent->mEventType) {
	}
}

// ========================================
// AudioDevicePropertyListener callbacks
// ========================================
static OSStatus
myAudioDevicePropertyListenerProc( AudioDeviceID           inDevice,
								   UInt32                  inChannel,
								   Boolean                 isInput,
								   AudioDevicePropertyID   inPropertyID,
								   void*                   inClientData)
{
	AudioPlayer *myself = (AudioPlayer *)inClientData;
	
	if(kAudioDevicePropertyNominalSampleRate == inPropertyID)
		[myself outputDeviceSampleRateChanged];

	return noErr;
}

@implementation AudioPlayer

+ (void) initialize
{
	[self exposeBinding:@"volume"];
	[self exposeBinding:@"currentFrame"];
	[self exposeBinding:@"totalFrames"];
	[self exposeBinding:@"hasValidStream"];
	[self exposeBinding:@"streamSupportsSeeking"];
	
	[self setKeys:[NSArray arrayWithObject:@"hasValidStream"] triggerChangeNotificationsForDependentKey:@"streamSupportsSeeking"];

	[self setKeys:[NSArray arrayWithObject:@"hasValidStream"] triggerChangeNotificationsForDependentKey:@"currentFrame"];
	[self setKeys:[NSArray arrayWithObject:@"hasValidStream"] triggerChangeNotificationsForDependentKey:@"totalFrames"];

	[self setKeys:[NSArray arrayWithObject:@"currentFrame"] triggerChangeNotificationsForDependentKey:@"currentSecond"];
	[self setKeys:[NSArray arrayWithObject:@"currentFrame"] triggerChangeNotificationsForDependentKey:@"secondsRemaining"];
	[self setKeys:[NSArray arrayWithObject:@"totalFrames"] triggerChangeNotificationsForDependentKey:@"totalSeconds"];
}

- (id) init
{
	if((self = [super init])) {
		_runLoop = [[NSRunLoop currentRunLoop] retain];
		
		OSStatus err = AUEventListenerCreate(myAUEventListenerProc, self,
											 CFRunLoopGetCurrent(), kCFRunLoopDefaultMode,
											 0.1, 0.1,
											 &_auEventListener);
		if(noErr != err) {
			[self release];
			return nil;
		}		
		
		[self setupAUGraph];

		_scheduler = [[AudioScheduler alloc] init];
		[_scheduler setAudioUnit:_generatorUnit];
		[_scheduler setDelegate:self];
		
		// Set up a timer to update the UI 4 times per second
		_timer = [NSTimer timerWithTimeInterval:0.25 target:self selector:@selector(uiTimerFireMethod:) userInfo:nil repeats:YES];
		
		// Add to all three run loop modes to ensure playback progress is always displayed
		[_runLoop addTimer:_timer forMode:NSDefaultRunLoopMode];
		[_runLoop addTimer:_timer forMode:NSModalPanelRunLoopMode];
//		[_runLoop addTimer:_timer forMode:NSEventTrackingRunLoopMode];

		// Set the output device
		[self setOutputDeviceUID:[[NSUserDefaults standardUserDefaults] objectForKey:@"outputAudioDeviceUID"]];

		// Listen for changes to the output device
		[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self 
																  forKeyPath:@"values.outputAudioDeviceUID"
																	 options:0
																	 context:NULL];		
	}
	return self;
}

- (void) dealloc
{
	[_timer invalidate], _timer = nil;

	if([self outputDeviceIsHogged])
		[self stopHoggingOutputDevice];
	
	OSStatus err = AUListenerDispose(_auEventListener);
	if(noErr != err)
		NSLog(@"AudioPlayer: AUListenerDispose failed: %i", err);

	[[self scheduler] stopScheduling];
	[self teardownAUGraph];

	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self 
																 forKeyPath:@"values.outputAudioDeviceUID"];
		
	[_runLoop release], _runLoop = nil;
	[_scheduler release], _scheduler = nil;
	
	[super dealloc];
}

- (AudioLibrary *)		owner									{ return [[_owner retain] autorelease]; }
- (void)				setOwner:(AudioLibrary *)owner			{ [_owner release], _owner = [owner retain]; }

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if(object == [NSUserDefaultsController sharedUserDefaultsController] && [keyPath isEqualToString:@"values.outputAudioDeviceUID"])
		[self setOutputDeviceUID:[[NSUserDefaults standardUserDefaults] objectForKey:@"outputAudioDeviceUID"]];
}

#pragma mark Stream Management

- (BOOL) setStream:(AudioStream *)stream error:(NSError **)error
{
	NSParameterAssert(nil != stream);
	
	[[self scheduler] stopScheduling];
	[[self scheduler] clear];

	[self stopAUGraph];
	[self setPlaying:NO];
	
	_regionStartingFrame = 0;		

	OSStatus err = [self resetAUGraph];
	if(noErr != err)
		NSLog(@"AudioPlayer error: Unable to reset AUGraph AudioUnits: %i", err);
	
	id <AudioDecoderMethods> decoder = [stream decoder:error];
	if(nil == decoder)
		return NO;

	AudioStreamBasicDescription		format				= [self format];
	AudioStreamBasicDescription		newFormat			= [decoder format];
	
	AudioChannelLayout				channelLayout		= [self channelLayout];
	AudioChannelLayout				newChannelLayout	= [decoder channelLayout];

	// If the sample rate or number of channels changed, change the AU formats
	if(newFormat.mSampleRate != format.mSampleRate || newFormat.mChannelsPerFrame != format.mChannelsPerFrame) {
		OSStatus err = [self setAUGraphFormat:newFormat];
		if(noErr == err) {
			[self setFormat:newFormat];
			
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"automaticallySetOutputDeviceSampleRate"])
				[self setOutputDeviceSampleRate:newFormat.mSampleRate];
		}
		else {
			if(nil != error) {
				NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
				NSString				*path				= [[stream valueForKey:StreamURLKey] path];
				
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The format of the file \"%@\" is not supported.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"File Format Not Supported", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"The current DSP effects may not support this track's sample rate or channel layout.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
				
				*error = [NSError errorWithDomain:AudioPlayerErrorDomain 
											 code:AudioPlayerInternalError 
										 userInfo:errorDictionary];
			}
			
			return NO;
		}
	}

	// Update the AUGraph
	if(NO == channelLayoutsAreEqual(&newChannelLayout, &channelLayout)) {
		OSStatus err = [self setAUGraphChannelLayout:newChannelLayout];
		if(noErr == err)
			[self setChannelLayout:newChannelLayout];
		else {
			if(nil != error) {
				NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
				NSString				*path				= [[stream valueForKey:StreamURLKey] path];
				
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The format of the file \"%@\" is not supported.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"File Format Not Supported", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"The current DSP effects may not support this track's sample rate or channel layout.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
				
				*error = [NSError errorWithDomain:AudioPlayerErrorDomain 
											 code:AudioPlayerInternalError 
										 userInfo:errorDictionary];
			}
			
			return NO;
		}
	}
	
	// Schedule the region for playback, and start scheduling audio slices
	[[self scheduler] scheduleAudioRegion:[ScheduledAudioRegion scheduledAudioRegionWithDecoder:decoder]];
	[[self scheduler] startScheduling];

	[self prepareToPlayStream:stream];

	return YES;
}

- (BOOL) setNextStream:(AudioStream *)stream error:(NSError **)error
{
	NSParameterAssert(nil != stream);

	if(NO == [self isPlaying] || NO == [[self scheduler] isScheduling])
		return NO;

	id <AudioDecoderMethods> decoder = [stream decoder:error];
	if(nil == decoder)
		return NO;

	AudioStreamBasicDescription		format				= [self format];
	AudioStreamBasicDescription		nextFormat			= [decoder format];
	
	AudioChannelLayout				channelLayout		= [self channelLayout];
	AudioChannelLayout				nextChannelLayout	= [decoder channelLayout];
	
	BOOL	formatsMatch			= (nextFormat.mSampleRate == format.mSampleRate && nextFormat.mChannelsPerFrame == format.mChannelsPerFrame);
	BOOL	channelLayoutsMatch		= channelLayoutsAreEqual(&nextChannelLayout, &channelLayout);
	
	// The two files can be joined only if they have the same formats and channel layouts
	if(NO == formatsMatch || NO == channelLayoutsMatch)
		return NO;

	// The formats and channel layouts match, so schedule the region for playback
	[[self scheduler] scheduleAudioRegion:[ScheduledAudioRegion scheduledAudioRegionWithDecoder:decoder]];

	return YES;
}

- (void) reset
{
	[self willChangeValueForKey:@"hasValidStream"];
	
	[[self scheduler] stopScheduling];
	[[self scheduler] clear];

	[self didChangeValueForKey:@"hasValidStream"];
	
	[self willChangeValueForKey:@"totalFrames"];
	[self setTotalFrames:0];
	[self didChangeValueForKey:@"totalFrames"];
	
	[self willChangeValueForKey:@"currentFrame"];
	[self setStartingFrame:0];
	[self setPlayingFrame:0];
	[self didChangeValueForKey:@"currentFrame"];

	_regionStartingFrame = 0;
}

- (BOOL) hasValidStream
{
	return (nil != [[self scheduler] regionBeingScheduled] || nil != [[self scheduler] regionBeingRendered]);
}

- (BOOL) streamSupportsSeeking
{
	return ([self hasValidStream] && [[[[self scheduler] regionBeingRendered] decoder] supportsSeeking]);
}

#pragma mark Playback Control

- (void) play
{
	if(NO == [self canPlay] || [self isPlaying])
		return;
	
	if(NO == [[self scheduler] isScheduling])
		[[self scheduler] startScheduling];

	// Start playback of the ScheduledSoundPlayer unit by setting its start time
	AudioTimeStamp timeStamp = { 0 };
	
	timeStamp.mFlags		= kAudioTimeStampSampleTimeValid;
	timeStamp.mSampleTime	= -1;

	OSStatus err = AudioUnitSetProperty(_generatorUnit,
										kAudioUnitProperty_ScheduleStartTimeStamp, 
										kAudioUnitScope_Global, 
										0,
										&timeStamp, 
										sizeof(timeStamp));
	if(noErr != err)
		NSLog(@"AudioPlayer error: Unable to start AUScheduledSoundPlayer: %i", err);

/*	UInt32 dataSize = sizeof(timeStamp);
	err = AudioUnitGetProperty(_generatorUnit, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0, &timeStamp, &dataSize);
	if(noErr == err)
		NSLog(@"started at time: %f", timeStamp.mSampleTime);*/
	
	[self startAUGraph];
	[self setPlaying:YES];
}

- (void) playPause
{
	if([self isPlaying])
		[self stop];
	else
		[self play];
}

- (void) pause
{
	if([self isPlaying])
		[self stop];
}

- (void) stop
{
	if(NO == [self isPlaying])
		return;
	
	// Don't schedule any further slices for playback
	[[self scheduler] stopScheduling];
	
	// Determine the last sample that was rendered and update our internal state
	AudioTimeStamp timeStamp = [[self scheduler] currentPlayTime];
	if(kAudioTimeStampSampleTimeValid & timeStamp.mFlags) {
		SInt64 lastRenderedFrame = [self startingFrame] + timeStamp.mSampleTime - _regionStartingFrame;
		[self setStartingFrame:[[[[self scheduler] regionBeingScheduled] decoder] seekToFrame:lastRenderedFrame]];
		[self setPlayingFrame:0];
	}
	
	// Reset the scheduler to remove any scheduled slices
	[[self scheduler] reset];
	
	_regionStartingFrame = 0;
	
	[self stopAUGraph];
	[self setPlaying:NO];
}

- (void) skipForward
{
	[self skipForward:3];
}

- (void) skipBackward
{
	[self skipBackward:3];
}

- (void) skipForward:(UInt32)seconds
{
	ScheduledAudioRegion *currentRegion = [[self scheduler] regionBeingScheduled];
	
	if(nil != currentRegion && [[currentRegion decoder] supportsSeeking]) {
		SInt64 totalFrames		= [[currentRegion decoder] totalFrames];
		SInt64 currentFrame		= [[currentRegion decoder] currentFrame];
		SInt64 desiredFrame		= currentFrame + (SInt64)(seconds * [[currentRegion decoder] format].mSampleRate);
		
		if(totalFrames < desiredFrame)
			desiredFrame = totalFrames;
		
		[self setCurrentFrame:desiredFrame];
	}	
}

- (void) skipBackward:(UInt32)seconds
{
	ScheduledAudioRegion *currentRegion = [[self scheduler] regionBeingScheduled];
	
	if(nil != currentRegion && [[currentRegion decoder] supportsSeeking]) {
		SInt64 currentFrame		= [[currentRegion decoder] currentFrame];
		SInt64 desiredFrame		= currentFrame - (SInt64)(seconds * [[currentRegion decoder] format].mSampleRate);
		
		if(0 > desiredFrame)
			desiredFrame = 0;
		
		[self setCurrentFrame:desiredFrame];
	}
}

- (void) skipToEnd
{
	ScheduledAudioRegion *currentRegion = [[self scheduler] regionBeingScheduled];
	
	if(nil != currentRegion && [[currentRegion decoder] supportsSeeking]) {
		SInt64 totalFrames = [[currentRegion decoder] totalFrames];		
		[self setCurrentFrame:totalFrames - 1];
	}
}

- (void) skipToBeginning
{
	ScheduledAudioRegion *currentRegion = [[self scheduler] regionBeingScheduled];
	
	if(nil != currentRegion && [[currentRegion decoder] supportsSeeking])
		[self setCurrentFrame:0];
}

- (BOOL) isPlaying
{
	return _playing;
}

#pragma mark Bindings

- (Float32) volume
{
	Float32				volume		= -1;
	ComponentResult		result		= AudioUnitGetParameter(_outputUnit,
															kHALOutputParam_Volume,
															kAudioUnitScope_Global,
															0,
															&volume);
	
	if(noErr != result)
		NSLog(@"Unable to determine volume");
	
	return volume;
}

- (void) setVolume:(Float32)volume
{
	NSParameterAssert(0 <= volume && volume <= 1);
	
	ComponentResult result = AudioUnitSetParameter(_outputUnit,
												   kHALOutputParam_Volume,
												   kAudioUnitScope_Global,
												   0,
												   volume,
												   0);
	if(noErr != result)
		NSLog(@"Unable to set volume");
}

- (BOOL)			hasReplayGain							{ return _hasReplayGain; }
- (float)			replayGain								{ return _replayGain; }

- (float)			preAmplification						{ return _preAmplification; }

- (void) setPreAmplification:(float)preAmplification
{
	NSParameterAssert(-15.0 <= preAmplification && preAmplification <= 15.0);
	
	_preAmplification = preAmplification;
}

- (AudioStreamBasicDescription)		format					{ return _format; }
- (AudioChannelLayout)				channelLayout			{ return _channelLayout; }

- (void) saveStateToDefaults
{
	[[NSUserDefaults standardUserDefaults] setFloat:[self volume] forKey:@"playerVolume"];
	[self saveEffectsToDefaults];
}

- (void) restoreStateFromDefaults
{
	[self setVolume:[[NSUserDefaults standardUserDefaults] floatForKey:@"playerVolume"]];
	[self restoreEffectsFromDefaults];	
}

- (SInt64)			totalFrames								{ return _totalFrames; }

- (SInt64) currentFrame
{
	return [self startingFrame] + [self playingFrame] - _regionStartingFrame;
}

- (void) setCurrentFrame:(SInt64)currentFrame
{
//	NSParameterAssert(0 <= currentFrame && currentFrame < [self totalFrames]);
/*	if(0 > currentFrame)
		currentFrame = 0;
	else if([self totalFrames] <= currentFrame)
		currentFrame = [self totalFrames ] - 1;*/

	BOOL resume = NO;

	[[self scheduler] stopScheduling];
	[[self scheduler] reset];

	if([self isPlaying]) {
		[self setPlaying:NO];
		_regionStartingFrame = 0;		
		resume = YES;
	}
	
	OSStatus err = [self resetAUGraph];
	if(noErr != err)
		NSLog(@"AudioPlayer error: Unable to reset AUGraph AudioUnits: %i", err);

	Float64 graphLatency;
	err = [self getAUGraphLatency:&graphLatency];
	if(noErr != err)
		NSLog(@"AudioPlayer error: Unable to determine AUGraph latency: %i", err);
	
	UInt32 graphLatencyFrames = graphLatency * [self format].mSampleRate;

	currentFrame -= graphLatencyFrames;
		
	if(0 > currentFrame)
		currentFrame = 0;
	else if([self totalFrames] <= currentFrame)
		currentFrame = [self totalFrames ] - 1;
	
	[self setStartingFrame:[[[[self scheduler] regionBeingScheduled] decoder] seekToFrame:currentFrame + _regionStartingFrame]];
	[self setPlayingFrame:0];

	AudioTimeStamp timeStamp = [[self scheduler] scheduledStartTime];
	timeStamp.mSampleTime -= graphLatencyFrames;
	
	[[self scheduler] setScheduledStartTime:timeStamp];
	
#if DEBUG
	if([self startingFrame] != currentFrame)
		NSLog(@"Seek failed: requested frame %qi, got %qi", currentFrame, [self startingFrame]);
#endif
		
	[[self scheduler] startScheduling];
	
	if(resume)
		[self play];
}

- (SInt64) framesRemaining
{
	return [self totalFrames] - [self currentFrame];
}

- (NSTimeInterval) totalSeconds
{
	return (NSTimeInterval)([self totalFrames] / [self format].mSampleRate);
}

- (NSTimeInterval) currentSecond
{
	return (NSTimeInterval)([self currentFrame] / [self format].mSampleRate);
}

- (NSTimeInterval) secondsRemaining
{
	return (NSTimeInterval)([self framesRemaining] / [self format].mSampleRate);
}

#pragma mark AudioSchedulerMethods

- (void) audioSchedulerFinishedSchedulingRegion:(NSDictionary *)schedulerAndRegion
{
	NSParameterAssert(nil != schedulerAndRegion);

#if DEBUG
	ScheduledAudioRegion *region = [schedulerAndRegion valueForKey:ScheduledAudioRegionObjectKey];
	NSLog(@"-audioSchedulerFinishedSchedulingRegion: %@", region);
#endif

	// Request the next stream from the library, to keep playback going
	[_owner requestNextStream];
}

- (void) audioSchedulerStartedRenderingRegion:(NSDictionary *)schedulerAndRegion
{
	NSParameterAssert(nil != schedulerAndRegion);

	ScheduledAudioRegion *region = [schedulerAndRegion valueForKey:ScheduledAudioRegionObjectKey];

#if DEBUG
	NSLog(@"-audioSchedulerStartedRenderingRegion: %@", region);
#endif
	
	[self setTotalFrames:[[region decoder] totalFrames]];
	
	[self willChangeValueForKey:@"hasValidStream"];
	[self didChangeValueForKey:@"hasValidStream"];	

	[self willChangeValueForKey:@"currentFrame"];
	[self setStartingFrame:0];
	[self setPlayingFrame:0];
	[self didChangeValueForKey:@"currentFrame"];
	
	// If the owner successfully sent the next stream request, signal the end of the current stream
	// and beginning of the next one
	if([_owner sentNextStreamRequest])
		[_owner streamPlaybackDidStart];
}

- (void) audioSchedulerFinishedRenderingRegion:(NSDictionary *)schedulerAndRegion
{
	NSParameterAssert(nil != schedulerAndRegion);

	ScheduledAudioRegion *region = [schedulerAndRegion valueForKey:ScheduledAudioRegionObjectKey];

#if DEBUG
	NSLog(@"-audioSchedulerFinishedRenderingRegion: %@", region);
#endif
	
	// If nothing is coming up right away, stop ourselves from playing
	if(nil == [[self scheduler] regionBeingScheduled]) {
		[self stopAUGraph];
		[self setPlaying:NO];

		_regionStartingFrame = 0;
		
		[self willChangeValueForKey:@"hasValidStream"];
		[self didChangeValueForKey:@"hasValidStream"];	

		// Reset play position
		[self willChangeValueForKey:@"currentFrame"];
		[self setStartingFrame:0];
		[self setPlayingFrame:0];
		[self didChangeValueForKey:@"currentFrame"];
	}
	// Otherwise set up for the next stream
	else {
		_regionStartingFrame += [region framesRendered];
		[self prepareToPlayStream:[_owner nextStream]];
	}

	// If the owner did not successfully send the next stream request, signal the end of the current stream
	if(NO == [_owner sentNextStreamRequest])
		[_owner streamPlaybackDidComplete];
}

@end

@implementation AudioPlayer (AUGraphMethods)

- (AUGraph) auGraph
{
	return _auGraph;
}

- (OSStatus) setupAUGraph
{
	// Set up the AUGraph
	OSStatus err = NewAUGraph(&_auGraph);
	if(noErr != err)
		return err;

	// The graph will look like:
	// Generator -> Peak Limiter -> Effects -> Output
	ComponentDescription desc;
	
	// Set up the generator node
	desc.componentType			= kAudioUnitType_Generator;
	desc.componentSubType		= kAudioUnitSubType_ScheduledSoundPlayer;
	desc.componentManufacturer	= kAudioUnitManufacturer_Apple;
	desc.componentFlags			= 0;
	desc.componentFlagsMask		= 0;
	
	err = AUGraphAddNode([self auGraph], &desc, &_generatorNode);
	if(noErr != err)
		return err;
	
	// Set up the peak limiter node
	desc.componentType			= kAudioUnitType_Effect;
	desc.componentSubType		= kAudioUnitSubType_PeakLimiter;
	desc.componentManufacturer	= kAudioUnitManufacturer_Apple;
	desc.componentFlags			= 0;
	desc.componentFlagsMask		= 0;
	
	err = AUGraphAddNode([self auGraph], &desc, &_limiterNode);
	if(noErr != err)
		return err;
	
	// Set up the output node
	desc.componentType			= kAudioUnitType_Output;
	desc.componentSubType		= kAudioUnitSubType_DefaultOutput;
	desc.componentManufacturer	= kAudioUnitManufacturer_Apple;
	desc.componentFlags			= 0;
	desc.componentFlagsMask		= 0;
	
	err = AUGraphAddNode([self auGraph], &desc, &_outputNode);
	if(noErr != err)
		return err;
	
	// Connect the nodes
	err = AUGraphConnectNodeInput([self auGraph], _generatorNode, 0, _limiterNode, 0);
	if(noErr != err)
		return err;

	err = AUGraphConnectNodeInput([self auGraph], _limiterNode, 0, _outputNode, 0);
	if(noErr != err)
		return err;
	
	// Open the graph
	err = AUGraphOpen([self auGraph]);
	if(noErr != err)
		return err;
	
	// Initialize the graph
	err = AUGraphInitialize([self auGraph]);
	if(noErr != err)
		return err;
	
	// Store the audio units for later  use
	err = AUGraphNodeInfo([self auGraph], _generatorNode, NULL, &_generatorUnit);
	if(noErr != err)
		return err;
	
	err = AUGraphNodeInfo([self auGraph], _limiterNode, NULL, &_limiterUnit);
	if(noErr != err)
		return err;
	
	err = AUGraphNodeInfo([self auGraph], _outputNode, NULL, &_outputUnit);
	if(noErr != err)
		return err;
	
	return noErr;
}

- (OSStatus) teardownAUGraph
{	
	Boolean graphIsRunning = NO;
	OSStatus err = AUGraphIsRunning([self auGraph], &graphIsRunning);
	if(noErr != err)
		return err;
	
	if(graphIsRunning) {
		err = AUGraphStop([self auGraph]);
		if(noErr != err)
			return err;
	}
	
	Boolean graphIsInitialized = NO;	
	err = AUGraphIsInitialized([self auGraph], &graphIsInitialized);
	if(noErr != err)
		return err;
	
	if(graphIsInitialized) {
		err = AUGraphUninitialize([self auGraph]);
		if(noErr != err)
			return err;
	}
	
	err = AUGraphClose([self auGraph]);
	if(noErr != err)
		return err;
	
	err = DisposeAUGraph([self auGraph]);
	if(noErr != err)
		return err;
	
	_auGraph			= NULL;
	_generatorUnit		= NULL;
	_limiterUnit		= NULL;
	_outputUnit			= NULL;
	
	return noErr;
}

- (OSStatus) resetAUGraph
{
	UInt32 nodeCount;
	OSStatus err = AUGraphGetNodeCount([self auGraph], &nodeCount);
	if(noErr != err)
		return err;
	
	UInt32 i;
	for(i = 0; i < nodeCount; ++i) {
		AUNode node;
		err = AUGraphGetIndNode([self auGraph], i, &node);
		if(noErr != err)
			return err;
		
		AudioUnit au;
		err = AUGraphNodeInfo([self auGraph], node, NULL, &au);
		if(noErr != err)
			return err;
		
		err = AudioUnitReset(au, kAudioUnitScope_Global, 0);
		if(noErr != err)
			return err;
	}
	
	return noErr;
}

- (OSStatus) startAUGraph
{
	// Don't attempt to start an already running graph
	Boolean graphIsRunning = NO;
	OSStatus err = AUGraphIsRunning([self auGraph], &graphIsRunning);
	if(noErr == err && !graphIsRunning)
		err = AUGraphStart([self auGraph]);
		
	return err;
}

- (OSStatus) stopAUGraph
{
	Boolean graphIsRunning = NO;
	OSStatus err = AUGraphIsRunning([self auGraph], &graphIsRunning);
	if(noErr == err && graphIsRunning)
		err = AUGraphStop([self auGraph]);
	
	return err;
}

- (OSStatus) getAUGraphLatency:(Float64 *)graphLatency
{
	NSParameterAssert(NULL != graphLatency);
	
	*graphLatency = 0;
	
	UInt32 nodeCount;
	OSStatus err = AUGraphGetNodeCount([self auGraph], &nodeCount);
	if(noErr != err)
		return err;
	
	UInt32 i;
	for(i = 0; i < nodeCount; ++i) {
		AUNode node;
		err = AUGraphGetIndNode([self auGraph], i, &node);
		if(noErr != err)
			return err;
		
		AudioUnit au;
		err = AUGraphNodeInfo([self auGraph], node, NULL, &au);
		if(noErr != err)
			return err;
		
		Float64 latency;
		UInt32 dataSize = sizeof(latency);
		err = AudioUnitGetProperty(au, kAudioUnitProperty_Latency, kAudioUnitScope_Global, 0, &latency, &dataSize);
		if(noErr != err)
			return err;
		
		*graphLatency += latency;
	}
	
	return noErr;
}

- (OSStatus) getAUGraphTailTime:(Float64 *)graphTailTime
{
	NSParameterAssert(NULL != graphTailTime);
	
	*graphTailTime = 0;
	
	UInt32 nodeCount;
	OSStatus err = AUGraphGetNodeCount([self auGraph], &nodeCount);
	if(noErr != err)
		return err;
	
	UInt32 i;
	for(i = 0; i < nodeCount; ++i) {
		AUNode node;
		err = AUGraphGetIndNode([self auGraph], i, &node);
		if(noErr != err)
			return err;
		
		AudioUnit au;
		err = AUGraphNodeInfo([self auGraph], node, NULL, &au);
		if(noErr != err)
			return err;
		
		Float64 tailTime;
		UInt32 dataSize = sizeof(tailTime);
		err = AudioUnitGetProperty(au, kAudioUnitProperty_TailTime, kAudioUnitScope_Global, 0, &tailTime, &dataSize);
		if(noErr != err)
			return err;
		
		*graphTailTime += tailTime;
	}
	
	return noErr;
}

- (void) saveEffectsToDefaults
{
	// Save the effects
	UInt32 connectionCount;
	OSStatus err = AUGraphGetNumberOfConnections([self auGraph], &connectionCount);
	if(noErr != err)
		return;
	
	NSMutableArray *effects = [NSMutableArray array];
	
	unsigned i;
	for(i = 0; i < connectionCount; ++i) {
		AUNode node;
		err = AUGraphGetConnectionInfo([self auGraph], i, &node, NULL, NULL, NULL);
		if(noErr != err)
			return;
		
		// Skip the Generator and Peak Limiter nodes
		if(node == _generatorNode || node == _limiterNode)
			continue;
		
		ComponentDescription desc;
		CFPropertyListRef classData;
		err = AUGraphGetNodeInfo([self auGraph], node, &desc, NULL, (void **)&classData, NULL);
		if(noErr != err)
			return;
		
		NSDictionary *auDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithUnsignedLong:desc.componentType], AUTypeKey,
			[NSNumber numberWithUnsignedLong:desc.componentSubType], AUSubTypeKey,
			[NSNumber numberWithUnsignedLong:desc.componentManufacturer], AUManufacturerKey,
			classData, AUClassDataKey,
			nil];
		
		[effects addObject:auDictionary];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:effects forKey:@"playerDSPEffects"];
}

- (void) restoreEffectsFromDefaults
{
	for(NSDictionary *auDictionary in [[NSUserDefaults standardUserDefaults] arrayForKey:@"playerDSPEffects"]) {
		AUNode node;
		/*BOOL result =*/ [self addEffectToAUGraph:auDictionary newNode:&node error:nil];
	}
}

- (OSStatus) setAUGraphFormat:(AudioStreamBasicDescription)format
{
	OSStatus result = noErr;
	AudioUnitNodeConnection *connections = NULL;
	
	// If the graph is running, stop it
	Boolean graphIsRunning = NO;
	OSStatus err = AUGraphIsRunning([self auGraph], &graphIsRunning);
	if(noErr != err)
		return err;
	
	if(graphIsRunning) {
		err = AUGraphStop([self auGraph]);
		if(noErr != err)
			return err;
	}
	
	// If the graph is initialized, uninitialize it
	Boolean graphIsInitialized = NO;
	err = AUGraphIsInitialized([self auGraph], &graphIsInitialized);
	if(noErr != err)
		return err;
	
	if(graphIsInitialized) {
		err = AUGraphUninitialize([self auGraph]);
		if(noErr != err)
			return err;
	}
	
	// Save the connection information and then disconnect all the connections
	UInt32 connectionCount;
	err = AUGraphGetNumberOfConnections([self auGraph], &connectionCount);
	if(noErr != err)
		return err;
	
	connections = calloc(connectionCount, sizeof(AudioUnitNodeConnection));
	if(NULL == connections)
		return memFullErr;
	
	unsigned i;
	for(i = 0; i < connectionCount; ++i) {
		err = AUGraphGetConnectionInfo([self auGraph], i,
									   &connections[i].sourceNode, &connections[i].sourceOutputNumber,
									   &connections[i].destNode, &connections[i].destInputNumber);
		if(noErr != err) {
			free(connections);
			return err;
		}
	}
	
	err = AUGraphClearConnections([self auGraph]);
	if(noErr != err) {
		free(connections);
		return err;
	}
	
	// Attempt to set the new stream format
	err = [self setPropertyOnAUGraphNodes:kAudioUnitProperty_StreamFormat data:&format dataSize:sizeof(format)];
	if(noErr != err) {
		// If the new format could not be set, restore the old format to ensure a working graph
		format = [self format];
		OSStatus newErr = [self setPropertyOnAUGraphNodes:kAudioUnitProperty_StreamFormat data:&format dataSize:sizeof(format)];
		if(noErr != newErr)
			NSLog(@"AudioPlayer error: Unable to restore AUGraph format: %i", newErr);

		// Do not free connections here, so graph can be rebuilt
		result = err;
	}
	
	// Restore the graph's connections
	for(i = 0; i < connectionCount; ++i) {
		err = AUGraphConnectNodeInput([self auGraph], 
									  connections[i].sourceNode, connections[i].sourceOutputNumber,
									  connections[i].destNode, connections[i].destInputNumber);
		if(noErr != err) {
			NSLog(@"AudioPlayer error: Unable to restore AUGraph connection: %i", err);
			free(connections);
			return err;
		}
	}
	
	free(connections);
	
	// If the graph was initialized, reinitialize it
	if(graphIsInitialized) {
		err = AUGraphInitialize([self auGraph]);
		if(noErr != err)
			return err;
	}
	
	// If the graph was running, restart it
	if(graphIsRunning) {
		err = AUGraphStart([self auGraph]);
		if(noErr != err)
			return err;
	}
	
	// If an error occurred above setting the stream format, return the error now
	if(noErr != result)
		return result;
	
	return noErr;
}

- (OSStatus) setAUGraphChannelLayout:(AudioChannelLayout)channelLayout
{
	/*
	// Attempt to set the new channel layout
//	OSStatus err = [self setPropertyOnAUGraphNodes:kAudioUnitProperty_AudioChannelLayout data:&channelLayout dataSize:sizeof(channelLayout)];
	OSStatus err = AudioUnitSetProperty(_outputUnit, kAudioUnitProperty_AudioChannelLayout, kAudioUnitScope_Input, 0, &channelLayout, sizeof(channelLayout));
	if(noErr != err) {
		// If the new format could not be set, restore the old format to ensure a working graph
		channelLayout = [self channelLayout];
//		OSStatus newErr = [self setPropertyOnAUGraphNodes:kAudioUnitProperty_AudioChannelLayout data:&channelLayout dataSize:sizeof(channelLayout)];
		OSStatus newErr = AudioUnitSetProperty(_outputUnit, kAudioUnitProperty_AudioChannelLayout, kAudioUnitScope_Input, 0, &channelLayout, sizeof(channelLayout));
		if(noErr != newErr)
			NSLog(@"AudioPlayer error: Unable to restore AUGraph channel layout: %i", newErr);
		
		return err;
	}
	*/
	return noErr;
}

- (OSStatus) setPropertyOnAUGraphNodes:(AudioUnitPropertyID)propertyID data:(const void *)propertyData dataSize:(UInt32)propertyDataSize
{
	NSParameterAssert(NULL != propertyData);
	NSParameterAssert(0 < propertyDataSize);
	
	UInt32 nodeCount;
	OSStatus err = AUGraphGetNodeCount([self auGraph], &nodeCount);
	if(noErr != err)
		return err;

	// Iterate through the nodes and attempt to set the property
	unsigned i;
	for(i = 0; i < nodeCount; ++i) {
		AUNode node;
		err = AUGraphGetIndNode([self auGraph], i, &node);
		if(noErr != err)
			return err;
		
		AudioUnit au;
		err = AUGraphGetNodeInfo([self auGraph], node, NULL, NULL, NULL, &au);
		if(noErr != err)
			return err;
		
		if([self outputNode] == node) {
			// For AUHAL as the output node, you can't set the device side, so just set the client side
			err = AudioUnitSetProperty(au, propertyID, kAudioUnitScope_Input, 0, propertyData, propertyDataSize);
			if(noErr != err)
				return err;
			
			// IO must be enabled for this to work
//			err = AudioUnitSetProperty(au, propertyID, kAudioUnitScope_Output, 1, propertyData, propertyDataSize);
//			if(noErr != err)
//				return err;
		}
		else {
			UInt32 elementCount = 0;
			UInt32 dataSize = sizeof(elementCount);
			err = AudioUnitGetProperty(au, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &elementCount, &dataSize);
			if(noErr != err)
				return err;
			
			unsigned j;
			for(j = 0; j < elementCount; ++j) {
/*				Boolean writable;
				err = AudioUnitGetPropertyInfo(au, propertyID, kAudioUnitScope_Input, j, &dataSize, &writable);
				if(noErr != err && kAudioUnitErr_InvalidProperty != err)
					return err;
				
				if(kAudioUnitErr_InvalidProperty == err || !writable)
					continue;*/
				
				err = AudioUnitSetProperty(au, propertyID, kAudioUnitScope_Input, j, propertyData, propertyDataSize);
				if(noErr != err)
					return err;
			}
			
			elementCount = 0;
			dataSize = sizeof(elementCount);
			err = AudioUnitGetProperty(au, kAudioUnitProperty_ElementCount, kAudioUnitScope_Output, 0, &elementCount, &dataSize);
			if(noErr != err)
				return err;
			
			for(j = 0; j < elementCount; ++j) {
/*				Boolean writable;
				err = AudioUnitGetPropertyInfo(au, propertyID, kAudioUnitScope_Output, j, &dataSize, &writable);
				if(noErr != err && kAudioUnitErr_InvalidProperty != err)
					return err;
				
				if(kAudioUnitErr_InvalidProperty == err || !writable)
					continue;*/
				
				err = AudioUnitSetProperty(au, propertyID, kAudioUnitScope_Output, j, propertyData, propertyDataSize);
				if(noErr != err)
					return err;
			}
		}
	}
	
	return noErr;
}

- (AUNode) limiterNode
{
	return _limiterNode;
}

- (AUNode) outputNode
{
	return _outputNode;
}

- (void) startListeningForParameterChangesOnAudioUnit:(AudioUnit)audioUnit
{
	NSParameterAssert(NULL != audioUnit);
	
	AudioUnitEvent parameterEvent;
    parameterEvent.mEventType							= kAudioUnitEvent_ParameterValueChange;
    parameterEvent.mArgument.mParameter.mAudioUnit		= audioUnit;
    parameterEvent.mArgument.mParameter.mParameterID	= kAUParameterListener_AnyParameter;
    parameterEvent.mArgument.mParameter.mScope			= kAudioUnitScope_Global;
    parameterEvent.mArgument.mParameter.mElement		= 0;
	
	OSStatus err = AUEventListenerAddEventType(_auEventListener, NULL, &parameterEvent);	
	if(noErr != err)
		NSLog(@"AudioPlayer error: AUEventListenerAddEventType failed: %i", err);	
}

- (void) stopListeningForParameterChangesOnAudioUnit:(AudioUnit)audioUnit
{
	NSParameterAssert(NULL != audioUnit);
	
	AudioUnitEvent parameterEvent;
    parameterEvent.mEventType							= kAudioUnitEvent_ParameterValueChange;
    parameterEvent.mArgument.mParameter.mAudioUnit		= audioUnit;
    parameterEvent.mArgument.mParameter.mParameterID	= kAUParameterListener_AnyParameter;
    parameterEvent.mArgument.mParameter.mScope			= kAudioUnitScope_Global;
    parameterEvent.mArgument.mParameter.mElement		= 0;
	
	OSStatus err = AUEventListenerRemoveEventType(_auEventListener, NULL, &parameterEvent);	
	if(noErr != err)
		NSLog(@"AudioPlayer error: AUEventListenerRemoveEventType failed: %i", err);	
}

@end

@implementation AudioPlayer (DSPMethods)

- (NSArray *) currentEffects
{
	// Save the effects
	UInt32 connectionCount;
	OSStatus err = AUGraphGetNumberOfConnections([self auGraph], &connectionCount);
	if(noErr != err)
		return nil;
	
	NSMutableArray *effects = [[NSMutableArray alloc] init];
	
	unsigned i;
	for(i = 0; i < connectionCount; ++i) {
		AUNode node;
		err = AUGraphGetConnectionInfo([self auGraph], i, &node, NULL, NULL, NULL);
		if(noErr != err)
			continue;
		
		// Skip the Generator and Peak Limiter nodes
		if(node == _generatorNode || node == _limiterNode)
			continue;
		
		ComponentDescription	desc;
		CFPropertyListRef		classData;
		AudioUnit				au;
		
		err = AUGraphGetNodeInfo([self auGraph], node, &desc, NULL, (void **)&classData, &au);
		if(noErr != err)
			continue;
		
		Handle componentNameHandle = NewHandle(sizeof(void *));
		NSAssert(NULL != componentNameHandle, @"Unable to allocate memory");

		Handle componentInformationHandle = NewHandle(sizeof(void *));
		NSAssert(NULL != componentInformationHandle, @"Unable to allocate memory");
		
		Handle componentIconHandle = NewHandle(sizeof(void *));
		NSAssert(NULL != componentIconHandle, @"Unable to allocate memory");
		
		NSMutableDictionary *auDictionary = [NSMutableDictionary dictionary];
		
		OSErr err = GetComponentInfo((Component)au, &desc, componentNameHandle, componentInformationHandle, componentIconHandle);
		if(noErr == err) {
			[auDictionary setValue:[NSNumber numberWithUnsignedLong:desc.componentType] forKey:AUTypeKey];
			[auDictionary setValue:[NSNumber numberWithUnsignedLong:desc.componentSubType] forKey:AUSubTypeKey];
			[auDictionary setValue:[NSNumber numberWithUnsignedLong:desc.componentManufacturer] forKey:AUManufacturerKey];

			NSString *auNameAndManufacturer = (NSString *)CFStringCreateWithPascalString(kCFAllocatorDefault, (ConstStr255Param)(*componentNameHandle), kCFStringEncodingUTF8);
			[auDictionary setValue:[auNameAndManufacturer autorelease] forKey:AUNameAndManufacturerStringKey];

			NSString *auInformation = (NSString *)CFStringCreateWithPascalString(kCFAllocatorDefault, (ConstStr255Param)(*componentInformationHandle), kCFStringEncodingUTF8);
			[auDictionary setValue:[auInformation autorelease] forKey:AUInformationStringKey];

			unsigned int index = [auNameAndManufacturer rangeOfString:@":" options:NSLiteralSearch].location;
			if(NSNotFound != index) {
				[auDictionary setValue:[auNameAndManufacturer substringToIndex:index] forKey:AUManufacturerStringKey];
				
				// Skip colon
				++index;
				
				// Skip whitespace
				NSCharacterSet *whitespaceCharacters = [NSCharacterSet whitespaceCharacterSet];
				while([whitespaceCharacters characterIsMember:[auNameAndManufacturer characterAtIndex:index]])
					++index;
				
				[auDictionary setValue:[auNameAndManufacturer substringFromIndex:index] forKey:AUNameStringKey];
			}
			
			NSImage *iconImage = nil;
			
			// Use the AU icon if present
			NSURL *auURL = nil;
			UInt32 dataSize = sizeof(auURL);
			OSStatus err = AudioUnitGetProperty(au, kAudioUnitProperty_IconLocation, kAudioUnitScope_Global, 0, &auURL, &dataSize);
			if(noErr == err && nil != auURL) {
				iconImage = [[NSImage alloc] initByReferencingURL:auURL];
				[iconImage setSize:NSMakeSize(16, 16)];
			}
			
			// Fallback to the component's icon
			if(nil == iconImage) {
				iconImage = [[NSImage alloc] initWithData:[NSData dataWithBytes:*componentIconHandle length:GetHandleSize(componentIconHandle)]];
				[iconImage setSize:NSMakeSize(16, 16)];
			}
			
			if(nil != iconImage)
				[auDictionary setValue:[iconImage autorelease] forKey:AUIconKey];
		}

		DisposeHandle(componentNameHandle);
		DisposeHandle(componentInformationHandle);
		DisposeHandle(componentIconHandle);

		[auDictionary setValue:(id)classData forKey:AUClassDataKey];
		[auDictionary setValue:[NSNumber numberWithInt:node] forKey:AUNodeKey];
		
		[effects addObject:auDictionary];
	}
	
	return [effects autorelease];
}

- (NSArray *) availableEffects
{
	NSMutableArray *effects = [[NSMutableArray alloc] init];
	ComponentDescription desc;
	
//    desc.componentType			= kAudioUnitType_FormatConverter;
    desc.componentType			= kAudioUnitType_Effect;
    desc.componentSubType		= 0;
    desc.componentManufacturer	= 0;
    desc.componentFlags			= 0;
    desc.componentFlagsMask		= 0;
    	
	Component effectAU = FindNextComponent(NULL, &desc);
    while(NULL != effectAU) {
		Handle componentNameHandle = NewHandle(sizeof(void *));
		NSAssert(NULL != componentNameHandle, @"Unable to allocate memory");
		
		Handle componentInformationHandle = NewHandle(sizeof(void *));
		NSAssert(NULL != componentInformationHandle, @"Unable to allocate memory");
		
		Handle componentIconHandle = NewHandle(sizeof(void *));
		NSAssert(NULL != componentIconHandle, @"Unable to allocate memory");
		
		NSMutableDictionary *auDictionary = [NSMutableDictionary dictionary];
		
		ComponentDescription cd;
		OSErr err = GetComponentInfo(effectAU, &cd, componentNameHandle, componentInformationHandle, componentIconHandle);
		if(noErr == err) {
			[auDictionary setValue:[NSNumber numberWithUnsignedLong:cd.componentType] forKey:AUTypeKey];
			[auDictionary setValue:[NSNumber numberWithUnsignedLong:cd.componentSubType] forKey:AUSubTypeKey];
			[auDictionary setValue:[NSNumber numberWithUnsignedLong:cd.componentManufacturer] forKey:AUManufacturerKey];
			
			NSString *auNameAndManufacturer = (NSString *)CFStringCreateWithPascalString(kCFAllocatorDefault, (ConstStr255Param)(*componentNameHandle), kCFStringEncodingUTF8);
			[auDictionary setValue:[auNameAndManufacturer autorelease] forKey:AUNameAndManufacturerStringKey];
			
			NSString *auInformation = (NSString *)CFStringCreateWithPascalString(kCFAllocatorDefault, (ConstStr255Param)(*componentInformationHandle), kCFStringEncodingUTF8);
			[auDictionary setValue:[auInformation autorelease] forKey:AUInformationStringKey];
			
			unsigned int index = [auNameAndManufacturer rangeOfString:@":" options:NSLiteralSearch].location;
			if(NSNotFound != index) {
				[auDictionary setValue:[auNameAndManufacturer substringToIndex:index] forKey:AUManufacturerStringKey];
				
				// Skip colon
				++index;
				
				// Skip whitespace
				NSCharacterSet *whitespaceCharacters = [NSCharacterSet whitespaceCharacterSet];
				while([whitespaceCharacters characterIsMember:[auNameAndManufacturer characterAtIndex:index]])
					++index;
				
				[auDictionary setValue:[auNameAndManufacturer substringFromIndex:index] forKey:AUNameStringKey];
			}
			
			NSImage *iconImage = nil;
			
			// Use the AU icon if present
			NSURL *auURL = nil;
			UInt32 dataSize = sizeof(auURL);
			OSStatus err = AudioUnitGetProperty((AudioUnit)effectAU, kAudioUnitProperty_IconLocation, kAudioUnitScope_Global, 0, &auURL, &dataSize);
			if(noErr == err && nil != auURL) {
				iconImage = [[NSImage alloc] initByReferencingURL:auURL];
				[iconImage setSize:NSMakeSize(16, 16)];
			}

			// Fallback to the component's icon
			if(nil == iconImage) {
				iconImage = [[NSImage alloc] initWithData:[NSData dataWithBytes:*componentIconHandle length:GetHandleSize(componentIconHandle)]];
				[iconImage setSize:NSMakeSize(16, 16)];
			}
			
			if(nil != iconImage)
				[auDictionary setValue:[iconImage autorelease] forKey:AUIconKey];
		}
		
		DisposeHandle(componentNameHandle);
		DisposeHandle(componentInformationHandle);
		DisposeHandle(componentIconHandle);
		
		[effects addObject:auDictionary];
		
		effectAU = FindNextComponent(effectAU, &desc);
	}

	return [effects autorelease];
}

- (AudioUnit) audioUnitForAUNode:(AUNode)node
{
	AudioUnit au;
	OSStatus err = AUGraphGetNodeInfo([self auGraph], node, NULL, NULL, NULL, &au);
	if(noErr != err)
		return NULL;
	
	return au;
}

- (BOOL) addEffectToAUGraph:(NSDictionary *)auDictionary newNode:(AUNode *)newNode error:(NSError **)error
{
	NSParameterAssert(NULL != auDictionary);
	NSParameterAssert(NULL != newNode);
	
	// Get the current input node for the graph's outputNode
	UInt32 numConnections = 0;
	OSStatus err = AUGraphCountNodeConnections([self auGraph], [self outputNode], &numConnections);
	if(noErr != err)
		return NO;
	
	AudioUnitNodeConnection *connections = calloc(numConnections, sizeof(AudioUnitNodeConnection));
	if(NULL == connections)
		return NO;
	
	err = AUGraphGetNodeConnections([self auGraph], [self outputNode], connections, &numConnections);
	if(noErr != err) {
		free(connections), connections = NULL;
		return NO;
	}
	
	AUNode previousNode = -1;
	UInt32 i;
	for(i = 0; i < numConnections; ++i) {
		AudioUnitNodeConnection connection = connections[i];
		if([self outputNode] == connection.destNode) {
			previousNode = connection.sourceNode;
			break;
		}
	}
	
	free(connections), connections = NULL;

	if(-1 == previousNode)
		return NO;
	
	AudioUnit au = NULL;	
	err = AUGraphGetNodeInfo([self auGraph], previousNode, NULL, NULL, NULL, &au);
	if(noErr != err)
		return NO;
	
	AudioStreamBasicDescription inputASBD;
	UInt32 dataSize = sizeof(inputASBD);
	err = AudioUnitGetProperty(au, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &inputASBD, &dataSize);
	if(noErr != err)
		return NO;
	
	AudioStreamBasicDescription outputASBD;
	dataSize = sizeof(outputASBD);
	err = AudioUnitGetProperty(au, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &outputASBD, &dataSize);
	if(noErr != err)
		return NO;
	
	// Create a new node of the specified type
	ComponentDescription componentDescription;
	
	componentDescription.componentType			= [[auDictionary valueForKey:AUTypeKey] unsignedLongValue];
	componentDescription.componentSubType		= [[auDictionary valueForKey:AUSubTypeKey] unsignedLongValue];
	componentDescription.componentManufacturer	= [[auDictionary valueForKey:AUManufacturerKey] unsignedLongValue];
	componentDescription.componentFlags			= 0;
	componentDescription.componentFlagsMask		= 0;
	
	CFPropertyListRef	classData				= [auDictionary valueForKey:AUClassDataKey];

	err = AUGraphNewNode([self auGraph], &componentDescription, 0, classData, newNode);
	if(noErr != err)
		return NO;
	
	err = AUGraphGetNodeInfo([self auGraph], *newNode, NULL, NULL, NULL, &au);
	if(noErr != err)
		return NO;
	
	err = AudioUnitSetProperty(au, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &inputASBD, sizeof(inputASBD));
	if(noErr != err) {
		// If the property couldn't be set (the AU may not support this format), remove the new node
		err = AUGraphRemoveNode([self auGraph], *newNode);
		if(noErr != err)
			NSLog(@"AudioPlayer error: Unable to remove node: %i", err);
		
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The DSP effect \"%@\" does not support this audio format.", @"Errors", @""), [auDictionary valueForKey:AUNameStringKey]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"DSP Effect Not Supported", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The current track's sample rate or channel layout is not supported by this DSP effect.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:AudioPlayerErrorDomain 
										 code:AudioPlayerInternalError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	err = AudioUnitSetProperty(au, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &outputASBD, sizeof(outputASBD));
	if(noErr != err) {
		// If the property couldn't be set (the AU may not support this format), remove the new node
		err = AUGraphRemoveNode([self auGraph], *newNode);
		if(noErr != err)
			NSLog(@"AudioPlayer error: Unable to remove node: %i", err);
		
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The DSP effect \"%@\" does not support this format.", @"Errors", @""), [auDictionary valueForKey:AUNameStringKey]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"DSP Effect Not Supported", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The current track's sample rate or channel layout is not supported by this DSP effect.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:AudioPlayerErrorDomain 
										 code:AudioPlayerInternalError 
									 userInfo:errorDictionary];
		}

		return NO;
	}
	
	// Insert the new node just before the outputNode
	err = AUGraphDisconnectNodeInput([self auGraph], [self outputNode], 0);
	if(noErr != err)
		return NO;
	
	// Reconnect the nodes
	err = AUGraphConnectNodeInput([self auGraph], previousNode, 0, *newNode, 0);
	if(noErr != err)
		return NO;
	
	err = AUGraphConnectNodeInput([self auGraph], *newNode, 0, [self outputNode], 0);
	if(noErr != err)
		return NO;
	
	err = AUGraphUpdate([self auGraph], NULL);
	if(noErr != err) {
		// If the update failed, restore the previous node state
		err = AUGraphConnectNodeInput([self auGraph], previousNode, 0, [self outputNode], 0);
		if(noErr != err)
			return NO;
	}

//	[self startListeningForParameterChangesOnAudioUnit:[self audioUnitForAUNode:*newNode]];
	
//	[self saveEffects];
	
	return YES;
}

- (BOOL) removeEffectFromAUGraph:(AUNode)effectNode error:(NSError **)error
{
	AudioUnit au = NULL;
	OSStatus err = AUGraphGetNodeInfo([self auGraph], effectNode, NULL, NULL, NULL, &au);
	if(noErr != err)
		return NO;
	
//	[self stopListeningForParameterChangesOnAudioUnit:au];
	
	// Get the current input and output nodes for the node to delete
	UInt32 numConnections = 0;
	err = AUGraphCountNodeConnections([self auGraph], effectNode, &numConnections);
	if(noErr != err)
		return NO;
	
	AudioUnitNodeConnection *connections = calloc(numConnections, sizeof(AudioUnitNodeConnection));
	if(NULL == connections)
		return NO;
	
	err = AUGraphGetNodeConnections([self auGraph], effectNode, connections, &numConnections);
	if(noErr != err) {
		free(connections), connections = NULL;
		return NO;
	}
	
	AUNode previousNode, nextNode;
	UInt32 i;
	for(i = 0; i < numConnections; ++i) {
		AudioUnitNodeConnection connection = connections[i];
		if(effectNode == connection.destNode)
			previousNode = connection.sourceNode;
		else if(effectNode == connection.sourceNode)
			nextNode = connection.destNode;
	}

	free(connections), connections = NULL;

	err = AUGraphDisconnectNodeInput([self auGraph], effectNode, 0);
	if(noErr != err)
		return NO;
	
	err = AUGraphDisconnectNodeInput([self auGraph], nextNode, 0);
	if(noErr != err)
		return NO;
	
	err = AUGraphRemoveNode([self auGraph], effectNode);
	if(noErr != err)
		return NO;
	
	// Reconnect the nodes
	err = AUGraphConnectNodeInput([self auGraph], previousNode, 0, nextNode, 0);
	if(noErr != err)
		return NO;
	
	err = AUGraphUpdate([self auGraph], NULL);
	if(noErr != err)
		return NO;
	
//	[self saveEffects];

	return YES;
}

@end

@implementation AudioPlayer (Private)

- (AudioScheduler *) scheduler
{
	return [[_scheduler retain] autorelease];
}

- (BOOL) canPlay
{
	Boolean graphIsInitialized = NO;
	OSStatus result = AUGraphIsInitialized([self auGraph], &graphIsInitialized);
	if(noErr != result)
		return NO;
	
	return (graphIsInitialized/* && [[self scheduler] isScheduling]*/);
}

- (void) uiTimerFireMethod:(NSTimer *)theTimer
{
	if(NO == [[self scheduler] isScheduling] || NO == [self isPlaying])
		return;

/*	Float32 averageCPULoad;
	OSStatus err = AUGraphGetCPULoad([self auGraph], &averageCPULoad);
	if(noErr == err)
		NSLog(@"Average CPU load = %f", averageCPULoad);*/
	
	// Determine the last sample that was rendered
	AudioTimeStamp timeStamp = [[self scheduler] currentPlayTime];
	if(kAudioTimeStampSampleTimeValid & timeStamp.mFlags && -1 != timeStamp.mSampleTime) {
		[self willChangeValueForKey:@"currentFrame"];
		[self setPlayingFrame:timeStamp.mSampleTime];
		[self didChangeValueForKey:@"currentFrame"];
	}
}

- (NSRunLoop *)	runLoop
{
	return [[_runLoop retain] autorelease];
}

- (void) setPlaying:(BOOL)playing
{
	_playing = playing;
}

- (void) setTotalFrames:(SInt64)totalFrames
{
	NSParameterAssert(0 <= totalFrames);
	_totalFrames = totalFrames;
}

- (SInt64)			startingFrame					{ return _startingFrame; }

- (void) setStartingFrame:(SInt64)startingFrame
{
	NSParameterAssert(0 <= startingFrame);
	_startingFrame = startingFrame;
}

- (SInt64)			playingFrame					{ return _playingFrame; }

- (void) setPlayingFrame:(SInt64)playingFrame
{
	NSParameterAssert(0 <= playingFrame);
	_playingFrame = playingFrame;
}

- (void) setOutputDeviceUID:(NSString *)deviceUID
{
	AudioDeviceID		deviceID		= kAudioDeviceUnknown;
	UInt32				specifierSize	= 0;
	OSStatus			status			= noErr;
	
	if(nil == deviceUID || [deviceUID isEqual:[NSNull null]] || [deviceUID isEqualToString:@""]) {
		specifierSize = sizeof(deviceID);
		status = AudioHardwareGetProperty(kAudioHardwarePropertyDefaultOutputDevice, 
										  &specifierSize, 
										  &deviceID);
	}
	else {
		AudioValueTranslation translation;
		
		translation.mInputData			= &deviceUID;
		translation.mInputDataSize		= sizeof(deviceUID);
		translation.mOutputData			= &deviceID;
		translation.mOutputDataSize		= sizeof(deviceID);
		specifierSize					= sizeof(translation);
		
		status = AudioHardwareGetProperty(kAudioHardwarePropertyDeviceForUID, 
										  &specifierSize, 
										  &translation);
	}

	if(noErr == status && kAudioDeviceUnknown != deviceID) {
		
		// Stop listening for sample rate changes
		[self stopListeningForSampleRateChangesOnOutputDevice];

		// Release hog mode, regardless of the user's preference
		if([self outputDeviceIsHogged]) {
			OSStatus hogStatus = [self stopHoggingOutputDevice];
			if(noErr != hogStatus)
				NSLog(@"Unable to release hog mode");
		}
		
		// Update our output AU to use the currently selected device
		status = AudioUnitSetProperty(_outputUnit,
									  kAudioOutputUnitProperty_CurrentDevice,
									  kAudioUnitScope_Global,
									  0,
									  &deviceID,
									  sizeof(deviceID));

		// Hog the device, if specified
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"hogOutputDevice"]) {
			OSStatus hogStatus = [self startHoggingOutputDevice];
			if(noErr != hogStatus)
				NSLog(@"Unable to obtain hog mode");
		}
		
		// Observe sample rate changes on the device
		[self startListeningForSampleRateChangesOnOutputDevice];
	}
	
	if(noErr != status)
		NSLog(@"Error setting output device");
}

- (OSStatus) setOutputDeviceSampleRate:(Float64)sampleRate
{
	// Get the current output device
	AudioDeviceID		deviceID		= kAudioDeviceUnknown;
	UInt32				specifierSize	= 0;
	OSStatus			status			= noErr;
	
	specifierSize = sizeof(deviceID);
	status = AudioUnitGetProperty(_outputUnit,
								  kAudioOutputUnitProperty_CurrentDevice,
								  kAudioUnitScope_Global,
								  0,
								  &deviceID,
								  &specifierSize);
	
	if(noErr != status) {
		NSLog(@"AudioUnitGetProperty(kAudioOutputUnitProperty_CurrentDevice) failed");
		return status;
	}
	
	// Determine if this actually is a change
	Float64 currentSampleRate;
	specifierSize = sizeof(currentSampleRate);
	status = AudioDeviceGetProperty(deviceID, 0, NO, kAudioDevicePropertyNominalSampleRate, &specifierSize, &currentSampleRate);
	if(noErr != status) {
		NSLog(@"AudioDeviceGetProperty(kAudioDevicePropertyNominalSampleRate) failed");
		return status;
	}
	
	// Nothing to do
	if(currentSampleRate == sampleRate)
		return noErr;
	
	// Set the sample rate
	specifierSize = sizeof(sampleRate);
	status = AudioDeviceSetProperty(deviceID, NULL, 0, NO, kAudioDevicePropertyNominalSampleRate, sizeof(sampleRate), &sampleRate);

	if(kAudioHardwareNoError != status)
		NSLog(@"AudioDeviceSetProperty(kAudioDevicePropertyNominalSampleRate) failed");
	
	return status;
}

- (BOOL) outputDeviceIsHogged
{
	// Get the current output device
	AudioDeviceID		deviceID		= kAudioDeviceUnknown;
	UInt32				specifierSize	= 0;
	OSStatus			status			= noErr;
	
	specifierSize = sizeof(deviceID);
	status = AudioUnitGetProperty(_outputUnit,
								  kAudioOutputUnitProperty_CurrentDevice,
								  kAudioUnitScope_Global,
								  0,
								  &deviceID,
								  &specifierSize);
	
	if(noErr != status) {
		NSLog(@"AudioUnitGetProperty(kAudioOutputUnitProperty_CurrentDevice) failed");
		return NO;
	}

	// Is it hogged by us?
	pid_t hogPID;
	specifierSize = sizeof(hogPID);
	status = AudioDeviceGetProperty(deviceID, 0, NO, kAudioDevicePropertyHogMode, &specifierSize, &hogPID);

	if(kAudioHardwareNoError != status) {
		NSLog(@"AudioDeviceGetProperty(kAudioDevicePropertyHogMode) failed");
		return NO;
	}
	
	if(hogPID == getpid())
		return YES;
	else
		return NO;
}

- (OSStatus) startHoggingOutputDevice
{
	// Get the current output device
	AudioDeviceID		deviceID		= kAudioDeviceUnknown;
	UInt32				specifierSize	= 0;
	OSStatus			status			= noErr;
	
	specifierSize = sizeof(deviceID);
	status = AudioUnitGetProperty(_outputUnit,
								  kAudioOutputUnitProperty_CurrentDevice,
								  kAudioUnitScope_Global,
								  0,
								  &deviceID,
								  &specifierSize);
	
	if(noErr != status) {
		NSLog(@"AudioUnitGetProperty(kAudioOutputUnitProperty_CurrentDevice) failed");
		return status;
	}
	
	// Is it hogged already?
	pid_t hogPID;
	specifierSize = sizeof(hogPID);
	status = AudioDeviceGetProperty(deviceID, 0, NO, kAudioDevicePropertyHogMode, &specifierSize, &hogPID);
	
	if(kAudioHardwareNoError != status) {
		NSLog(@"AudioDeviceGetProperty(kAudioDevicePropertyHogMode) failed");
		return status;
	}
		
	// The device isn't hogged, so attempt to hog it
	if(hogPID == (pid_t)-1) {
		hogPID = getpid();
		status = AudioDeviceSetProperty(deviceID, NULL, 0, NO, kAudioDevicePropertyHogMode, sizeof(hogPID), &hogPID);

		if(kAudioHardwareNoError != status) {
			NSLog(@"AudioDeviceSetProperty(kAudioDevicePropertyHogMode) failed");
			return status;
		}
	}
	else
		NSLog(@"Device is already hogged by pid: %d", hogPID);
	
	return noErr;
}

- (OSStatus) stopHoggingOutputDevice
{
	// Since kAudioDevicePropertyHogMode is a toggle, this is identical to startHoggingOutputDevice
	return [self startHoggingOutputDevice];
}

- (OSStatus) startListeningForSampleRateChangesOnOutputDevice
{
	// Get the current output device
	AudioDeviceID		deviceID		= kAudioDeviceUnknown;
	UInt32				specifierSize	= 0;
	OSStatus			status			= noErr;
	
	specifierSize = sizeof(deviceID);
	status = AudioUnitGetProperty(_outputUnit,
								  kAudioOutputUnitProperty_CurrentDevice,
								  kAudioUnitScope_Global,
								  0,
								  &deviceID,
								  &specifierSize);
	
	if(noErr != status) {
		NSLog(@"AudioUnitGetProperty(kAudioOutputUnitProperty_CurrentDevice) failed");
		return status;
	}

	return AudioDeviceAddPropertyListener(deviceID, 0, NO, kAudioDevicePropertyNominalSampleRate, myAudioDevicePropertyListenerProc, self);
}

- (OSStatus) stopListeningForSampleRateChangesOnOutputDevice
{
	// Get the current output device
	AudioDeviceID		deviceID		= kAudioDeviceUnknown;
	UInt32				specifierSize	= 0;
	OSStatus			status			= noErr;
	
	specifierSize = sizeof(deviceID);
	status = AudioUnitGetProperty(_outputUnit,
								  kAudioOutputUnitProperty_CurrentDevice,
								  kAudioUnitScope_Global,
								  0,
								  &deviceID,
								  &specifierSize);
	
	if(noErr != status) {
		NSLog(@"AudioUnitGetProperty(kAudioOutputUnitProperty_CurrentDevice) failed");
		return status;
	}

	return AudioDeviceRemovePropertyListener(deviceID, 0, NO, kAudioDevicePropertyNominalSampleRate, myAudioDevicePropertyListenerProc);
}

- (void) outputDeviceSampleRateChanged
{
	// Get the current output device
	AudioDeviceID		deviceID		= kAudioDeviceUnknown;
	UInt32				specifierSize	= 0;
	OSStatus			status			= noErr;
	
	specifierSize = sizeof(deviceID);
	status = AudioUnitGetProperty(_outputUnit,
								  kAudioOutputUnitProperty_CurrentDevice,
								  kAudioUnitScope_Global,
								  0,
								  &deviceID,
								  &specifierSize);
	
	if(noErr != status) {
		NSLog(@"AudioUnitGetProperty(kAudioOutputUnitProperty_CurrentDevice) failed");
		return;
	}

	// Query sample rate
	Float64 sampleRate = 0;
	specifierSize = sizeof(sampleRate);
	status = AudioDeviceGetProperty(deviceID, 0, NO, kAudioDevicePropertyNominalSampleRate, &specifierSize, &sampleRate);
	
	if(kAudioHardwareNoError != status) {
		NSLog(@"AudioDeviceGetProperty(kAudioDevicePropertyNominalSampleRate) failed");
		return;
	}

	// Determine if this is bad (ie, doesn't match the current stream's sample rate)
	if([self format].mSampleRate == sampleRate)
		return;

	// Display an alert since this is a bad thing
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:NSLocalizedStringFromTable(@"Sample Rate Change Detected", @"Errors", @"")];
	[alert setInformativeText:NSLocalizedStringFromTable(@"An external program has changed the sample rate of the device. This can lead to degraded audio quality.", @"Errors", @"")];
	[alert setAlertStyle:NSInformationalAlertStyle];
	
	// Display the alert
	[alert beginSheetModalForWindow:[[self owner] window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
	[alert release];
	
#if DEBUG
	NSLog(@"External sample rate change: %f (stream sample rate %f)", sampleRate, [self format].mSampleRate);
#endif
}

- (void) setHasReplayGain:(BOOL)hasReplayGain
{
	_hasReplayGain = hasReplayGain;
}

- (void) setReplayGain:(float)replayGain
{
	NSParameterAssert(-51.0 <= replayGain && replayGain <= 51.0);
	
	_replayGain = replayGain;
}

- (void) prepareToPlayStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	
	// Reset preamp to user-specified value
	[self setPreAmplification:[[NSUserDefaults standardUserDefaults] floatForKey:@"preAmplification"]];

	// Set our ReplayGain to the appropriate value and grab the appropriate peak
	NSNumber *peak = [self setReplayGainForStream:stream];

	// Reduce pre-amp gain, if user specified and signal would clip
	if([self hasReplayGain] && nil != peak && ReducePreAmpGain == [[NSUserDefaults standardUserDefaults] integerForKey:@"clippingPrevention"]) {

		float adjustment = [self preAmplification] + [self replayGain];
		
		if(0 != adjustment) {
			float	peakSample	= [peak floatValue];
			float	multiplier	= powf(10, adjustment / 20);
			float	sample		= peakSample * multiplier;
			float	magnitude	= fabsf(sample);
			
			// If clipping will occur, reduce the preamp gain so the peak will be +/- 1.0
			if(1.0 < magnitude)
				[self setPreAmplification:(20 * log10f(1.0 / peakSample)) - [self replayGain]];
		}
	}

	// Set the pre-gain on the peak limiter
	float preGain = 0;
	if([self hasReplayGain])
		preGain = [self preAmplification] + [self replayGain];
	
	AudioUnitParameter auParameter;
	
	auParameter.mAudioUnit		= _limiterUnit;
	auParameter.mParameterID	= kLimiterParam_PreGain;
	auParameter.mScope			= kAudioUnitScope_Global;
	auParameter.mElement		= 0;
	
	OSStatus err = AUParameterSet(NULL, NULL, &auParameter, preGain, 0);
	if(noErr != err)
		NSLog(@"AudioPlayer error: Unable to set ReplayGain: %i", err);
}

- (NSNumber *) setReplayGainForStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	
	int				replayGain		= [[NSUserDefaults standardUserDefaults] integerForKey:@"replayGain"];
	NSNumber		*trackGain		= [stream valueForKey:ReplayGainTrackGainKey];
	NSNumber		*albumGain		= [stream valueForKey:ReplayGainAlbumGainKey];
	
	// Try to use the RG the user wants
	if(ReplayGainTrackGain == replayGain && nil != trackGain) {
		[self setReplayGain:[trackGain floatValue]];
		[self setHasReplayGain:YES];
		return [stream valueForKey:ReplayGainTrackPeakKey];
	}
	else if(ReplayGainAlbumGain == replayGain && nil != albumGain) {
		[self setReplayGain:[albumGain floatValue]];
		[self setHasReplayGain:YES];
		return [stream valueForKey:ReplayGainAlbumPeakKey];
	}
	// Fall back to any gain if present
	else if(ReplayGainNone != replayGain && nil != trackGain) {
		[self setReplayGain:[trackGain floatValue]];
		[self setHasReplayGain:YES];
		return [stream valueForKey:ReplayGainTrackPeakKey];
	}
	else if(ReplayGainNone != replayGain && nil != albumGain) {
		[self setReplayGain:[albumGain floatValue]];
		[self setHasReplayGain:YES];
		return [stream valueForKey:ReplayGainAlbumPeakKey];
	}

	// No dice, or RG set to off
	[self setReplayGain:0];
	[self setHasReplayGain:NO];
	return nil;
}

- (void) setFormat:(AudioStreamBasicDescription)format
{
	_format = format;
}

- (void) setChannelLayout:(AudioChannelLayout)channelLayout
{
	_channelLayout = channelLayout;
}

@end
