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

#import "LoopableRegionDecoder.h"
#import "AudioDecoder.h"

@interface LoopableRegionDecoder (Private)
- (AudioDecoder *) decoder;
@end

@implementation LoopableRegionDecoder

+ (void) initialize
{
	[self exposeBinding:@"startingFrame"];
	[self exposeBinding:@"frameCount"];
	[self exposeBinding:@"loopCount"];
}

+ (id) decoderWithURL:(NSURL *)URL startingFrame:(SInt64)startingFrame error:(NSError **)error
{
	return [[[LoopableRegionDecoder alloc] initWithURL:URL startingFrame:startingFrame error:error] autorelease];
}

+ (id) decoderWithURL:(NSURL *)URL startingFrame:(SInt64)startingFrame frameCount:(unsigned)frameCount error:(NSError **)error
{
	return [[[LoopableRegionDecoder alloc] initWithURL:URL startingFrame:startingFrame frameCount:frameCount error:error] autorelease];
}

+ (id) decoderWithURL:(NSURL *)URL startingFrame:(SInt64)startingFrame frameCount:(unsigned)frameCount loopCount:(unsigned)loopCount error:(NSError **)error
{
	return [[[LoopableRegionDecoder alloc] initWithURL:URL startingFrame:startingFrame frameCount:frameCount loopCount:loopCount error:error] autorelease];
}

- (id) initWithURL:(NSURL *)URL error:(NSError **)error
{
	if((self = [super init])) {
		_decoder = [AudioDecoder decoderWithURL:URL error:error];
		if(nil != _decoder)
			[_decoder retain];
		else {
			[self release];
			return nil;
		}
		
		[self setFrameCount:[[self decoder] totalFrames]];
	}
	return self;
}

- (id) initWithURL:(NSURL *)URL startingFrame:(SInt64)startingFrame error:(NSError **)error
{
	if((self = [super init])) {
		_decoder = [AudioDecoder decoderWithURL:URL error:error];
		if(nil != _decoder)
			[_decoder retain];
		else {
			[self release];
			return nil;
		}
		
		[self setStartingFrame:startingFrame];
		[self setFrameCount:([[self decoder] totalFrames] - startingFrame)];
		
		if(0 != [self startingFrame])
			[self reset];
	}
	return self;
}

- (id) initWithURL:(NSURL *)URL startingFrame:(SInt64)startingFrame frameCount:(unsigned)frameCount error:(NSError **)error
{
	if((self = [super init])) {
		_decoder = [AudioDecoder decoderWithURL:URL error:error];
		if(nil != _decoder)
			[_decoder retain];
		else {
			[self release];
			return nil;
		}

		[self setStartingFrame:startingFrame];
		[self setFrameCount:frameCount];
		
		if(0 != [self startingFrame])
			[self reset];
	}
	return self;
}

- (id) initWithURL:(NSURL *)URL startingFrame:(SInt64)startingFrame frameCount:(unsigned)frameCount loopCount:(unsigned)loopCount error:(NSError **)error
{
	if((self = [super init])) {
		_decoder = [AudioDecoder decoderWithURL:URL error:error];
		if(nil != _decoder)
			[_decoder retain];
		else {
			[self release];
			return nil;
		}

		[self setStartingFrame:startingFrame];
		[self setFrameCount:frameCount];
		[self setLoopCount:loopCount];
		
		if(0 != [self startingFrame])
			[self reset];
	}
	return self;
}

- (void) dealloc
{
	[_decoder release], _decoder = nil;
	
	[super dealloc];
}

- (unsigned)		loopCount								{ return _loopCount; }
- (void)			setLoopCount:(unsigned)loopCount 		{ _loopCount = loopCount; }

- (SInt64)			startingFrame							{ return _startingFrame; }

- (void) setStartingFrame:(SInt64)startingFrame
{
	NSParameterAssert(0 <= startingFrame);
	
	_startingFrame = startingFrame;
}

- (UInt32)			frameCount							{ return _frameCount; }

- (void) setFrameCount:(UInt32)frameCount
{
	NSParameterAssert(0 < frameCount);
	
	_frameCount = frameCount;
}

#pragma mark Decoding

- (unsigned)		completedLoops							{ return _completedLoops; }

- (SInt64)			totalFrames								{ return (([self loopCount] + 1) * [self frameCount]); }
- (SInt64)			currentFrame							{ return _totalFramesRead; }
- (SInt64)			framesRemaining							{ return ([self totalFrames] - [self currentFrame]); }

- (SInt64) seekToFrame:(SInt64)frame
{
	NSParameterAssert(0 <= frame && frame < [self totalFrames]);
	
	_completedLoops				= frame / [self frameCount];
	_framesReadInCurrentLoop	= frame % [self frameCount];
	_totalFramesRead			= frame;
	
	[[self decoder] seekToFrame:[self startingFrame] + _framesReadInCurrentLoop];
	
	return [self currentFrame];
}

- (UInt32) readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount
{
	NSParameterAssert(NULL != bufferList);
	NSParameterAssert(0 < frameCount);
	
	if([self loopCount] < [self completedLoops])
		return 0;
	
	UInt32	framesRemaining		= [self startingFrame] + [self frameCount] - [[self decoder] currentFrame];
	UInt32	framesToRead		= (frameCount < framesRemaining ? frameCount : framesRemaining);
	UInt32	framesRead			= 0;
	
	if(0 < framesToRead)
		framesRead = [[self decoder] readAudio:bufferList frameCount:framesToRead];
	
	_framesReadInCurrentLoop	+= framesRead;
	_totalFramesRead			+= framesRead;
	
	if([self frameCount] == _framesReadInCurrentLoop || (0 == framesRead && 0 != framesToRead)) {
		++_completedLoops;
		_framesReadInCurrentLoop = 0;
		
		if([self loopCount] > [self completedLoops])
			[[self decoder] seekToFrame:[self startingFrame]];
	}
	
	return framesRead;	
}

- (void) reset
{
	[[self decoder] seekToFrame:[self startingFrame]];
	
	_framesReadInCurrentLoop	= 0;
	_totalFramesRead			= 0;
	_completedLoops				= 0;
}

#pragma mark AudioDecoder pass-throughs

- (AudioStreamBasicDescription) format						{ return [[self decoder] format]; }

- (NSString *)		formatDescription						{ return [[self decoder] formatDescription]; }

- (AudioChannelLayout) channelLayout						{ return [[self decoder] channelLayout]; }
- (NSString *)		channelLayoutDescription				{ return [[self decoder] channelLayoutDescription]; }

- (AudioStreamBasicDescription) sourceFormat				{ return [[self decoder] sourceFormat]; }
- (NSString *)		sourceFormatDescription					{ return [[self decoder] sourceFormatDescription]; }


- (BOOL)			supportsSeeking							{ return [[self decoder] supportsSeeking]; }

@end

@implementation LoopableRegionDecoder (Private)
- (AudioDecoder *)	decoder									{ return [[_decoder retain] autorelease]; }

@end
