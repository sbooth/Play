/*
 *  $Id$
 *
 *  Copyright (C) 2007 Stephen F. Booth <me@sbooth.org>
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

#import "ScheduledAudioRegion.h"
#import "AudioDecoder.h"

// ========================================
// Helper functions
// ========================================
void
allocate_slice_for_asbd(const AudioStreamBasicDescription *asbd, ScheduledAudioSlice *slice, unsigned numberOfFramesPerSlice)
{
	NSCParameterAssert(NULL != asbd);
	NSCParameterAssert(NULL != slice);
	NSCParameterAssert(0 < numberOfFramesPerSlice);
	
	// Allocate the buffer list
	slice->mBufferList = calloc(sizeof(AudioBufferList) + (sizeof(AudioBuffer) * (asbd->mChannelsPerFrame - 1)), 1);
	NSCAssert(NULL != slice->mBufferList, @"Unable to allocate memory");
	
	slice->mBufferList->mNumberBuffers = asbd->mChannelsPerFrame;
	
	unsigned i;
	for(i = 0; i < slice->mBufferList->mNumberBuffers; ++i) {
		slice->mBufferList->mBuffers[i].mData = calloc(numberOfFramesPerSlice, sizeof(float));
		NSCAssert(NULL != slice->mBufferList->mBuffers[i].mData, @"Unable to allocate memory");
		slice->mBufferList->mBuffers[i].mDataByteSize = numberOfFramesPerSlice * sizeof(float);
		slice->mBufferList->mBuffers[i].mNumberChannels = 1;
	}
	
	// Set the complete flag so the scheduler knows this slice can be filled and scheduled
	slice->mFlags = kScheduledAudioSliceFlag_Complete;
}

void
deallocate_slice(ScheduledAudioSlice *slice)
{
	NSCParameterAssert(NULL != slice);
	
	unsigned i;
	for(i = 0; i < slice->mBufferList->mNumberBuffers; ++i) {
		free(slice->mBufferList->mBuffers[i].mData);
		slice->mBufferList->mBuffers[i].mData = NULL;
	}
	
	free(slice->mBufferList);
	slice->mBufferList = NULL;
}

ScheduledAudioSlice *
allocate_slice_buffer_for_asbd(const AudioStreamBasicDescription *asbd, unsigned numberOfSlicesInBuffer, unsigned numberOfFramesPerSlice)
{
	NSCParameterAssert(NULL != asbd);
	NSCParameterAssert(0 < numberOfSlicesInBuffer);
	NSCParameterAssert(0 < numberOfFramesPerSlice);
	
	ScheduledAudioSlice *sliceBuffer = calloc(numberOfSlicesInBuffer, sizeof(ScheduledAudioSlice));
	NSCAssert(NULL != sliceBuffer, @"Unable to allocate memory");
	
	unsigned i;
	for(i = 0; i < numberOfSlicesInBuffer; ++i)
		allocate_slice_for_asbd(asbd, sliceBuffer + i, numberOfFramesPerSlice);
	
	return sliceBuffer;
}

void
deallocate_slice_buffer(ScheduledAudioSlice **sliceBuffer, unsigned numberOfSlicesInBuffer)
{
	NSCParameterAssert(NULL != sliceBuffer);
	NSCParameterAssert(0 < numberOfSlicesInBuffer);

	if(NULL == *sliceBuffer)
		return;
	
	unsigned i;
	for(i = 0; i < numberOfSlicesInBuffer; ++i)
		deallocate_slice(*sliceBuffer + i);
	
	free(*sliceBuffer), *sliceBuffer = NULL;
}

static void
clear_buffer_list(AudioBufferList *bufferList, unsigned numberOfFramesPerSlice)
{
	NSCParameterAssert(NULL != bufferList);
	NSCParameterAssert(0 < numberOfFramesPerSlice);
	
	unsigned i;
	for(i = 0; i < bufferList->mNumberBuffers; ++i) {
		bufferList->mBuffers[i].mDataByteSize = numberOfFramesPerSlice * sizeof(float);
		memset(bufferList->mBuffers[i].mData, 0, bufferList->mBuffers[i].mDataByteSize);
	}
}

static void
clear_slice_buffer(ScheduledAudioSlice *sliceBuffer, unsigned numberOfSlicesInBuffer, unsigned numberOfFramesPerSlice)
{
	NSCParameterAssert(NULL != sliceBuffer);
	NSCParameterAssert(0 < numberOfSlicesInBuffer);
	NSCParameterAssert(0 < numberOfFramesPerSlice);
	
	unsigned i, j;
	for(i = 0; i < numberOfSlicesInBuffer; ++i) {
		for(j = 0; j < sliceBuffer[i].mBufferList->mNumberBuffers; ++j)
			clear_buffer_list(sliceBuffer[i].mBufferList, numberOfFramesPerSlice);
		sliceBuffer[i].mFlags = kScheduledAudioSliceFlag_Complete;
	}
}

@implementation ScheduledAudioRegion

#pragma mark Creation

+ (ScheduledAudioRegion *) scheduledAudioRegionForDecoder:(AudioDecoder *)decoder
{
	AudioTimeStamp startTime = { 0 };
	
	startTime.mFlags		= kAudioTimeStampSampleTimeValid;
	startTime.mSampleTime	= 0;
	
	return [ScheduledAudioRegion scheduledAudioRegionForDecoder:decoder startTime:startTime startingFrame:0 framesToPlay:[decoder totalFrames] loopCount:0];
}

+ (ScheduledAudioRegion *) scheduledAudioRegionForDecoder:(AudioDecoder *)decoder startingFrame:(SInt64)startingFrame
{
	AudioTimeStamp startTime = { 0 };
	
	startTime.mFlags		= kAudioTimeStampSampleTimeValid;
	startTime.mSampleTime	= 0;
	
	return [ScheduledAudioRegion scheduledAudioRegionForDecoder:decoder startTime:startTime startingFrame:startingFrame framesToPlay:([decoder totalFrames] - startingFrame) loopCount:0];
}

+ (ScheduledAudioRegion *) scheduledAudioRegionForDecoder:(AudioDecoder *)decoder startingFrame:(SInt64)startingFrame framesToPlay:(unsigned)framesToPlay
{
	AudioTimeStamp startTime = { 0 };
	
	startTime.mFlags		= kAudioTimeStampSampleTimeValid;
	startTime.mSampleTime	= 0;
	
	return [ScheduledAudioRegion scheduledAudioRegionForDecoder:decoder startTime:startTime startingFrame:startingFrame framesToPlay:framesToPlay loopCount:0];
}

+ (ScheduledAudioRegion *) scheduledAudioRegionForDecoder:(AudioDecoder *)decoder startingFrame:(SInt64)startingFrame framesToPlay:(unsigned)framesToPlay loopCount:(unsigned)loopCount
{
	AudioTimeStamp startTime = { 0 };
	
	startTime.mFlags		= kAudioTimeStampSampleTimeValid;
	startTime.mSampleTime	= 0;
	
	return [ScheduledAudioRegion scheduledAudioRegionForDecoder:decoder startTime:startTime startingFrame:startingFrame framesToPlay:framesToPlay loopCount:loopCount];
}

+ (ScheduledAudioRegion *) scheduledAudioRegionForDecoder:(AudioDecoder *)decoder startTime:(AudioTimeStamp)startTime
{
	return [ScheduledAudioRegion scheduledAudioRegionForDecoder:decoder startTime:startTime startingFrame:0 framesToPlay:[decoder totalFrames] loopCount:0];
}

+ (ScheduledAudioRegion *) scheduledAudioRegionForDecoder:(AudioDecoder *)decoder startTime:(AudioTimeStamp)startTime startingFrame:(SInt64)startingFrame
{
	return [ScheduledAudioRegion scheduledAudioRegionForDecoder:decoder startTime:startTime startingFrame:startingFrame framesToPlay:([decoder totalFrames] - startingFrame) loopCount:0];
}

+ (ScheduledAudioRegion *) scheduledAudioRegionForDecoder:(AudioDecoder *)decoder startTime:(AudioTimeStamp)startTime startingFrame:(SInt64)startingFrame framesToPlay:(unsigned)framesToPlay
{
	return [ScheduledAudioRegion scheduledAudioRegionForDecoder:decoder startTime:startTime startingFrame:startingFrame framesToPlay:framesToPlay loopCount:0];
}

+ (ScheduledAudioRegion *) scheduledAudioRegionForDecoder:(AudioDecoder *)decoder startTime:(AudioTimeStamp)startTime startingFrame:(SInt64)startingFrame framesToPlay:(unsigned)framesToPlay loopCount:(unsigned)loopCount
{
	ScheduledAudioRegion *result = [[ScheduledAudioRegion alloc] init];
	
	[result setDecoder:decoder];
	[result setStartTime:startTime];
	[result setStartingFrame:startingFrame];
	[result setFramesToPlay:framesToPlay];
	[result setLoopCount:loopCount];
	
	return [result autorelease];
}

- (void) dealloc
{
	[_decoder release], _decoder = nil;
	
	deallocate_slice_buffer(&_sliceBuffer, [self numberOfSlicesInBuffer]);
	
	[super dealloc];
}

#pragma mark Properties

- (AudioTimeStamp)	startTime								{ return _startTime; }

- (void) setStartTime:(AudioTimeStamp)startTime
{
	NSParameterAssert(kAudioTimeStampSampleTimeValid & startTime.mFlags);
	
	_startTime = startTime;
}

- (AudioDecoder *)	decoder									{ return [[_decoder retain] autorelease]; }

- (void) setDecoder:(AudioDecoder *)decoder
{
	NSParameterAssert(nil != decoder);
	NSParameterAssert(kAudioFormatFlagsNativeFloatPacked & [decoder format].mFormatFlags);
	NSParameterAssert(kAudioFormatFlagIsNonInterleaved & [decoder format].mFormatFlags);
	
	[_decoder release];
	_decoder = [decoder retain];	
}

- (unsigned)		loopCount								{ return _loopCount; }
- (void)			setLoopCount:(unsigned)loopCount 		{ _loopCount = loopCount; }

- (SInt64)			startingFrame							{ return _startingFrame; }

- (void) setStartingFrame:(SInt64)startingFrame
{
	NSParameterAssert(0 <= startingFrame);
	
	_startingFrame = startingFrame;
}

- (UInt32)			framesToPlay							{ return _framesToPlay; }

- (void) setFramesToPlay:(UInt32)framesToPlay
{
	NSParameterAssert(0 < framesToPlay);

	_framesToPlay = framesToPlay;
}

#pragma mark Playback

- (unsigned)		completedLoops							{ return _completedLoops; }

- (SInt64)			totalFrames								{ return (([self loopCount] + 1) * [self framesToPlay]); }
- (SInt64)			currentFrame							{ return _totalFramesRead; }
- (SInt64)			framesRemaining							{ return ([self totalFrames] - [self currentFrame]); }

- (BOOL)			supportsSeeking							{ return [[self decoder] supportsSeeking]; }

- (SInt64) seekToFrame:(SInt64)frame
{
	NSParameterAssert(0 <= frame && frame < [self totalFrames]);
	
	_completedLoops				= frame / [self framesToPlay];
	_framesReadInCurrentLoop	= frame % [self framesToPlay];
	_totalFramesRead			= frame;
	_atEnd						= NO;

	[[self decoder] seekToFrame:[self startingFrame] + _framesReadInCurrentLoop];
	
	return [self currentFrame];
}

- (SInt64)			framesScheduled							{ return _framesScheduled; }
- (SInt64)			framesRendered							{ return _framesRendered; }

- (NSString *) description
{
	return [NSString stringWithFormat:@"%@ (%qi, %qi)", [self decoder], [self framesRendered], [self framesScheduled]];
}

@end

@implementation ScheduledAudioRegion (AudioSchedulerMethods)

- (unsigned) numberOfSlicesInBuffer
{
	return _numberSlices;
}

- (unsigned) numberOfFramesPerSlice
{
	return _framesPerSlice;
}

- (void) allocateBuffersWithSliceCount:(unsigned)sliceCount frameCount:(unsigned)frameCount
{
	NSParameterAssert(0 < sliceCount);
	NSParameterAssert(0 < frameCount);
	
	_numberSlices		= sliceCount;
	_framesPerSlice		= frameCount;
	
	// Allocate the buffers for the AudioScheduler to use
	deallocate_slice_buffer(&_sliceBuffer, [self numberOfSlicesInBuffer]);
	AudioStreamBasicDescription format = [[self decoder] format];
	_sliceBuffer = allocate_slice_buffer_for_asbd(&format, [self numberOfSlicesInBuffer], [self numberOfFramesPerSlice]);
}

- (void) clearSliceBuffer
{
	clear_slice_buffer(_sliceBuffer,[self numberOfSlicesInBuffer], [self numberOfFramesPerSlice]);
}

- (void) clearSlice:(unsigned)sliceIndex
{
	NSParameterAssert(sliceIndex < [self numberOfSlicesInBuffer]);

	clear_buffer_list(_sliceBuffer[sliceIndex].mBufferList, [self numberOfFramesPerSlice]);
}

- (void) reset
{
	[[self decoder] seekToFrame:[self startingFrame]];
	
	_framesReadInCurrentLoop	= 0;
	_totalFramesRead			= 0;
	_completedLoops				= 0;
	_atEnd						= NO;
}

- (void)			clearFramesScheduled					{ _framesScheduled = 0; }
- (void)			clearFramesRendered						{ _framesRendered = 0; }

- (UInt32) readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount
{
	NSParameterAssert(NULL != bufferList);
	NSParameterAssert(0 < frameCount);
	
	if([self loopCount] < [self completedLoops])
		return 0;

	UInt32	framesRemaining		= [self startingFrame] + [self framesToPlay] - [[self decoder] currentFrame];
	UInt32	framesToRead		= (frameCount < framesRemaining ? frameCount : framesRemaining);
	UInt32	framesRead			= 0;
	
	if(0 < framesToRead)
		framesRead = [[self decoder] readAudio:bufferList frameCount:framesToRead];
	
	_framesReadInCurrentLoop	+= framesRead;
	_totalFramesRead			+= framesRead;
	
	if([self framesToPlay] == _framesReadInCurrentLoop || (0 == framesRead && 0 != framesToRead)) {
		[[self decoder] seekToFrame:[self startingFrame]];
		++_completedLoops;
		_framesReadInCurrentLoop = 0;		
	}
	
	if([self loopCount] < [self completedLoops])
		_atEnd = YES;
	
	return framesRead;	
}

- (UInt32) readAudioInSlice:(unsigned)sliceIndex
{
	NSParameterAssert(sliceIndex < [self numberOfSlicesInBuffer]);

	return [self readAudio:_sliceBuffer[sliceIndex].mBufferList frameCount:[self numberOfFramesPerSlice]];
}

- (ScheduledAudioSlice *) buffer
{
	return _sliceBuffer;
}

- (ScheduledAudioSlice *) sliceAtIndex:(unsigned)sliceIndex
{
	NSParameterAssert(sliceIndex < [self numberOfSlicesInBuffer]);

	return _sliceBuffer + sliceIndex;
}

- (void) scheduledAdditionalFrames:(UInt32)frameCount
{
	_framesScheduled += frameCount;
}

- (void) renderedAdditionalFrames:(UInt32)frameCount
{
	_framesRendered += frameCount;
}

- (BOOL) atEnd
{
	return _atEnd;
}

@end
