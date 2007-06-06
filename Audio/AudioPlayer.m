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
#import "AudioDecoder.h"

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
NSString *const AudioPlayerErrorDomain = @"org.sbooth.Play.ErrorDomain.AudioPlayer";

// ========================================
// AudioPlayer callbacks
// ========================================
@interface AudioLibrary (AudioPlayerMethods)
- (void) streamPlaybackDidStart;
- (void) streamPlaybackDidComplete;
- (void) requestNextStream;
- (BOOL) sentNextStreamRequest;
@end

// ========================================
// AUGraph manipulation
// ========================================
@interface AudioPlayer (AUGraphMethods)
- (OSStatus) setupAUGraph;
- (OSStatus) teardownAUGraph;
- (OSStatus) setAUGraphFormat:(AudioStreamBasicDescription)format;
- (OSStatus) setAUGraphChannelLayout:(AudioChannelLayout)channelLayout;
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

- (void) setHasReplayGain:(BOOL)hasReplayGain;
- (void) setReplayGain:(float)replayGain;

- (void) prepareToPlayStream:(AudioStream *)stream;
- (NSNumber *) setReplayGainForStream:(AudioStream *)stream;
@end

@implementation AudioPlayer

+ (void) initialize
{
	[self exposeBinding:@"volume"];
	[self exposeBinding:@"currentFrame"];
	[self exposeBinding:@"totalFrames"];
	[self exposeBinding:@"hasValidStream"];
	[self exposeBinding:@"streamSupportsSeeking"];
	
	[self setKeys:[NSArray arrayWithObject:@"streamDecoder"] triggerChangeNotificationsForDependentKey:@"hasValidStream"];
	[self setKeys:[NSArray arrayWithObject:@"hasValidStream"] triggerChangeNotificationsForDependentKey:@"streamSupportsSeeking"];

//	[self setKeys:[NSArray arrayWithObject:@"hasValidStream"] triggerChangeNotificationsForDependentKey:@"currentFrame"];
	[self setKeys:[NSArray arrayWithObject:@"hasValidStream"] triggerChangeNotificationsForDependentKey:@"totalFrames"];

	[self setKeys:[NSArray arrayWithObject:@"currentFrame"] triggerChangeNotificationsForDependentKey:@"currentSecond"];
	[self setKeys:[NSArray arrayWithObject:@"currentFrame"] triggerChangeNotificationsForDependentKey:@"secondsRemaining"];
	[self setKeys:[NSArray arrayWithObject:@"totalFrames"] triggerChangeNotificationsForDependentKey:@"totalSeconds"];
}

- (id) init
{
	if((self = [super init])) {
		_runLoop = [[NSRunLoop currentRunLoop] retain];
		
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
																	 options:nil
																	 context:NULL];		
	}
	return self;
}

- (void) dealloc
{
	[_timer invalidate], _timer = nil;

	[[self scheduler] stopScheduling];
	[self teardownAUGraph];

	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self 
																 forKeyPath:@"values.outputAudioDeviceUID"];
		
	[_runLoop release], _runLoop = nil;
	[_scheduler release], _scheduler = nil;
	
	[super dealloc];
}

- (AudioLibrary *)		owner									{ return _owner; }
- (void)				setOwner:(AudioLibrary *)owner			{ _owner = owner; }

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
	
	AudioDecoder *decoder = [AudioDecoder audioDecoderForStream:stream error:error];
	if(nil == decoder)
		return NO;
	
	AudioStreamBasicDescription		newFormat			= [decoder format];
	AudioChannelLayout				newChannelLayout	= [decoder channelLayout];

	// If the sample rate or number of channels changed, change the AU formats
	if(newFormat.mSampleRate != _format.mSampleRate || newFormat.mChannelsPerFrame != _format.mChannelsPerFrame) {
		OSStatus err = [self setAUGraphFormat:newFormat];
		if(noErr != err) {
			if(nil != error) {
				NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
				NSString				*path				= [[stream valueForKey:StreamURLKey] path];
				
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The format of the file \"%@\" is not supported.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"File Format Not Supported", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"The file contains an unsupported audio data format.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
				
				*error = [NSError errorWithDomain:AudioPlayerErrorDomain 
											 code:AudioPlayerInternalError 
										 userInfo:errorDictionary];
			}
			
			[self teardownAUGraph];
			[self setupAUGraph];
			[[self scheduler] setAudioUnit:_generatorUnit];
			
			return NO;
		}
	}

	// Schedule the region for playback, and start scheduling audio slices
	[[self scheduler] scheduleAudioRegion:[ScheduledAudioRegion scheduledAudioRegionForDecoder:decoder]];
	[[self scheduler] startScheduling];

	[self prepareToPlayStream:stream];
	
	return YES;
}

- (BOOL) setNextStream:(AudioStream *)stream error:(NSError **)error
{
	NSParameterAssert(nil != stream);

	if(NO == [self isPlaying] || NO == [[self scheduler] isScheduling])
		return NO;

	AudioDecoder *decoder = [AudioDecoder audioDecoderForStream:stream error:error];
	if(nil == decoder)
		return NO;
	
	AudioStreamBasicDescription		nextFormat			= [decoder format];
	AudioChannelLayout				nextChannelLayout	= [decoder channelLayout];
	
	BOOL	formatsMatch			= (nextFormat.mSampleRate == _format.mSampleRate && nextFormat.mChannelsPerFrame == _format.mChannelsPerFrame);
	BOOL	channelLayoutsMatch		= channelLayoutsAreEqual(&nextChannelLayout, &_channelLayout);
	
	// The two files can be joined only if they have the same formats and channel layouts
	if(NO == formatsMatch || NO == channelLayoutsMatch)
		return NO;
	
	// They match, so schedule the region for playback
	[[self scheduler] scheduleAudioRegion:[ScheduledAudioRegion scheduledAudioRegionForDecoder:decoder]];

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
	return ([self hasValidStream] && [[[self scheduler] regionBeingRendered] supportsSeeking]);
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
		NSLog(@"AudioUnitSetProperty failed: %s", UTCreateStringForOSType(err));

	[self setPlaying:YES];
}

- (void) playPause
{
	if([self isPlaying])
		[self stop];
	else
		[self play];
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
		[self setStartingFrame:[[[self scheduler] regionBeingScheduled] seekToFrame:lastRenderedFrame]];
		[self setPlayingFrame:0];
	}
	
	// Reset the scheduler to remove any scheduled slices
	[[self scheduler] reset];
	
	_regionStartingFrame = 0;
	
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
		SInt64 totalFrames		= [currentRegion totalFrames];
		SInt64 currentFrame		= [currentRegion currentFrame];
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
		SInt64 currentFrame		= [currentRegion currentFrame];
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
		SInt64 totalFrames = [currentRegion totalFrames];		
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

- (SInt64)			totalFrames								{ return _totalFrames; }

- (SInt64) currentFrame
{
	return [self startingFrame] + [self playingFrame] - _regionStartingFrame;
}

- (void) setCurrentFrame:(SInt64)currentFrame
{
	NSParameterAssert(0 <= currentFrame && currentFrame <= [self totalFrames]);
	
	BOOL resume = NO;
	
	if([self isPlaying]) {
		[self stop];
		resume = YES;
	}
	else {
		[[self scheduler] stopScheduling];
		[[self scheduler] reset];
	}
	
	[self setStartingFrame:[[[self scheduler] regionBeingScheduled] seekToFrame:currentFrame + _regionStartingFrame]];
	[self setPlayingFrame:0];

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

#if EXTENDED_DEBUG
- (void) audioSchedulerStartedScheduling:(AudioScheduler *)scheduler
{
	NSParameterAssert(nil != scheduler);
	NSLog(@"-audioSchedulerStartedScheduling");
}

- (void) audioSchedulerStoppedScheduling:(AudioScheduler *)scheduler
{
	NSParameterAssert(nil != scheduler);
	NSLog(@"-audioSchedulerStoppedScheduling");
}

- (void) audioSchedulerStartedSchedulingRegion:(NSDictionary *)schedulerAndRegion
{
	NSParameterAssert(nil != schedulerAndRegion);
	ScheduledAudioRegion *region = [schedulerAndRegion valueForKey:ScheduledAudioRegionObjectKey];
	NSLog(@"-audioSchedulerStartedSchedulingRegion: %@", [[region decoder] stream]);
}
#endif

- (void) audioSchedulerFinishedSchedulingRegion:(NSDictionary *)schedulerAndRegion
{
	NSParameterAssert(nil != schedulerAndRegion);

#if DEBUG
	ScheduledAudioRegion *region = [schedulerAndRegion valueForKey:ScheduledAudioRegionObjectKey];
	NSLog(@"-audioSchedulerFinishedSchedulingRegion: %@", [[region decoder] stream]);
#endif

	// Request the next stream from the library, to keep playback going
	[_owner requestNextStream];
}

- (void) audioSchedulerStartedRenderingRegion:(NSDictionary *)schedulerAndRegion
{
	NSParameterAssert(nil != schedulerAndRegion);

	ScheduledAudioRegion *region = [schedulerAndRegion valueForKey:ScheduledAudioRegionObjectKey];

#if DEBUG
	NSLog(@"-audioSchedulerStartedRenderingRegion: %@", [[region decoder] stream]);
#endif
	
	_format			= [[region decoder] format];
	_channelLayout	= [[region decoder] channelLayout];

	[self setTotalFrames:[region totalFrames]];
	
	[self willChangeValueForKey:@"hasValidStream"];
	[self didChangeValueForKey:@"hasValidStream"];	

	[self willChangeValueForKey:@"currentFrame"];
	[self setStartingFrame:0];
	[self setPlayingFrame:0];
	[self didChangeValueForKey:@"currentFrame"];
	
	if([_owner sentNextStreamRequest])
		[_owner streamPlaybackDidStart];
}

- (void) audioSchedulerFinishedRenderingRegion:(NSDictionary *)schedulerAndRegion
{
	NSParameterAssert(nil != schedulerAndRegion);

	ScheduledAudioRegion *region = [schedulerAndRegion valueForKey:ScheduledAudioRegionObjectKey];

#if DEBUG
	NSLog(@"-audioSchedulerFinishedRenderingRegion: %@", [[region decoder] stream]);
#endif
	
	memset(&_format, 0, sizeof(_format));
	memset(&_channelLayout, 0, sizeof(_channelLayout));

	// If nothing is coming up right away, stop ourselves from playing
	if(nil == [[self scheduler] regionBeingScheduled]) {
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
	else
		_regionStartingFrame += [region framesRendered];

	if(NO == [_owner sentNextStreamRequest])
		[_owner streamPlaybackDidComplete];
}

@end

@implementation AudioPlayer (AUGraphMethods)

- (OSStatus) setupAUGraph
{
	// Set up the AUGraph
	OSStatus err = NewAUGraph(&_auGraph);
	if(noErr != err)
		return err;
	
	// The graph will look like:
	// Generator -> Peak Limiter -> (any effects units) -> Output
	AUNode						generatorNode, limiterNode;
	ComponentDescription		desc;
	
	// Set up the generator node
	desc.componentType			= kAudioUnitType_Generator;
	desc.componentSubType		= kAudioUnitSubType_ScheduledSoundPlayer;
	desc.componentManufacturer	= kAudioUnitManufacturer_Apple;
	desc.componentFlags			= 0;
	desc.componentFlagsMask		= 0;
	
	err = AUGraphNewNode(_auGraph, &desc, 0, NULL, &generatorNode);
	if(noErr != err)
		return err;
	
	// Set up the peak limiter node
	desc.componentType			= kAudioUnitType_Effect;
	desc.componentSubType		= kAudioUnitSubType_PeakLimiter;
	desc.componentManufacturer	= kAudioUnitManufacturer_Apple;
	desc.componentFlags			= 0;
	desc.componentFlagsMask		= 0;
	
	err = AUGraphNewNode(_auGraph, &desc, 0, NULL, &limiterNode);
	if(noErr != err)
		return err;
	
	// Set up the equalizer node
	desc.componentType			= kAudioUnitType_Effect;
//	desc.componentSubType		= kAudioUnitSubType_DynamicsProcessor;
	desc.componentSubType		= kAudioUnitSubType_MatrixReverb;
//	desc.componentSubType		= kAudioUnitSubType_GraphicEQ;
	desc.componentManufacturer	= kAudioUnitManufacturer_Apple;
	desc.componentFlags			= 0;
	desc.componentFlagsMask		= 0;
	
//	err = AUGraphNewNode(_auGraph, &desc, 0, NULL, &effectNode);
//	if(noErr != err)
//		return err;
	
	// Set up the output node
	desc.componentType			= kAudioUnitType_Output;
	desc.componentSubType		= kAudioUnitSubType_DefaultOutput;
	desc.componentManufacturer	= kAudioUnitManufacturer_Apple;
	desc.componentFlags			= 0;
	desc.componentFlagsMask		= 0;
	
	err = AUGraphNewNode(_auGraph, &desc, 0, NULL, &_outputNode);
	if(noErr != err)
		return err;
	
	// Connect the nodes
	err = AUGraphConnectNodeInput(_auGraph, generatorNode, 0, limiterNode, 0);
	if(noErr != err)
		return err;
	
//	err = AUGraphConnectNodeInput(_auGraph, limiterNode, 0, effectNode, 0);
//	if(noErr != err)
//		return err;
	
//	err = AUGraphConnectNodeInput(_auGraph, effectNode, 0, _outputNode, 0);
	err = AUGraphConnectNodeInput(_auGraph, limiterNode, 0, _outputNode, 0);
	if(noErr != err)
		return err;
	
	// Open the graph
	err = AUGraphOpen(_auGraph);
	if(noErr != err)
		return err;
	
	// Initialize the graph
	err = AUGraphInitialize(_auGraph);
	if(noErr != err)
		return err;
	
	// And start it up
	err = AUGraphStart(_auGraph);
	if(noErr != err)
		return err;
	
	// Store the audio units for later  use
	err = AUGraphGetNodeInfo(_auGraph, generatorNode, NULL, NULL, NULL, &_generatorUnit);
	if(noErr != err)
		return err;
	
	err = AUGraphGetNodeInfo(_auGraph, limiterNode, NULL, NULL, NULL, &_limiterUnit);
	if(noErr != err)
		return err;
	
	err = AUGraphGetNodeInfo(_auGraph, _outputNode, NULL, NULL, NULL, &_outputUnit);
	if(noErr != err)
		return err;
	
	return noErr;
}

- (OSStatus) teardownAUGraph
{
	Boolean graphIsRunning = NO;
	OSStatus err = AUGraphIsRunning(_auGraph, &graphIsRunning);
	if(noErr != err)
		return err;
	
	if(graphIsRunning) {
		err = AUGraphStop(_auGraph);
		if(noErr != err)
			return err;
	}
	
	Boolean graphIsInitialized = NO;	
	err = AUGraphIsInitialized(_auGraph, &graphIsInitialized);
	if(noErr != err)
		return err;
	
	if(graphIsInitialized) {
		err = AUGraphUninitialize(_auGraph);
		if(noErr != err)
			return err;
	}
	
	err = AUGraphClose(_auGraph);
	if(noErr != err)
		return err;
	
	err = DisposeAUGraph(_auGraph);
	if(noErr != err)
		return err;
	
	_auGraph			= NULL;
	_generatorUnit		= NULL;
	_limiterUnit		= NULL;
	_outputUnit			= NULL;
	
	return noErr;
}

- (OSStatus) setAUGraphFormat:(AudioStreamBasicDescription)format
{	
	// If the graph is running, stop it
	Boolean graphIsRunning = NO;
	OSStatus err = AUGraphIsRunning(_auGraph, &graphIsRunning);
	if(noErr != err)
		return err;
	
	if(graphIsRunning) {
		err = AUGraphStop(_auGraph);
		if(noErr != err)
			return err;
	}
	
	// If the graph is initialized, uninitialize it
	Boolean graphIsInitialized = NO;
	err = AUGraphIsInitialized(_auGraph, &graphIsInitialized);
	if(noErr != err)
		return err;
	
	if(graphIsInitialized) {
		err = AUGraphUninitialize(_auGraph);
		if(noErr != err)
			return err;
	}
	
	// Save the connection information and then disconnect all the graph's connections
	UInt32 connectionCount;
	err = AUGraphGetNumberOfConnections(_auGraph, &connectionCount);
	if(noErr != err)
		return err;
	
	AudioUnitNodeConnection *connections = calloc(connectionCount, sizeof(AudioUnitNodeConnection));
	NSAssert(NULL != connections, @"Unable to allocate memory");
	
	unsigned i;
	for(i = 0; i < connectionCount; ++i) {
		err = AUGraphGetConnectionInfo(_auGraph, i,
									   &connections[i].sourceNode, &connections[i].sourceOutputNumber,
									   &connections[i].destNode, &connections[i].destInputNumber);
		if(noErr != err)
			return err;
	}
	
	err = AUGraphClearConnections(_auGraph);
	if(noErr != err)
		return err;
	
	UInt32 nodeCount;
	err = AUGraphGetNodeCount(_auGraph, &nodeCount);
	if(noErr != err)
		return err;
	
	// OK - now we go through and set the sample rate on each connection...
	for(i = 0; i < nodeCount; ++i) {
		AUNode node;
		err = AUGraphGetIndNode(_auGraph, i, &node);
		if(noErr != err)
			return err;
		
		AudioUnit au;
		err = AUGraphGetNodeInfo(_auGraph, node, NULL, NULL, NULL, &au);
		if(noErr != err)
			return err;
		
		if(_outputNode == node) {
			// this is for AUHAL as the output node. You can't set the device side here, so you just set the client side
			err = AudioUnitSetProperty(au, 
									   kAudioUnitProperty_StreamFormat,
									   kAudioUnitScope_Input, 
									   0, 
									   &format, 
									   sizeof(format));
			if(noErr != err)
				return err;
			
			// IO must be enabled for this to work
			/*			err = AudioUnitSetProperty(au, 
				kAudioUnitProperty_SampleRate,
				kAudioUnitScope_Output, 
				1, 
				&sampleRate, 
				sizeof(sampleRate));
if(noErr != err)
return err;	*/
		}
		else {
			UInt32 elementCount = 0;
			UInt32 dataSize = sizeof(elementCount);
			
			err = AudioUnitGetProperty(au, 
									   kAudioUnitProperty_ElementCount,
									   kAudioUnitScope_Input, 
									   0, 
									   &elementCount, 
									   &dataSize);
			if(noErr != err)
				return err;
			
			unsigned j;
			for(j = 0; j < elementCount; ++j) {
				err = AudioUnitSetProperty(au, 
										   kAudioUnitProperty_StreamFormat,
										   kAudioUnitScope_Input, 
										   j, 
										   &format, 
										   sizeof(format));
				if(noErr != err)
					return err;
			}
			
			elementCount = 0;
			dataSize = sizeof(elementCount);
			
			err = AudioUnitGetProperty(au, 
									   kAudioUnitProperty_ElementCount,
									   kAudioUnitScope_Output, 
									   0, 
									   &elementCount, 
									   &dataSize);
			if(noErr != err)
				return err;
			
			for(j = 0; j < elementCount; ++j) {
				err = AudioUnitSetProperty(au, 
										   kAudioUnitProperty_StreamFormat,
										   kAudioUnitScope_Output, 
										   j, 
										   &format, 
										   sizeof(format));
				if(noErr != err)
					return err;
			}
		}
	}
	
	for(i = 0; i < connectionCount; ++i) {
		// ok, now we can connect this up again
		err = AUGraphConnectNodeInput(_auGraph, 
									  connections[i].sourceNode, connections[i].sourceOutputNumber,
									  connections[i].destNode, connections[i].destInputNumber);
		if(noErr != err)
			return err;
	}
	
	// If the graph was initialized, reinitialize it
	if(graphIsInitialized) {
		err = AUGraphInitialize(_auGraph);
		if(noErr != err)
			return err;
	}
	
	// If the graph was running, restart it
	if(graphIsRunning) {
		err = AUGraphStart(_auGraph);
		if(noErr != err)
			return err;
	}
	
	free(connections);
	
	return noErr;
}

- (OSStatus) setAUGraphChannelLayout:(AudioChannelLayout)channelLayout
{
	return noErr;	
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
	OSStatus result = AUGraphIsInitialized(_auGraph, &graphIsInitialized);
	if(noErr != result)
		return NO;
	
	return (graphIsInitialized/* && [[self scheduler] isScheduling]*/);
}

- (void) uiTimerFireMethod:(NSTimer *)theTimer
{
	if(NO == [[self scheduler] isScheduling] || NO == [self isPlaying])
		return;
	
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
		status = AudioUnitSetProperty(_outputUnit,
									  kAudioOutputUnitProperty_CurrentDevice,
									  kAudioUnitScope_Global,
									  0,
									  &deviceID,
									  sizeof(deviceID));
	}
	
	if(noErr != status)
		NSLog(@"Error setting output device");
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
			double	multiplier	= pow(10, adjustment / 20);
			float	sample		= peakSample * multiplier;
			float	magnitude	= fabsf(sample);
			
			// If clipping will occur, reduce the preamp gain so the peak will be +/- 1.0
			if(1.0 < magnitude) {
				[self setPreAmplification:(20 * log10(1.0 / peakSample)) - [self replayGain]];
			}
		}
	}
	
	if([self hasReplayGain]) {
		AudioUnitParameter auParameter;
		
		auParameter.mAudioUnit		= _limiterUnit;
		auParameter.mParameterID	= 2;
		auParameter.mScope			= kAudioUnitScope_Global;
		auParameter.mElement		= 0;
		
		OSStatus err = AUParameterSet(NULL, NULL, &auParameter, [self preAmplification] + [self replayGain], 0);
		if(noErr != err)
			NSLog(@"Error settting RG");
	}
}

- (NSNumber *) setReplayGainForStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	
	int				replayGain		= [[NSUserDefaults standardUserDefaults] integerForKey:@"replayGain"];
	NSNumber		*trackGain		= [stream valueForKey:ReplayGainTrackGainKey];
	NSNumber		*albumGain		= [stream valueForKey:ReplayGainAlbumGainKey];
	
	// Try to use the RG the user wants
	if(ReplayGainTrackGain == replayGain && nil != trackGain) {
		[self setReplayGain:[trackGain doubleValue]];
		[self setHasReplayGain:YES];
		return [stream valueForKey:ReplayGainTrackPeakKey];
	}
	else if(ReplayGainAlbumGain == replayGain && nil != albumGain) {
		[self setReplayGain:[albumGain doubleValue]];
		[self setHasReplayGain:YES];
		return [stream valueForKey:ReplayGainAlbumPeakKey];
	}
	// Fall back to any gain if present
	else if(ReplayGainNone != replayGain && nil != trackGain) {
		[self setReplayGain:[trackGain doubleValue]];
		[self setHasReplayGain:YES];
		return [stream valueForKey:ReplayGainTrackPeakKey];
	}
	else if(ReplayGainNone != replayGain && nil != albumGain) {
		[self setReplayGain:[albumGain doubleValue]];
		[self setHasReplayGain:YES];
		return [stream valueForKey:ReplayGainAlbumPeakKey];
	}

	// No dice, or RG set to off
	[self setReplayGain:0];
	[self setHasReplayGain:NO];
	return nil;
}

@end
