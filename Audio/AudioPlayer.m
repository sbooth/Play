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

#include <CoreServices/CoreServices.h>

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
	
	pool				= [[NSAutoreleasePool alloc] init];
	player				= (AudioPlayer *)inRefCon;
	streamDecoder		= [player valueForKey:@"streamDecoder"];
	
	[streamDecoder readAudio:ioData frameCount:inNumberFrames];
	
	/*
	RenderSin (sSinWaveFrameCount, 
			   inNumberFrames,  
			   ioData->mBuffers[0].mData, 
			   sSampleRate, 
			   sAmplitude, 
			   sToneFrequency, 
			   sWhichFormat);
	
	//we're just going to copy the data into each channel
	for (UInt32 channel = 1; channel < ioData->mNumberBuffers; channel++)
		memcpy (ioData->mBuffers[channel].mData, ioData->mBuffers[0].mData, ioData->mBuffers[0].mDataByteSize);
	
	sSinWaveFrameCount += inNumberFrames;
	*/
	
	[pool release];
	
	return noErr;
}

@implementation AudioPlayer

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
	
	[self setValue:streamDecoder forKey:@"streamDecoder"];
	[streamDecoder setupDecoder];
	
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
		
		[self setNilValueForKey:@"streamDecoder"];

		return NO;
	}
			
	return YES;
}

- (void) play
{
	ComponentResult				result;

	result						= AudioOutputUnitStart([self audioUnit]);
	
	if(noErr != result) {
		printf ("AudioOutputUnitStart=%ld\n", result);
	}
}

- (void) stop
{
	ComponentResult				result;
	
	result						= AudioOutputUnitStop([self audioUnit]);
	
	if(noErr != result) {
		printf ("AudioOutputUnitStop=%ld\n", result);
	}
}

//@end

//@implementation AudioPlayer (Private)

- (AudioUnit) audioUnit
{
	return _audioUnit;
}

@end
