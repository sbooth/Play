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

#import "AudioStreamDecoder.h"
#import "FLACStreamDecoder.h"
#import "OggVorbisStreamDecoder.h"
#import "MusepackStreamDecoder.h"
#import "CoreAudioStreamDecoder.h"

#import "UtilityFunctions.h"

#include <AudioToolbox/AudioFormat.h>

NSString *const AudioStreamDecoderErrorDomain = @"org.sbooth.Play.ErrorDomain.AudioStreamDecoder";

@implementation AudioStreamDecoder

+ (void) initialize
{
	[self exposeBinding:@"currentFrame"];
	[self exposeBinding:@"totalFrames"];
	[self exposeBinding:@"framesRemaining"];

	[self setKeys:[NSArray arrayWithObject:@"framesRemaining"] triggerChangeNotificationsForDependentKey:@"currentFrame"];
	[self setKeys:[NSArray arrayWithObject:@"framesRemaining"] triggerChangeNotificationsForDependentKey:@"totalFrames"];
}

+ (AudioStreamDecoder *) streamDecoderForURL:(NSURL *)url error:(NSError **)error
{
	NSParameterAssert(nil != url);
	NSParameterAssert([url isFileURL]);
	
	AudioStreamDecoder				*result;
	NSString						*path;
	NSString						*pathExtension;
	
	path							= [url path];
	pathExtension					= [[path pathExtension] lowercaseString];
	
	if([pathExtension isEqualToString:@"flac"]) {
		result						= [[FLACStreamDecoder alloc] init];
		
		[result setValue:url forKey:@"url"];
	}
	else if([pathExtension isEqualToString:@"ogg"]) {
		result						= [[OggVorbisStreamDecoder alloc] init];
		
		[result setValue:url forKey:@"url"];
	}
	else if([pathExtension isEqualToString:@"mpc"]) {
		result						= [[MusepackStreamDecoder alloc] init];
		
		[result setValue:url forKey:@"url"];
	}
	else if([getCoreAudioExtensions() containsObject:pathExtension]) {
		result						= [[CoreAudioStreamDecoder alloc] init];
		
		[result setValue:url forKey:@"url"];
	}
	else {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary;
			
			errorDictionary			= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The format of the file \"%@\" was not recognized.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"File Format Not Recognized" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error					= [NSError errorWithDomain:AudioStreamDecoderErrorDomain 
														  code:AudioStreamDecoderFileFormatNotRecognizedError 
													  userInfo:errorDictionary];
		}
		
		result						= nil;
	}
		
	return [result autorelease];
}

- (id) init
{
	if((self = [super init])) {
		_pcmBuffer		= [[CircularBuffer alloc] init];
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_pcmBuffer release];		_pcmBuffer = nil;
		
	[super dealloc];
}

- (AudioStreamBasicDescription)		pcmFormat			{ return _pcmFormat; }
- (CircularBuffer *)				pcmBuffer			{ return [[_pcmBuffer retain] autorelease]; }

- (NSString *)						pcmFormatDescription
{
	OSStatus						result;
	UInt32							specifierSize;
	AudioStreamBasicDescription		asbd;
	NSString						*fileFormat;
	
	asbd			= _pcmFormat;
	specifierSize	= sizeof(fileFormat);
	result			= AudioFormatGetProperty(kAudioFormatProperty_FormatName, sizeof(AudioStreamBasicDescription), &asbd, &specifierSize, &fileFormat);
	NSAssert1(noErr == result, @"AudioFormatGetProperty failed: %@", UTCreateStringForOSType(result));
	
	return [fileFormat autorelease];
}

- (UInt32) readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount
{
	NSParameterAssert(NULL != bufferList);
	NSParameterAssert(0 < bufferList->mNumberBuffers);
	NSParameterAssert(0 < frameCount);

	UInt32							framesRead;
	UInt32							byteCount;
	UInt32							bytesRead;
	
//	NSParameterAssert(bufferList->mBuffers[0].mDataByteSize >= byteCount);
	
	framesRead						= 0;
	byteCount						= frameCount * [self pcmFormat].mBytesPerPacket;
	bytesRead						= 0;
	
	// If there aren't enough bytes in the buffer, fill it as much as possible
	if([[self pcmBuffer] bytesAvailable] < byteCount) {
		[self fillPCMBuffer];
	}
	
	// If there still aren't enough bytes available, return what we have
	if([[self pcmBuffer] bytesAvailable] < byteCount) {
		byteCount = [[self pcmBuffer] bytesAvailable];
	}
	
	bytesRead								= [[self pcmBuffer] getData:bufferList->mBuffers[0].mData byteCount:byteCount];
	bufferList->mBuffers[0].mNumberChannels	= [self pcmFormat].mChannelsPerFrame;
	bufferList->mBuffers[0].mDataByteSize	= bytesRead;
	framesRead								= bytesRead / [self pcmFormat].mBytesPerFrame;
	
	[self setCurrentFrame:[self currentFrame] + framesRead];
		
	return framesRead;
}

- (NSString *)		sourceFormatDescription					{ return nil; }

- (SInt64)			totalFrames								{ return _totalFrames; }
- (SInt64)			currentFrame							{ return _currentFrame; }
- (SInt64)			framesRemaining 						{ return ([self totalFrames] - [self currentFrame]); }

- (SInt64)			seekToFrame:(SInt64)frame				{ return -1; }

- (BOOL)			readProperties:(NSError **)error		{ return YES; }

- (void)			fillPCMBuffer							{}
- (void)			setupDecoder							{}
- (void)			cleanupDecoder							{}

- (void)			setTotalFrames:(SInt64)totalFrames		{ _totalFrames = totalFrames; }
- (void)			setCurrentFrame:(SInt64)currentFrame	{ _currentFrame = currentFrame; }

@end
