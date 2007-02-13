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

@interface AudioPlayer (Private)

- (AudioUnit)			audioUnit;

- (NSFormatter *)		secondsFormatter;

- (NSRunLoop *)			runLoop;

- (AudioStreamDecoder *) streamDecoder;
- (void)				setStreamDecoder:(AudioStreamDecoder *)streamDecoder;

- (AudioStreamDecoder *) nextStreamDecoder;
- (void)				setNextStreamDecoder:(AudioStreamDecoder *)nextStreamDecoder;

//- (void)				didReachEndOfStream:(id)arg;
- (void)				didReachEndOfStream;
//- (void)				didReadFrames:(NSNumber *)frameCount;
- (void)				didReadFrames:(UInt32)frameCount;

- (void)				didStartUsingNextStreamDecoder;

- (void)				currentFrameNeedsUpdate;

- (void)				setPlaying:(BOOL)playing;

@end

#if DEBUG
static void dumpASBD(const AudioStreamBasicDescription *asbd)
{
	NSLog(@"====================");
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
	NSAutoreleasePool		*pool;
	AudioPlayer				*player;
	AudioStreamDecoder		*streamDecoder;
	UInt32					framesRead, currentBuffer, originalBufferSize;

	pool					= [[NSAutoreleasePool alloc] init];
	player					= (AudioPlayer *)inRefCon;
	streamDecoder			= [player streamDecoder];
	
	if(nil == streamDecoder) {
		*ioActionFlags		= kAudioUnitRenderAction_OutputIsSilence;
		
		for(currentBuffer = 0; currentBuffer < ioData->mNumberBuffers; ++currentBuffer) {
			memset(ioData->mBuffers[currentBuffer].mData, 0, ioData->mBuffers[currentBuffer].mDataByteSize);
		}
		
		[pool release];
		return noErr;
	}
	
	originalBufferSize		= ioData->mBuffers[0].mDataByteSize;
	framesRead				= [streamDecoder readAudio:ioData frameCount:inNumberFrames];
		
#if DEBUG
	if(framesRead != inNumberFrames) {
		NSLog(@"MyRenderer requested %i frames, got %i", inNumberFrames, framesRead);
	}
#endif
	
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
	
	if(0 == framesRead) {
		*ioActionFlags		= kAudioUnitRenderAction_OutputIsSilence;
		
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
	NSAutoreleasePool		*pool;
	AudioPlayer				*player;
	
	pool					= [[NSAutoreleasePool alloc] init];
	player					= (AudioPlayer *)inRefCon;
	
	if(kAudioUnitRenderAction_PostRender & (*ioActionFlags)) {

#if DEBUG
		if(kAudioTimeStampSampleTimeValid & inTimeStamp->mFlags) {
			NSLog(@"PostRender time = %f", inTimeStamp->mSampleTime/44100.);
		}
#endif

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
		OSStatus					err;
		ComponentResult				s;
		ComponentDescription		desc;
		Component					comp;
		AURenderCallbackStruct		input;
		
		desc.componentType			= kAudioUnitType_Output;
		desc.componentSubType		= kAudioUnitSubType_DefaultOutput;
		desc.componentManufacturer	= kAudioUnitManufacturer_Apple;
		desc.componentFlags			= 0;
		desc.componentFlagsMask		= 0;
		
		comp						= FindNextComponent(NULL, &desc);
		
		if(NULL == comp) {
			printf ("FindNextComponent\n");
			
			[self release];
			return nil;
		}
		
		err = OpenAComponent(comp, &_audioUnit);
		
		if(noErr != err || NULL == comp) {
			printf ("OpenAComponent=%ld\n", err);
			
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
			printf ("AudioUnitSetProperty-CB=%ld\n", err);
			
			[self release];
			return nil;
		}
			
		s = AudioUnitInitialize(_audioUnit);
		if(noErr != s) {
			printf ("AudioUnitInitialize-CB=%ld\n", s);
			
			[self release];
			return nil;
		}
		
		AudioUnitAddRenderNotify(_audioUnit, MyRenderNotification, (void *)self);

		_secondsFormatter	= [[SecondsFormatter alloc] init];
		_runLoop			= [[NSRunLoop currentRunLoop] retain];
	}
	return self;
}

- (void) dealloc
{
	[self stop];
	
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

#pragma mark Stream Management

- (BOOL) setStream:(AudioStream *)stream error:(NSError **)error
{
	NSParameterAssert(nil != stream);
	
	BOOL							result;
	AudioStreamBasicDescription		pcmFormat;
	AudioStreamDecoder				*streamDecoder;

	if(nil != [self nextStreamDecoder]) {
		[[self nextStreamDecoder] stopDecoding:error];
		[self setNextStreamDecoder:nil];
	}

	if(nil != [self streamDecoder]) {
		[[self streamDecoder] stopDecoding:error];
		[self setStreamDecoder:nil];
		
	}
	
	streamDecoder = [AudioStreamDecoder streamDecoderForStream:stream error:error];
	if(nil == streamDecoder) {

		if(nil != error) {
			
		}

		return NO;
	}
	
	[self willChangeValueForKey:@"totalFrames"];
	[self willChangeValueForKey:@"currentFrame"];
	
	[self setStreamDecoder:streamDecoder];
	[[self streamDecoder] startDecoding:error];
	
	[self didChangeValueForKey:@"totalFrames"];
	[self didChangeValueForKey:@"currentFrame"];
	
	pcmFormat	= [[self streamDecoder] pcmFormat];
	result		= AudioUnitSetProperty([self audioUnit],
									   kAudioUnitProperty_StreamFormat,
									   kAudioUnitScope_Input,
									   0,
									   &pcmFormat,
									   sizeof(AudioStreamBasicDescription));
	
	if(noErr != result) {
		printf ("AudioUnitSetProperty-SF=%4.4s, %ld\n", (char*)&result, result); 
		
		if(nil != error) {
			
		}
		
		return NO;
	}
	
	return YES;
}

- (BOOL) setNextStream:(AudioStream *)stream error:(NSError **)error
{
	NSParameterAssert(nil != stream);

	AudioStreamBasicDescription		pcmFormat, nextPCMFormat;
		
	AudioStreamDecoder *streamDecoder = [AudioStreamDecoder streamDecoderForStream:stream error:error];	
	if(nil == streamDecoder) {
		
		if(nil != error) {
			
		}
		
		return NO;
	}
	
	[self setNextStreamDecoder:streamDecoder];
	[[self nextStreamDecoder] startDecoding:error];
	
	pcmFormat		= [[self streamDecoder] pcmFormat];
	nextPCMFormat	= [[self nextStreamDecoder] pcmFormat];

	// We can only join the two files if they have the same formats (mSampleRate, etc)
	if(0 != memcmp(&pcmFormat, &nextPCMFormat, sizeof(pcmFormat))) {

#if DEBUG
		NSLog(@"Unable to join buffers, PCM formats don't match:");
		dumpASBD(&pcmFormat);
		dumpASBD(&nextPCMFormat);
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
		printf ("AudioOutputUnitStart=%ld\n", result);
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
		printf ("AudioOutputUnitStop=%ld\n", result);
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

- (Float32) volume
{
	Float32				volume;	
	ComponentResult		result		= AudioUnitGetParameter([self audioUnit],
															kHALOutputParam_Volume,
															kAudioUnitScope_Global,
															0,
															&volume);
	
	if(noErr != result) {
		NSLog(@"Unable to determine volume: %i", result);
	}
	
	return volume;
}

- (void) setVolume:(Float32)volume
{
	ComponentResult result = AudioUnitSetParameter([self audioUnit],
												   kHALOutputParam_Volume,
												   kAudioUnitScope_Global,
												   0,
												   volume,
												   0);

	if(noErr != result) {
		NSLog(@"Unable to set volume: %i", result);
	}
}

- (SInt64) totalFrames
{
	SInt64				result				= -1;
	AudioStreamDecoder	*streamDecoder		= [self streamDecoder];
	
	if(nil != streamDecoder) {
		result						= [streamDecoder totalFrames];
	}
	
	return result;
}

- (SInt64) currentFrame
{
	SInt64				result				= -1;
	AudioStreamDecoder	*streamDecoder		= [self streamDecoder];
	
	if(nil != streamDecoder) {
		result						= [streamDecoder currentFrame];
	}
	
	return result;
}

- (void) setCurrentFrame:(SInt64)currentFrame
{
	AudioStreamDecoder *streamDecoder = [self streamDecoder];
	
	if(nil != streamDecoder) {
		if([self isPlaying]) {
			[self stop];
		}
		
		SInt64 seekedFrame = [streamDecoder seekToFrame:currentFrame];

#if DEBUG
		if(seekedFrame != currentFrame) {
			NSLog(@"Seek failed: requested frame %qi, got %qi", currentFrame, seekedFrame);
		}
#endif
		
		if(nil != [self nextStreamDecoder]) {
			NSError *error;
			[[self nextStreamDecoder] stopDecoding:&error];
			[self setNextStreamDecoder:nil];
			_requestedNextStream = NO;
		}
		
		if([self isPlaying]) {
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
		timeInterval				= (NSTimeInterval) ([streamDecoder totalFrames] / [streamDecoder pcmFormat].mSampleRate);				
		result						= [[self secondsFormatter] stringForObjectValue:[NSNumber numberWithDouble:timeInterval]];
	}
	
	return result;
}

- (NSString *) currentSecondString
{
	NSString			*result			= nil;
	NSTimeInterval		timeInterval	= 0.0;
	AudioStreamDecoder	*streamDecoder	= [self streamDecoder];
	
	if(nil != streamDecoder) {
		timeInterval				= (NSTimeInterval) ([streamDecoder currentFrame] / [streamDecoder pcmFormat].mSampleRate);		
		result						= [[self secondsFormatter] stringForObjectValue:[NSNumber numberWithDouble:timeInterval]];
	}
	
	return result;
}

- (NSString *) secondsRemainingString
{
	NSString			*result			= nil;
	NSTimeInterval		timeInterval	= 0.0;
	AudioStreamDecoder	*streamDecoder	= [self streamDecoder];
	
	if(nil != streamDecoder) {
		timeInterval				= (NSTimeInterval) ([streamDecoder framesRemaining] / [streamDecoder pcmFormat].mSampleRate);
		result						= [[self secondsFormatter] stringForObjectValue:[NSNumber numberWithDouble:timeInterval]];
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
	[_owner performSelectorOnMainThread:@selector(streamPlaybackDidComplete:) withObject:nil waitUntilDone:NO];
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
		_frameCounter		= 0;
	}
}


- (void) didStartUsingNextStreamDecoder
{
	[self setStreamDecoder:[self nextStreamDecoder]];
	[self setNextStreamDecoder:nil];
	_requestedNextStream = NO;
	
	[_owner performSelectorOnMainThread:@selector(streamPlaybackDidStart:) withObject:[[self streamDecoder] stream] waitUntilDone:NO];
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

@end
