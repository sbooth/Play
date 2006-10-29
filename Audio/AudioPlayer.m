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

#import "AudioPlayer.h"
#import "LibraryDocument.h"

#include <CoreServices/CoreServices.h>

@interface AudioPlayer (Private)

- (AudioUnit)			audioUnit;

- (NSRunLoop *)			runLoop;

- (AudioStreamDecoder *) streamDecoder;
- (void)				setStreamDecoder:(AudioStreamDecoder *)streamDecoder;

//- (void)				didReachEndOfStream:(id)arg;
- (void)				didReachEndOfStream;
//- (void)				didReadFrames:(NSNumber *)frameCount;
- (void)				didReadFrames:(UInt32)frameCount;

- (void)				currentFrameNeedsUpdate;

- (void)				setIsPlaying:(BOOL)isPlaying;

@end

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
	UInt32					framesRead, currentBuffer;

	pool					= [[NSAutoreleasePool alloc] init];
	player					= (AudioPlayer *)inRefCon;
	streamDecoder			= [player streamDecoder];
	framesRead				= [streamDecoder readAudio:ioData frameCount:inNumberFrames];
		
#if DEBUG
	if(framesRead != inNumberFrames) {
		NSLog(@"MyRenderer requested %i frames, got %i", inNumberFrames, framesRead);
	}
#endif
	
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
	[self exposeBinding:@"currentFrame"];
	[self exposeBinding:@"totalFrames"];
	[self exposeBinding:@"hasValidStream"];
	
	[self setKeys:[NSArray arrayWithObject:@"streamDecoder"] triggerChangeNotificationsForDependentKey:@"hasValidStream"];

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
		
		err							= OpenAComponent(comp, &_audioUnit);
		
		if(noErr != err || NULL == comp) {
			printf ("OpenAComponent=%ld\n", err);
			
			[self release];
			return nil;
		}
		
		// Set up a callback function to generate output to the output unit
		input.inputProc				= MyRenderer;
		input.inputProcRefCon		= (void *)self;
		
		err							= AudioUnitSetProperty(_audioUnit, 
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
			
		s							= AudioUnitInitialize(_audioUnit);
		
		if(noErr != s) {
			printf ("AudioUnitInitialize-CB=%ld\n", s);
			
			[self release];
			return nil;
		}
		
		AudioUnitAddRenderNotify(_audioUnit, MyRenderNotification, (void *)self);

		_runLoop = [[NSRunLoop currentRunLoop] retain];
		
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	ComponentResult				result;
	
	[self stop];
	
	result						= AudioUnitUninitialize(_audioUnit);
	
	if(noErr != result) {
		NSLog(@"AudioUnitUninitialize failed: %ld", result);
	}
	
	CloseComponent(_audioUnit);			_audioUnit = NULL;

	
	if(nil != [self streamDecoder]) {
		[[self streamDecoder] stopDecoding:nil];
		[_streamDecoder release];		_streamDecoder = nil;
	}
	
	[_owner release];					_owner = nil;
	[_runLoop release];					_runLoop = nil;
	
	[super dealloc];
}

- (LibraryDocument *)	owner									{ return [[_owner retain] autorelease]; }
- (void)				setOwner:(LibraryDocument *)owner		{ [_owner release]; _owner = [owner retain]; }

- (BOOL) setStreamURL:(NSURL *)url error:(NSError **)error
{
	BOOL							result;
	AudioStreamBasicDescription		pcmFormat;
	AudioStreamDecoder				*streamDecoder;

	if(nil != [self streamDecoder]) {
		[[self streamDecoder] stopDecoding:error];
		[self setStreamDecoder:nil];
		
	}
	
	streamDecoder				= [AudioStreamDecoder streamDecoderForURL:url error:error];
	
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
	
	pcmFormat					= [[self streamDecoder] pcmFormat];
	result						= AudioUnitSetProperty([self audioUnit],
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

- (void) reset
{
	[self willChangeValueForKey:@"totalFrames"];
	[self willChangeValueForKey:@"currentFrame"];
	
	[self setStreamDecoder:nil];

	[self didChangeValueForKey:@"totalFrames"];
	[self didChangeValueForKey:@"currentFrame"];
}

- (BOOL) hasValidStream
{
	return (nil != [self streamDecoder]);
}

- (void) play
{
	ComponentResult				result;
	
	result						= AudioOutputUnitStart([self audioUnit]);
	
	if(noErr != result) {
		printf ("AudioOutputUnitStart=%ld\n", result);
	}
	
	[self setIsPlaying:YES];
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
	ComponentResult				result;
	
	result						= AudioOutputUnitStop([self audioUnit]);
	
	if(noErr != result) {
		printf ("AudioOutputUnitStop=%ld\n", result);
	}

	[self setIsPlaying:NO];
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
	SInt64							currentFrame;
	SInt64							desiredFrame;
	SInt64							totalFrames;
	AudioStreamDecoder				*streamDecoder;
	
	streamDecoder					= [self streamDecoder];
	
	if(nil != streamDecoder) {
		totalFrames					= [streamDecoder totalFrames];
		currentFrame				= [streamDecoder currentFrame];
		desiredFrame				= currentFrame + (SInt64)(seconds * [streamDecoder pcmFormat].mSampleRate);
		
		if(totalFrames < desiredFrame) {
			desiredFrame = totalFrames;
		}
		
		[self setCurrentFrame:desiredFrame];
	}	
}

- (void) skipBackward:(UInt32)seconds
{
	SInt64							currentFrame;
	SInt64							desiredFrame;
	AudioStreamDecoder				*streamDecoder;
	
	streamDecoder					= [self streamDecoder];
	
	if(nil != streamDecoder) {
		currentFrame				= [streamDecoder currentFrame];
		desiredFrame				= currentFrame - (SInt64)(seconds * [streamDecoder pcmFormat].mSampleRate);
		
		if(0 > desiredFrame) {
			desiredFrame = 0;
		}
		
		[self setCurrentFrame:desiredFrame];
	}
}

- (void) skipToEnd
{
	SInt64							totalFrames;
	AudioStreamDecoder				*streamDecoder;
	
	streamDecoder					= [self streamDecoder];
	
	if(nil != streamDecoder) {
		totalFrames					= [streamDecoder totalFrames];		
		
		[self setCurrentFrame:totalFrames - 1];
	}
}

- (void) skipToBeginning
{
	if(nil != [self streamDecoder]) {
		[self setCurrentFrame:0];
	}
}

- (BOOL) isPlaying
{
	return _isPlaying;
}

- (SInt64) totalFrames
{
	SInt64							result;
	AudioStreamDecoder				*streamDecoder;
	
	result							= -1;
	streamDecoder					= [self streamDecoder];
	
	if(nil != streamDecoder) {
		result						= [streamDecoder totalFrames];
	}
	
	return result;
}

- (SInt64) currentFrame
{
	SInt64							result;
	AudioStreamDecoder				*streamDecoder;
	
	result							= -1;
	streamDecoder					= [self streamDecoder];
	
	if(nil != streamDecoder) {
		result						= [streamDecoder currentFrame];
	}
	
	return result;
}

- (void) setCurrentFrame:(SInt64)currentFrame
{
	AudioStreamDecoder				*streamDecoder;
	SInt64							seekedFrame;
	BOOL							isPlaying;
	
	streamDecoder					= [self streamDecoder];
	
	if(nil != streamDecoder) {
		isPlaying					= [self isPlaying];
		
		if(isPlaying) {
			[self stop];
		}
		
		seekedFrame					= [streamDecoder seekToFrame:currentFrame];

#if DEBUG
		if(seekedFrame != currentFrame) {
			NSLog(@"Seek failed: requested frame %qi, got %qi", currentFrame, seekedFrame);
		}
#endif
		
		if(isPlaying) {
			[self play];
		}
	}
}

- (NSString *) totalSecondsString
{
	NSString						*result;
	NSTimeInterval					timeInterval;
	AudioStreamDecoder				*streamDecoder;

	result							= nil;
	streamDecoder					= [self streamDecoder];
	
	if(nil != streamDecoder) {
		UInt32						minutes, seconds;
		
		minutes						= 0;
		seconds						= 0;
		timeInterval				= (NSTimeInterval) ([streamDecoder totalFrames] / [streamDecoder pcmFormat].mSampleRate);
		minutes						= (UInt32)timeInterval / 60;
		seconds						= (UInt32)timeInterval % 60;
				
		result						= [NSString stringWithFormat:@"%u:%.2u", minutes, seconds];
	}
	
	return result;
}

- (NSString *) currentSecondString
{
	NSString						*result;
	NSTimeInterval					timeInterval;
	AudioStreamDecoder				*streamDecoder;
	
	result							= nil;
	streamDecoder					= [self streamDecoder];
	
	if(nil != streamDecoder) {
		UInt32						minutes, seconds;
		
		minutes						= 0;
		seconds						= 0;
		timeInterval				= (NSTimeInterval) ([streamDecoder currentFrame] / [streamDecoder pcmFormat].mSampleRate);
		minutes						= (UInt32)timeInterval / 60;
		seconds						= (UInt32)timeInterval % 60;
		
		result						= [NSString stringWithFormat:@"%u:%.2u", minutes, seconds];
	}
	
	return result;
}

- (NSString *) secondsRemainingString
{
	NSString						*result;
	NSTimeInterval					timeInterval;
	AudioStreamDecoder				*streamDecoder;
	
	result							= nil;
	streamDecoder					= [self streamDecoder];
	
	if(nil != streamDecoder) {
		UInt32						minutes, seconds;
		
		minutes						= 0;
		seconds						= 0;
		timeInterval				= (NSTimeInterval) ([streamDecoder framesRemaining] / [streamDecoder pcmFormat].mSampleRate);
		minutes						= (UInt32)timeInterval / 60;
		seconds						= (UInt32)timeInterval % 60;
		
		result						= [NSString stringWithFormat:@"%u:%.2u", minutes, seconds];
	}
	
	return result;
}

@end

@implementation AudioPlayer (Private)

- (AudioUnit) audioUnit
{
	return _audioUnit;
}

- (NSRunLoop *)	runLoop
{
	return [[_runLoop retain] autorelease];
}

- (AudioStreamDecoder *) streamDecoder
{
	return [[_streamDecoder retain] autorelease];
}

- (void) setStreamDecoder:(AudioStreamDecoder *)streamDecoder
{
	[_streamDecoder release];
	_streamDecoder = [streamDecoder retain];
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
	NSTimeInterval			seconds;
	
	// Accumulate the frames for UI updates approx. once per second
//	_frameCounter			+= [frameCount unsignedIntValue];
	_frameCounter			+= frameCount;
	seconds					= (NSTimeInterval) (_frameCounter / [[self streamDecoder] pcmFormat].mSampleRate);
	
	if(1.0 < seconds) {
//		[self currentFrameNeedsUpdate];
		[self performSelectorOnMainThread:@selector(currentFrameNeedsUpdate) withObject:nil waitUntilDone:NO];
		_frameCounter		= 0;
	}
}

- (void) currentFrameNeedsUpdate
{
	[self willChangeValueForKey:@"currentFrame"];
	[self didChangeValueForKey:@"currentFrame"];	
}

- (void) setIsPlaying:(BOOL)isPlaying
{
	_isPlaying = isPlaying;
}

@end
