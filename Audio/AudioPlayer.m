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
- (void)				renderDidComplete;
- (void)				accumulateFrames:(UInt32)frameCount;

@end

// ========================================
// AudioUnit render function
// Thin wrapper around an AudioStreamDecoder
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
	UInt32					framesRead;
	
	pool				= [[NSAutoreleasePool alloc] init];
	player				= (AudioPlayer *)inRefCon;
	streamDecoder		= [player valueForKey:@"streamDecoder"];
	framesRead			= [streamDecoder readAudio:ioData frameCount:inNumberFrames];
	
	// Accumulate the frames for UI updates
	[player accumulateFrames:framesRead];

	if(0 == framesRead) {
		[player renderDidComplete];
	}	

	[pool release];
	
	return noErr;
}

@implementation AudioPlayer

+ (void) initialize
{
	[self exposeBinding:@"currentFrame"];
	[self exposeBinding:@"totalFrames"];
	
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
		
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	ComponentResult				result;
	AudioStreamDecoder			*currentStreamDecoder;
	
	
	result						= AudioUnitUninitialize(_audioUnit);
	
	if(noErr != result) {
		NSLog(@"AudioUnitUninitialize failed: %ld", result);
	}
	
	CloseComponent(_audioUnit);			_audioUnit = NULL;

	currentStreamDecoder			= [self valueForKey:@"streamDecoder"];
	
	if(nil != currentStreamDecoder) {
		[currentStreamDecoder cleanupDecoder];
		[self setValue:nil forKey:@"streamDecoder"];
	}
	
	[super dealloc];
}

- (BOOL) setStreamDecoder:(AudioStreamDecoder *)streamDecoder error:(NSError **)error
{
	NSParameterAssert(nil != streamDecoder);

	BOOL							result;
	AudioStreamBasicDescription		pcmFormat;
	AudioStreamDecoder				*currentStreamDecoder;
	
	currentStreamDecoder			= [self valueForKey:@"streamDecoder"];
	
	if(nil != currentStreamDecoder) {
		[currentStreamDecoder cleanupDecoder];
	}
	
	[self willChangeValueForKey:@"totalFrames"];
	[self willChangeValueForKey:@"currentFrame"];

	[self setValue:streamDecoder forKey:@"streamDecoder"];
	[streamDecoder setupDecoder];

	[self didChangeValueForKey:@"totalFrames"];
	[self didChangeValueForKey:@"currentFrame"];

	pcmFormat					= [streamDecoder pcmFormat];
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
		
		[self setValue:nil forKey:@"streamDecoder"];

		return NO;
	}
		
	return YES;
}

- (void) reset
{
	[self willChangeValueForKey:@"totalFrames"];
	[self willChangeValueForKey:@"currentFrame"];
	
	[self setValue:nil forKey:@"streamDecoder"];

	[self didChangeValueForKey:@"totalFrames"];
	[self didChangeValueForKey:@"currentFrame"];

	_frameCountAccumulator			= 0;
}

- (void) play
{
	ComponentResult				result;
	
	result						= AudioOutputUnitStart([self audioUnit]);
	
	if(noErr != result) {
		printf ("AudioOutputUnitStart=%ld\n", result);
	}
	
	_isPlaying					= YES;
}

- (void) playPause
{
	if(_isPlaying) {
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

	_isPlaying					= NO;
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
	
	streamDecoder					= [self valueForKey:@"streamDecoder"];
	
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
	
	streamDecoder					= [self valueForKey:@"streamDecoder"];
	
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
	
	streamDecoder					= [self valueForKey:@"streamDecoder"];
	
	if(nil != streamDecoder) {
		totalFrames					= [streamDecoder totalFrames];		
		
		[self setCurrentFrame:totalFrames - 1];
	}
}

- (void) skipToBeginning
{
	AudioStreamDecoder				*streamDecoder;
	
	streamDecoder					= [self valueForKey:@"streamDecoder"];
	
	if(nil != streamDecoder) {
		[self setCurrentFrame:0];
	}
}

- (BOOL)		isPlaying		{ return _isPlaying; }

- (SInt64) totalFrames
{
	SInt64							result;
	AudioStreamDecoder				*streamDecoder;
	
	result							= -1;
	streamDecoder					= [self valueForKey:@"streamDecoder"];
	
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
	streamDecoder					= [self valueForKey:@"streamDecoder"];
	
	if(nil != streamDecoder) {
		result						= [streamDecoder currentFrame];
	}
	
	return result;
}

- (void) setCurrentFrame:(SInt64)currentFrame
{
	AudioStreamDecoder				*streamDecoder;
	SInt64							seekedFrame;
	BOOL							playing;
	
	playing							= [self isPlaying];
	
	if(playing) {
		[self stop];
	}
	
	streamDecoder					= [self valueForKey:@"streamDecoder"];
	seekedFrame						= [streamDecoder seekToFrame:currentFrame];

	NSAssert2(seekedFrame == currentFrame, @"Seek failed: requested frame %qi, frame %qi", currentFrame, seekedFrame);
	
	if(playing) {
		[self playPause];
	}
}

- (NSString *) totalSecondsString
{
	NSString						*result;
	NSTimeInterval					timeInterval;
	AudioStreamDecoder				*streamDecoder;

	result							= nil;
	streamDecoder					= [self valueForKey:@"streamDecoder"];
	
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
	streamDecoder					= [self valueForKey:@"streamDecoder"];
	
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
	streamDecoder					= [self valueForKey:@"streamDecoder"];
	
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

- (AudioUnit)			audioUnit						{ return _audioUnit; }

- (void) renderDidComplete
{
	[_owner streamPlaybackDidComplete];
}

- (void) accumulateFrames:(UInt32)frameCount
{
	NSTimeInterval					seconds;
	AudioStreamDecoder				*streamDecoder;
	
	streamDecoder					= [self valueForKey:@"streamDecoder"];
	_frameCountAccumulator			+= frameCount;
	seconds							= (NSTimeInterval) (_frameCountAccumulator / [streamDecoder pcmFormat].mSampleRate);
	
	if(1.0 < seconds) {
		[self willChangeValueForKey:@"currentFrame"];
		_frameCountAccumulator		= 0;
		[self didChangeValueForKey:@"currentFrame"];
	}
	
}

@end
