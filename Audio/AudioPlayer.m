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
#import "AudioLibrary.h"
#import "AudioStream.h"
#import "AudioStreamDecoder.h"

#include <CoreServices/CoreServices.h>
#include <CoreAudio/CoreAudio.h>

static BOOL
channelLayoutsAreEqual(AudioChannelLayout *layoutA,
					   AudioChannelLayout *layoutB)
{
	// First check if the tags are equal
	if(layoutA->mChannelLayoutTag != layoutB->mChannelLayoutTag) {
		return NO;
	}
	
	// If the tags are equal, check for special values
	if(kAudioChannelLayoutTag_UseChannelBitmap == layoutA->mChannelLayoutTag) {
		return (layoutA->mChannelBitmap == layoutB->mChannelBitmap);
	}

	if(kAudioChannelLayoutTag_UseChannelDescriptions == layoutA->mChannelLayoutTag) {
		if(layoutA->mNumberChannelDescriptions != layoutB->mNumberChannelDescriptions) {
			return NO;
		}
		
		unsigned bytesToCompare = layoutA->mNumberChannelDescriptions * sizeof(AudioChannelDescription);
		return (0 == memcmp(&layoutA->mChannelDescriptions, &layoutB->mChannelDescriptions, bytesToCompare));
	}
	
	return YES;
}

NSString *const AudioPlayerErrorDomain = @"org.sbooth.Play.ErrorDomain.AudioPlayer";

// ========================================
// AudioPlayer callbacks
// ========================================
@interface AudioLibrary (AudioPlayerCallbackMethods)
- (void) streamPlaybackDidStart;
- (void) streamPlaybackDidComplete;
- (void) requestNextStream;
@end

@interface AudioPlayer (Private)
- (AudioUnit) audioUnit;

- (NSFormatter *) secondsFormatter;

- (NSRunLoop *) runLoop;

- (AudioStreamDecoder *) streamDecoder;
- (void) setStreamDecoder:(AudioStreamDecoder *)streamDecoder;

- (AudioStreamDecoder *) nextStreamDecoder;
- (void) setNextStreamDecoder:(AudioStreamDecoder *)nextStreamDecoder;

//- (void) didReachEndOfStream:(id)arg;
- (void) didReachEndOfStream;
//- (void) didReadFrames:(NSNumber *)frameCount;
- (void) didReadFrames:(UInt32)frameCount;

- (void) didStartUsingNextStreamDecoder;
- (void) currentFrameNeedsUpdate;

- (void) setPlaying:(BOOL)playing;
- (void) setOutputDeviceUID:(NSString *)deviceUID;

- (Float32) actualVolume;
- (void) setActualVolume:(Float32)volume;

- (void) setReplayGainForStream:(AudioStream *)stream;
@end

#if DEBUG
static void dumpASBD(const AudioStreamBasicDescription *asbd)
{
	NSLog(@"mSampleRate         %f", asbd->mSampleRate);
	NSLog(@"mFormatID           %.4s", (const char *)(&asbd->mFormatID));
	NSLog(@"mFormatFlags        %u", asbd->mFormatFlags);
	NSLog(@"mBytesPerPacket     %u", asbd->mBytesPerPacket);
	NSLog(@"mFramesPerPacket    %u", asbd->mFramesPerPacket);
	NSLog(@"mBytesPerFrame      %u", asbd->mBytesPerFrame);
	NSLog(@"mChannelsPerFrame   %u", asbd->mChannelsPerFrame);
	NSLog(@"mBitsPerChannel     %u", asbd->mBitsPerChannel);
	NSLog(@"mReserved           %u", asbd->mReserved);
}
#endif

// ========================================
// AudioUnit render function
// Thin wrapper around an AudioStreamDecoder
// This function will not be called from the main thread
// Since bindings are not thread safe, make sure all calls back to the player
// are done on the main thread
OSStatus	
MyRenderer(void							*inRefCon, 
		   AudioUnitRenderActionFlags 	*ioActionFlags, 
		   const AudioTimeStamp 		*inTimeStamp, 
		   UInt32 						inBusNumber, 
		   UInt32 						inNumberFrames, 
		   AudioBufferList				*ioData)

{
	NSAutoreleasePool	*pool				= [[NSAutoreleasePool alloc] init];
	AudioPlayer			*player				= (AudioPlayer *)inRefCon;
	AudioStreamDecoder	*streamDecoder		= [player streamDecoder];
	UInt32				currentBuffer;
	
	if(nil == streamDecoder) {
		*ioActionFlags = kAudioUnitRenderAction_OutputIsSilence;
		
		for(currentBuffer = 0; currentBuffer < ioData->mNumberBuffers; ++currentBuffer) {
			memset(ioData->mBuffers[currentBuffer].mData, 0, ioData->mBuffers[currentBuffer].mDataByteSize);
		}
		
		[pool release];
		return noErr;
	}
	
	UInt32 originalBufferSize	= ioData->mBuffers[0].mDataByteSize;
	UInt32 framesRead			= [streamDecoder readAudio:ioData frameCount:inNumberFrames];
		
	// If this stream is finished, roll straight into the next one if possible
	if(framesRead != inNumberFrames && [streamDecoder atEndOfStream] && nil != [player nextStreamDecoder]) {
		AudioBufferList			additionalData;
		UInt32					additionalFramesRead;
		UInt32					bufferSizeAfterFirstRead;

		[player didStartUsingNextStreamDecoder];
		
		streamDecoder								= [player streamDecoder];
		
		bufferSizeAfterFirstRead					= ioData->mBuffers[0].mDataByteSize;
		additionalData.mNumberBuffers				= 1;
		additionalData.mBuffers[0].mData			= ioData->mBuffers[0].mData + ioData->mBuffers[0].mDataByteSize;
		additionalData.mBuffers[0].mDataByteSize	= originalBufferSize - ioData->mBuffers[0].mDataByteSize;
		
		additionalFramesRead	= [streamDecoder readAudio:&additionalData frameCount:inNumberFrames - framesRead];
		
		ioData->mBuffers[0].mDataByteSize			= bufferSizeAfterFirstRead + additionalData.mBuffers[0].mDataByteSize;

		framesRead									+= additionalFramesRead;
	}
	
#if DEBUG
	if(framesRead != inNumberFrames) {
		NSLog(@"MyRenderer requested %i frames, got %i", inNumberFrames, framesRead);
	}
#endif
	
	if(0 == framesRead) {
		*ioActionFlags = kAudioUnitRenderAction_OutputIsSilence;
		
		for(currentBuffer = 0; currentBuffer < ioData->mNumberBuffers; ++currentBuffer) {
			memset(ioData->mBuffers[currentBuffer].mData, 0, ioData->mBuffers[currentBuffer].mDataByteSize);
		}
		
		if([streamDecoder atEndOfStream]) {
			[player didReachEndOfStream];
//			[[player runLoop] performSelector:@selector(didReachEndOfStream:) 
//									   target:player 
//									 argument:nil 
//										order:0
//										modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
		}
	}
	
	[pool release];
	
	return noErr;
}

static OSStatus
MyRenderNotification(void							*inRefCon, 
					 AudioUnitRenderActionFlags      *ioActionFlags,
					 const AudioTimeStamp            *inTimeStamp, 
					 UInt32                          inBusNumber,
					 UInt32                          inNumFrames, 
					 AudioBufferList                 *ioData)
{
	NSAutoreleasePool	*pool		= [[NSAutoreleasePool alloc] init];
	AudioPlayer			*player		= (AudioPlayer *)inRefCon;
	
	if(kAudioUnitRenderAction_PostRender & (*ioActionFlags)) {

		[player didReadFrames:inNumFrames];
//		[[player runLoop] performSelector:@selector(didReadFrames:) 
//								   target:player 
//								 argument:[NSNumber numberWithUnsignedInt:inNumFrames]
//									order:0
//									modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSEventTrackingRunLoopMode, nil]];
	}
	
	[pool release];
	
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
	
	[self setKeys:[NSArray arrayWithObject:@"streamDecoder"] triggerChangeNotificationsForDependentKey:@"hasValidStream"];
	[self setKeys:[NSArray arrayWithObject:@"hasValidStream"] triggerChangeNotificationsForDependentKey:@"streamSupportsSeeking"];

	[self setKeys:[NSArray arrayWithObject:@"hasValidStream"] triggerChangeNotificationsForDependentKey:@"currentFrame"];
	[self setKeys:[NSArray arrayWithObject:@"hasValidStream"] triggerChangeNotificationsForDependentKey:@"totalFrames"];

	[self setKeys:[NSArray arrayWithObject:@"currentFrame"] triggerChangeNotificationsForDependentKey:@"currentSecondString"];
	[self setKeys:[NSArray arrayWithObject:@"currentFrame"] triggerChangeNotificationsForDependentKey:@"secondsRemainingString"];
	[self setKeys:[NSArray arrayWithObject:@"totalFrames"] triggerChangeNotificationsForDependentKey:@"totalSecondsString"];
	
}

- (id) init
{
	if((self = [super init])) {
		ComponentDescription		desc;
		AURenderCallbackStruct		input;
		
		desc.componentType			= kAudioUnitType_Output;
		desc.componentSubType		= kAudioUnitSubType_DefaultOutput;
		desc.componentManufacturer	= kAudioUnitManufacturer_Apple;
		desc.componentFlags			= 0;
		desc.componentFlagsMask		= 0;
		
		Component comp = FindNextComponent(NULL, &desc);
		if(NULL == comp) {
			[self release];
			return nil;
		}
				
		OSStatus err = OpenAComponent(comp, &_audioUnit);
		if(noErr != err || NULL == comp) {
			[self release];
			return nil;
		}
		
		// Set up a callback function to generate output to the output unit
		input.inputProc				= MyRenderer;
		input.inputProcRefCon		= (void *)self;
		
		err = AudioUnitSetProperty(_audioUnit, 
								   kAudioUnitProperty_SetRenderCallback, 
								   kAudioUnitScope_Input,
								   0, 
								   &input, 
								   sizeof(input));
		if(noErr != err) {
			CloseComponent(_audioUnit);
			[self release];
			return nil;
		}
			
		ComponentResult result = AudioUnitInitialize(_audioUnit);
		if(noErr != result) {
			CloseComponent(_audioUnit);
			[self release];
			return nil;
		}
		
		AudioUnitAddRenderNotify(_audioUnit, MyRenderNotification, (void *)self);

		_secondsFormatter	= [[SecondsFormatter alloc] init];
		_runLoop			= [[NSRunLoop currentRunLoop] retain];
		
		// Set the output device
		[self setOutputDeviceUID:[[NSUserDefaults standardUserDefaults] objectForKey:@"outputAudioDeviceUID"]];

		_baseVolume = [self actualVolume];

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
	[self stop];

	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self 
																 forKeyPath:@"values.outputAudioDeviceUID"];
	
	ComponentResult result = AudioUnitUninitialize(_audioUnit);
	if(noErr != result) {
		NSLog(@"AudioUnitUninitialize failed: %ld", result);
	}
	
	CloseComponent(_audioUnit), _audioUnit = NULL;

	if(nil != [self streamDecoder]) {
		[[self streamDecoder] stopDecoding:nil];
		[_streamDecoder release],		_streamDecoder = nil;
	}
	
	[_secondsFormatter release], _secondsFormatter = nil;
	[_runLoop release], _runLoop = nil;
	
	[super dealloc];
}

- (AudioLibrary *)		owner									{ return _owner; }
- (void)				setOwner:(AudioLibrary *)owner			{ _owner = owner; }

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if(object == [NSUserDefaultsController sharedUserDefaultsController] && [keyPath isEqualToString:@"values.outputAudioDeviceUID"]) {
		[self setOutputDeviceUID:[[NSUserDefaults standardUserDefaults] objectForKey:@"outputAudioDeviceUID"]];
	}
}


#pragma mark Stream Management

- (BOOL) setStream:(AudioStream *)stream error:(NSError **)error
{
	NSParameterAssert(nil != stream);
	
	if(nil != [self nextStreamDecoder]) {
		[[self nextStreamDecoder] stopDecoding:error];
		[self setNextStreamDecoder:nil];
	}

	if(nil != [self streamDecoder]) {
		[[self streamDecoder] stopDecoding:error];
		[self setStreamDecoder:nil];
	}
	
	_requestedNextStream = NO;
	
	AudioStreamDecoder *streamDecoder = [AudioStreamDecoder streamDecoderForStream:stream error:error];
	if(nil == streamDecoder) {
		return NO;
	}
	
	[self willChangeValueForKey:@"totalFrames"];
	[self willChangeValueForKey:@"currentFrame"];
	
	[self setStreamDecoder:streamDecoder];
	BOOL startedDecoding = [[self streamDecoder] startDecoding:error];
	
	[self didChangeValueForKey:@"totalFrames"];
	[self didChangeValueForKey:@"currentFrame"];
	
	if(NO == startedDecoding) {
		return NO;
	}
	
	// Set the PCM format we will feed to the AudioUnit
	AudioStreamBasicDescription		pcmFormat	= [[self streamDecoder] pcmFormat];
	ComponentResult					result		= AudioUnitSetProperty([self audioUnit],
																	   kAudioUnitProperty_StreamFormat,
																	   kAudioUnitScope_Input,
																	   0,
																	   &pcmFormat,
																	   sizeof(AudioStreamBasicDescription));
	
	if(noErr != result) {
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
		
		return NO;
	}

	// And the channel layout as well
	if([[self streamDecoder] hasChannelLayout]) {
		AudioChannelLayout channelLayout = [[self streamDecoder] channelLayout];
		
		result = AudioUnitSetProperty([self audioUnit],
									  kAudioUnitProperty_AudioChannelLayout,
									  kAudioUnitScope_Input,
									  0,
									  &channelLayout,
									  sizeof(AudioChannelLayout));
	}
	else {
		result = AudioUnitSetProperty([self audioUnit],
									  kAudioUnitProperty_AudioChannelLayout,
									  kAudioUnitScope_Input,
									  0,
									  NULL,
									  0);
	}
	
	if(noErr != result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [[stream valueForKey:StreamURLKey] path];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The format of the file \"%@\" is not supported.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"File Format Not Supported", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file contains an unsupported audio channel layout.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:AudioPlayerErrorDomain 
										 code:AudioPlayerInternalError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	[self setReplayGainForStream:stream];
	
	return YES;
}

- (BOOL) setNextStream:(AudioStream *)stream error:(NSError **)error
{
	NSParameterAssert(nil != stream);

	AudioStreamBasicDescription		pcmFormat, nextPCMFormat;
	AudioChannelLayout				channelLayout, nextChannelLayout;
		
	AudioStreamDecoder *streamDecoder = [AudioStreamDecoder streamDecoderForStream:stream error:error];	
	if(nil == streamDecoder) {
		return NO;
	}
	
	[self setNextStreamDecoder:streamDecoder];
	[[self nextStreamDecoder] startDecoding:error];
	
	pcmFormat		= [[self streamDecoder] pcmFormat];
	nextPCMFormat	= [[self nextStreamDecoder] pcmFormat];

	channelLayout		= [[self streamDecoder] channelLayout];
	nextChannelLayout	= [[self nextStreamDecoder] channelLayout];

	BOOL pcmFormatsMatch		= (0 == memcmp(&pcmFormat, &nextPCMFormat, sizeof(AudioStreamBasicDescription)));
	BOOL channelLayoutsMatch	= channelLayoutsAreEqual(&channelLayout, &nextChannelLayout);

	// We can only join the two files if they have the same formats (mSampleRate, etc) and channel layouts
	if(NO == pcmFormatsMatch || NO == channelLayoutsMatch) {

#if DEBUG
		if(NO == pcmFormatsMatch) {
			NSLog(@"Unable to join buffers for gapless playback, PCM formats don't match");
//			dumpASBD(&pcmFormat);
//			dumpASBD(&nextPCMFormat);
		}

		if(NO == channelLayoutsMatch) {
			NSLog(@"Unable to join buffers for gapless playback, channel layouts don't match");
		}
#endif
		
		[[self nextStreamDecoder] stopDecoding:error];
		[self setNextStreamDecoder:nil];
		
		return NO;
	}
	
	return YES;
}

- (void) reset
{
	[self willChangeValueForKey:@"totalFrames"];
	[self willChangeValueForKey:@"currentFrame"];
	
	[self setStreamDecoder:nil];
	[self setNextStreamDecoder:nil];
	_requestedNextStream = NO;

	[self didChangeValueForKey:@"totalFrames"];
	[self didChangeValueForKey:@"currentFrame"];
}

- (BOOL) hasValidStream
{
	return (nil != [self streamDecoder]);
}

- (BOOL) streamSupportsSeeking
{
	return ([self hasValidStream] && [[self streamDecoder] supportsSeeking]);
}

#pragma mark Playback Control

- (void) play
{
	ComponentResult result = AudioOutputUnitStart([self audioUnit]);	
	if(noErr != result) {
		NSLog(@"Unable to start the AudioUnit");
	}
	
	[self setPlaying:YES];
}

- (void) playPause
{
	if([self isPlaying]) {
		[self stop];
	}
	else {
		[self play];
	}
}

- (void) stop
{
	ComponentResult result = AudioOutputUnitStop([self audioUnit]);	
	if(noErr != result) {
		NSLog(@"Unable to stop the AudioUnit");
	}

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
	AudioStreamDecoder *streamDecoder = [self streamDecoder];
	
	if(nil != streamDecoder && [streamDecoder supportsSeeking]) {
		SInt64 totalFrames		= [streamDecoder totalFrames];
		SInt64 currentFrame		= [streamDecoder currentFrame];
		SInt64 desiredFrame		= currentFrame + (SInt64)(seconds * [streamDecoder pcmFormat].mSampleRate);
		
		if(totalFrames < desiredFrame) {
			desiredFrame = totalFrames;
		}
		
		[self setCurrentFrame:desiredFrame];
	}	
}

- (void) skipBackward:(UInt32)seconds
{
	AudioStreamDecoder *streamDecoder = [self streamDecoder];
	
	if(nil != streamDecoder && [streamDecoder supportsSeeking]) {
		SInt64 currentFrame		= [streamDecoder currentFrame];
		SInt64 desiredFrame		= currentFrame - (SInt64)(seconds * [streamDecoder pcmFormat].mSampleRate);
		
		if(0 > desiredFrame) {
			desiredFrame = 0;
		}
		
		[self setCurrentFrame:desiredFrame];
	}
}

- (void) skipToEnd
{
	AudioStreamDecoder *streamDecoder = [self streamDecoder];
	
	if(nil != streamDecoder && [streamDecoder supportsSeeking]) {
		SInt64 totalFrames = [streamDecoder totalFrames];		
		[self setCurrentFrame:totalFrames - 1];
	}
}

- (void) skipToBeginning
{
	AudioStreamDecoder *streamDecoder = [self streamDecoder];
	if(nil != streamDecoder && [streamDecoder supportsSeeking]) {
		[self setCurrentFrame:0];
	}
}

- (BOOL) isPlaying
{
	return _playing;
}

#pragma mark Bindings

- (Float32) baseVolume
{
	return _baseVolume;	
}

- (void) setBaseVolume:(Float32)baseVolume
{
	NSParameterAssert(0 <= baseVolume <= 1);
	
	_baseVolume = baseVolume;
	
	[self setActualVolume:[self baseVolume] * pow(10, [self replayGain] / 20)];
}

- (double) replayGain
{
	return _replayGain;
}

- (void) setReplayGain:(double)replayGain
{
	_replayGain = replayGain;
	
	[self setActualVolume:[self baseVolume] * pow(10, [self replayGain] / 20)];
}

- (SInt64) totalFrames
{
	SInt64				result				= -1;
	AudioStreamDecoder	*streamDecoder		= [self streamDecoder];
	
	if(nil != streamDecoder) {
		result = [streamDecoder totalFrames];
	}
	
	return result;
}

- (SInt64) currentFrame
{
	SInt64				result				= -1;
	AudioStreamDecoder	*streamDecoder		= [self streamDecoder];
	
	if(nil != streamDecoder) {
		result = [streamDecoder currentFrame];
	}
	
	return result;
}

- (void) setCurrentFrame:(SInt64)currentFrame
{
	AudioStreamDecoder *streamDecoder = [self streamDecoder];
	
	if(nil != streamDecoder) {
		BOOL playing = [self isPlaying];
		
		if(playing) {
			[self stop];
		}
		
#if DEBUG
		SInt64 seekedFrame = 
#endif
			[streamDecoder seekToFrame:currentFrame];

#if DEBUG
		if(seekedFrame != currentFrame) {
			NSLog(@"Seek failed: requested frame %qi, got %qi", currentFrame, seekedFrame);
		}
#endif
		
		if(nil != [self nextStreamDecoder]) {
			/*BOOL result = */ [[self nextStreamDecoder] stopDecoding:nil];
			[self setNextStreamDecoder:nil];
			_requestedNextStream = NO;
		}
		
		if(playing) {
			[self play];
		}
	}
}

- (NSString *) totalSecondsString
{
	NSString			*result			= nil;
	NSTimeInterval		timeInterval	= 0.0;
	AudioStreamDecoder	*streamDecoder	= [self streamDecoder];
	
	if(nil != streamDecoder) {
		timeInterval	= (NSTimeInterval) ([streamDecoder totalFrames] / [streamDecoder pcmFormat].mSampleRate);				
		result			= [[self secondsFormatter] stringForObjectValue:[NSNumber numberWithDouble:timeInterval]];
	}
	
	return result;
}

- (NSString *) currentSecondString
{
	NSString			*result			= nil;
	NSTimeInterval		timeInterval	= 0.0;
	AudioStreamDecoder	*streamDecoder	= [self streamDecoder];
	
	if(nil != streamDecoder) {
		timeInterval	= (NSTimeInterval) ([streamDecoder currentFrame] / [streamDecoder pcmFormat].mSampleRate);		
		result			= [[self secondsFormatter] stringForObjectValue:[NSNumber numberWithDouble:timeInterval]];
	}
	
	return result;
}

- (NSString *) secondsRemainingString
{
	NSString			*result			= nil;
	NSTimeInterval		timeInterval	= 0.0;
	AudioStreamDecoder	*streamDecoder	= [self streamDecoder];
	
	if(nil != streamDecoder) {
		timeInterval	= (NSTimeInterval) ([streamDecoder framesRemaining] / [streamDecoder pcmFormat].mSampleRate);
		result			= [[self secondsFormatter] stringForObjectValue:[NSNumber numberWithDouble:timeInterval]];
	}
	
	return result;
}

@end

@implementation AudioPlayer (Private)

- (AudioUnit) audioUnit
{
	return _audioUnit;
}

- (NSFormatter *) secondsFormatter
{
	return _secondsFormatter;
}

- (NSRunLoop *)	runLoop
{
	return _runLoop;
}

- (AudioStreamDecoder *) streamDecoder
{
	return _streamDecoder;
}

- (void) setStreamDecoder:(AudioStreamDecoder *)streamDecoder
{
	[_streamDecoder release];
	_streamDecoder = [streamDecoder retain];
}

- (AudioStreamDecoder *) nextStreamDecoder
{
	return _nextStreamDecoder;
}

- (void) setNextStreamDecoder:(AudioStreamDecoder *)nextStreamDecoder
{
	[_nextStreamDecoder release];
	_nextStreamDecoder = [nextStreamDecoder retain];
}

//- (void) didReachEndOfStream:(id)arg
- (void) didReachEndOfStream
{
	[self stop];
//	[_owner streamPlaybackDidComplete];
	[_owner performSelectorOnMainThread:@selector(streamPlaybackDidComplete) withObject:nil waitUntilDone:NO];
}

//- (void) didReadFrames:(NSNumber *)frameCount
- (void) didReadFrames:(UInt32)frameCount
{
	NSTimeInterval			seconds, secondsRemaining;
	
	// Accumulate the frames for UI updates approx. once per second
//	_frameCounter			+= [frameCount unsignedIntValue];
	_frameCounter			+= frameCount;
	seconds					= (NSTimeInterval) (_frameCounter / [[self streamDecoder] pcmFormat].mSampleRate);
	secondsRemaining		= (NSTimeInterval) ([[self streamDecoder] framesRemaining] / [[self streamDecoder] pcmFormat].mSampleRate);

	if(2.0 > secondsRemaining && nil == [self nextStreamDecoder] && NO == _requestedNextStream) {
		_requestedNextStream = YES;
		[_owner performSelectorOnMainThread:@selector(requestNextStream) withObject:nil waitUntilDone:NO];
	}
	
	if(1.0 < seconds) {
//		[self currentFrameNeedsUpdate];
		[self performSelectorOnMainThread:@selector(currentFrameNeedsUpdate) withObject:nil waitUntilDone:NO];
		_frameCounter = 0;
	}
}


- (void) didStartUsingNextStreamDecoder
{
	[_owner performSelectorOnMainThread:@selector(streamPlaybackDidComplete) withObject:nil waitUntilDone:NO];
	[self setStreamDecoder:[self nextStreamDecoder]];
	[self setNextStreamDecoder:nil];
	_requestedNextStream = NO;
	
	[self setReplayGainForStream:[[self streamDecoder] stream]];
	
	[_owner performSelectorOnMainThread:@selector(streamPlaybackDidStart) withObject:nil waitUntilDone:NO];
}

- (void) currentFrameNeedsUpdate
{
	[self willChangeValueForKey:@"currentFrame"];
	[self didChangeValueForKey:@"currentFrame"];	
}

- (void) setPlaying:(BOOL)playing
{
	_playing = playing;
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
		status = AudioUnitSetProperty(_audioUnit,
									  kAudioOutputUnitProperty_CurrentDevice,
									  kAudioUnitScope_Global,
									  0,
									  &deviceID,
									  sizeof(deviceID));
	}
	
	if(noErr != status) {
		NSLog(@"Error setting output device");
	}
	
}


- (Float32) actualVolume
{
	Float32				volume		= 0;	
	ComponentResult		result		= AudioUnitGetParameter([self audioUnit],
															kHALOutputParam_Volume,
															kAudioUnitScope_Global,
															0,
															&volume);
	
	if(noErr != result) {
		NSLog(@"Unable to determine volume");
	}
	
	return volume;
}

- (void) setActualVolume:(Float32)volume
{
	ComponentResult result =  AudioUnitSetParameter([self audioUnit],
													kHALOutputParam_Volume,
													kAudioUnitScope_Global,
													0,
													volume,
													0);
	if(noErr != result) {
		NSLog(@"Unable to set volume");
	}
}

- (void) setReplayGainForStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	
	int				replayGain		= [[NSUserDefaults standardUserDefaults] integerForKey:@"replayGain"];
	NSNumber		*trackGain		= [stream valueForKey:ReplayGainTrackGainKey];
	NSNumber		*albumGain		= [stream valueForKey:ReplayGainAlbumGainKey];
	
	// Try to use the RG the user wants
	if(ReplayGainTrackGain == replayGain && nil != trackGain) {
		[self setReplayGain:[trackGain doubleValue]];
	}
	else if(ReplayGainAlbumGain == replayGain && nil != albumGain) {
		[self setReplayGain:[albumGain doubleValue]];
	}
	// Fall back to any gain if present
	else if(ReplayGainNone != replayGain && nil != trackGain) {
		[self setReplayGain:[trackGain doubleValue]];
	}
	else if(ReplayGainNone != replayGain && nil != albumGain) {
		[self setReplayGain:[albumGain doubleValue]];
	}
	// No dice, or RG set to off
	else {
		[self setReplayGain:0];
	}
}

@end
