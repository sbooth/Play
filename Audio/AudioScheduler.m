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

#import "AudioScheduler.h"
#import "ScheduledAudioRegion.h"
#import "AudioDecoder.h"

// ========================================
// Dictionary keys
// ========================================
NSString * const	AudioSchedulerObjectKey				= @"org.sbooth.Play.AudioScheduler";
NSString * const	ScheduledAudioRegionObjectKey		= @"org.sbooth.Play.ScheduledAudioRegion";

// ========================================
// Symbolic Constants
// ========================================
NSString * const	AudioSchedulerRunLoopMode			= @"org.sbooth.Play.AudioScheduler.RunLoopMode";

// ========================================
// Buffer parameters
// ========================================
#define NUMBER_OF_SLICES_IN_BUFFER		10
#define FRAMES_PER_SLICE				2048

// ========================================
// Friends
// ========================================
@interface ScheduledAudioRegion (AudioSchedulerMethods)
- (void) reset;

- (void) clearFramesScheduled;
- (void) clearFramesRendered;

- (UInt32) readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount;

- (ScheduledAudioSlice *) buffer;

- (void) scheduledAdditionalFrames:(UInt32)frameCount;
- (void) renderedAdditionalFrames:(UInt32)frameCount;

- (BOOL) atEnd;
@end

// ========================================
// Private methods
// ========================================
@interface AudioScheduler (Private)
- (semaphore_t) semaphore;

- (NSMutableArray *) scheduledAudioRegions;

- (void) setRegionBeingScheduled:(ScheduledAudioRegion *)region;
- (void) setRegionBeingRendered:(ScheduledAudioRegion *)region;

- (BOOL) keepScheduling;

- (void) scheduledAdditionalFrames:(UInt32)frameCount;
- (void) renderedAdditionalFrames:(UInt32)frameCount;

- (void) processSlicesInThread:(id)dummy;
- (void) setThreadPolicy;
@end

// ========================================
// AudioUnit callbacks
// ========================================
static void
scheduledAudioSliceCompletionProc(void *userData, ScheduledAudioSlice *slice)
{
	NSAutoreleasePool	*pool		= [[NSAutoreleasePool alloc] init];
	AudioScheduler		*scheduler	= (AudioScheduler *)userData;

#if DEBUG
	if(kScheduledAudioSliceFlag_BeganToRenderLate & slice->mFlags)
		printf("AudioScheduler error: kScheduledAudioSliceFlag_BeganToRenderLate (starting sample %qi)\n", (SInt64)slice->mTimeStamp.mSampleTime);
#endif

	// Determine if this render represents a  new region
	if(/*(kScheduledAudioSliceFlag_BeganToRender & slice->mFlags) &&*/ nil == [scheduler regionBeingRendered]) {

		// Update the scheduler
		[scheduler setRegionBeingRendered:[scheduler regionBeingScheduled]];
		
		// Notify the delegate
		if(nil != [scheduler delegate] && [[scheduler delegate] respondsToSelector:@selector(audioSchedulerStartedRenderingRegion:)])
			[[scheduler delegate] performSelectorOnMainThread:@selector(audioSchedulerStartedRenderingRegion:)
												   withObject:[NSDictionary dictionaryWithObjectsAndKeys:scheduler, AudioSchedulerObjectKey, [scheduler regionBeingRendered], ScheduledAudioRegionObjectKey, nil]
												waitUntilDone:NO];
	}

	// Record the number of frames rendered
//	if(kScheduledAudioSliceFlag_BeganToRender & slice->mFlags)
		[scheduler renderedAdditionalFrames:slice->mNumberFrames];
		
	// Signal the scheduling thread that a slice is available for filling
	semaphore_signal([scheduler semaphore]);

	// Determine if region rendering is complete
	if([[scheduler regionBeingRendered] atEnd] && [[scheduler regionBeingRendered] framesRendered] == [[scheduler regionBeingRendered] framesScheduled]) {

		// Notify the delegate
		if(nil != [scheduler delegate] && [[scheduler delegate] respondsToSelector:@selector(audioSchedulerFinishedRenderingRegion:)])
			[[scheduler delegate] performSelectorOnMainThread:@selector(audioSchedulerFinishedRenderingRegion:)
												   withObject:[NSDictionary dictionaryWithObjectsAndKeys:scheduler, AudioSchedulerObjectKey, [scheduler regionBeingRendered], ScheduledAudioRegionObjectKey, nil]
												waitUntilDone:NO];

		// Update the scheduler
		[scheduler setRegionBeingRendered:nil];
	}

	[pool release];
}

// ========================================
// Helper functions
// ========================================
void
allocate_slice_for_asbd(const AudioStreamBasicDescription *asbd, ScheduledAudioSlice *slice)
{
	NSCParameterAssert(NULL != asbd);
	NSCParameterAssert(NULL != slice);
	
	// Allocate the buffer list
	slice->mBufferList = calloc(sizeof(AudioBufferList) + (sizeof(AudioBuffer) * (asbd->mChannelsPerFrame - 1)), 1);
	NSCAssert(NULL != slice->mBufferList, @"Unable to allocate memory");
	
	slice->mBufferList->mNumberBuffers = asbd->mChannelsPerFrame;

	unsigned i;
	for(i = 0; i < slice->mBufferList->mNumberBuffers; ++i) {
		slice->mBufferList->mBuffers[i].mData = calloc(FRAMES_PER_SLICE, sizeof(float));
		NSCAssert(NULL != slice->mBufferList->mBuffers[i].mData, @"Unable to allocate memory");
		slice->mBufferList->mBuffers[i].mDataByteSize = FRAMES_PER_SLICE * sizeof(float);
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
allocate_slice_buffer_for_asbd(const AudioStreamBasicDescription *asbd)
{
	NSCParameterAssert(NULL != asbd);
	
	ScheduledAudioSlice *sliceBuffer = calloc(NUMBER_OF_SLICES_IN_BUFFER, sizeof(ScheduledAudioSlice));
	NSCAssert(NULL != sliceBuffer, @"Unable to allocate memory");
	
	unsigned i;
	for(i = 0; i < NUMBER_OF_SLICES_IN_BUFFER; ++i)
		allocate_slice_for_asbd(asbd, sliceBuffer + i);
	
	return sliceBuffer;
}

void
deallocate_slice_buffer(ScheduledAudioSlice **sliceBuffer)
{
	NSCParameterAssert(NULL != sliceBuffer);
	
	if(NULL == *sliceBuffer)
		return;
	
	unsigned i;
	for(i = 0; i < NUMBER_OF_SLICES_IN_BUFFER; ++i)
		deallocate_slice(*sliceBuffer + i);
	
	free(*sliceBuffer), *sliceBuffer = NULL;
}

static void
clear_buffer_list(AudioBufferList *bufferList)
{
	NSCParameterAssert(NULL != bufferList);
	
	unsigned i;
	for(i = 0; i < bufferList->mNumberBuffers; ++i) {
		bufferList->mBuffers[i].mDataByteSize = FRAMES_PER_SLICE * sizeof(float);
		memset(bufferList->mBuffers[i].mData, 0, bufferList->mBuffers[i].mDataByteSize);
	}
}

static void
clear_slice_buffer(ScheduledAudioSlice *sliceBuffer)
{
	NSCParameterAssert(NULL != sliceBuffer);
	
	unsigned i, j;
	for(i = 0; i < NUMBER_OF_SLICES_IN_BUFFER; ++i) {
		for(j = 0; j < sliceBuffer[i].mBufferList->mNumberBuffers; ++j)
			clear_buffer_list(sliceBuffer[i].mBufferList);
		sliceBuffer[i].mFlags = kScheduledAudioSliceFlag_Complete;
	}
}

@implementation AudioScheduler

- (id) init
{	
	if((self = [super init])) {
		kern_return_t result = semaphore_create(mach_task_self(), &_semaphore, SYNC_POLICY_FIFO, 0);		
		if(KERN_SUCCESS != result) {
			mach_error("Couldn't create semaphore", result);
			[self release];
			return nil;
		}
		
		_scheduledStartTime.mSampleTime	= 0;
		_scheduledStartTime.mFlags		= kAudioTimeStampSampleTimeValid;
	}
	return self;
}

- (void) dealloc
{
	if([self isScheduling])
		[self stopScheduling];

	[_regionBeingScheduled release], _regionBeingScheduled = nil;
	[_regionBeingRendered release], _regionBeingRendered = nil;

	[_scheduledAudioRegions release], _scheduledAudioRegions = nil;
	_delegate = nil;

	[super dealloc];
}

- (AudioUnit) audioUnit
{
	return _audioUnit;
}

- (void) setAudioUnit:(AudioUnit)audioUnit
{
	NSParameterAssert(NULL != audioUnit);

	// Ensure the audio unit is a ScheduledSoundPlayer
	ComponentDescription componentDescription;
	ComponentResult err = GetComponentInfo((Component)audioUnit,
										   &componentDescription,
										   NULL,
										   NULL,
										   NULL);
	if(noErr != err || 
	   kAudioUnitType_Generator != componentDescription.componentType || 
	   kAudioUnitSubType_ScheduledSoundPlayer != componentDescription.componentSubType) {
		NSLog(@"Illegal audio unit passed to setAudioUnit");
		return;
	}

	_audioUnit = audioUnit;
}

- (id) delegate
{
	return _delegate;
}

- (void) setDelegate:(id)delegate
{
	_delegate = delegate;
}

- (AudioTimeStamp) scheduledStartTime
{
	return _scheduledStartTime;
}

- (void) setScheduledStartTime:(AudioTimeStamp)scheduledStartTime
{
	NSParameterAssert(kAudioTimeStampSampleTimeValid & scheduledStartTime.mFlags);
	_scheduledStartTime = scheduledStartTime;
}

- (void) scheduleAudioRegion:(ScheduledAudioRegion *)scheduledAudioRegion
{
	NSParameterAssert(nil != scheduledAudioRegion);
	
	@synchronized([self scheduledAudioRegions]) {
		[[self scheduledAudioRegions] addObject:scheduledAudioRegion];
	}

	semaphore_signal([self semaphore]);
}

- (void) unscheduleAudioRegion:(ScheduledAudioRegion *)scheduledAudioRegion
{
	NSParameterAssert(nil != scheduledAudioRegion);
	
	if([self regionBeingScheduled] == scheduledAudioRegion) {
		if([self isScheduling])
			NSLog(@"Cannot unschedule the current ScheduledAudioRegion while scheduling audio slices");
		else
			// This operation is thread safe as long as the scheduling thread isn't active
			[_regionBeingScheduled release], _regionBeingScheduled = nil;
		
		return;
	}
	
	@synchronized([self scheduledAudioRegions]) {
		[[self scheduledAudioRegions] removeObjectIdenticalTo:scheduledAudioRegion];
	}
}

- (ScheduledAudioRegion *) regionBeingScheduled
{
	return [[_regionBeingScheduled retain] autorelease];
}

- (ScheduledAudioRegion *) regionBeingRendered
{
	return [[_regionBeingRendered retain] autorelease];
}

- (void) startScheduling
{
	if(NULL == [self audioUnit] || [self isScheduling])
		return;

	_framesScheduled		= 0;
	_framesRendered			= 0;
	_keepScheduling			= YES;
	_scheduling				= YES;
	
	[[self regionBeingScheduled] clearFramesScheduled];
	[[self regionBeingScheduled] clearFramesRendered];

	// Rather than set regionBeingRendered to nil, just clear to avoid repeat startedRenderingRegion: notifications
	[[self regionBeingRendered] clearFramesScheduled];
	[[self regionBeingRendered] clearFramesRendered];

	[NSThread detachNewThreadSelector:@selector(processSlicesInThread:) toTarget:self withObject:nil];
}

- (void) stopScheduling
{
	if(NO == [self isScheduling])
		return;
	
	// Signal the scheduling thread that it may exit
	_keepScheduling = NO;
	semaphore_signal([self semaphore]);

	// Wait for the thread to terminate
	while([self isScheduling])
		[[NSRunLoop currentRunLoop] runMode:AudioSchedulerRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
}

- (void) reset
{
	if([self isScheduling])
		return;
	
	// Remove any scheduled slices by resetting the AUScheduledSoundPlayer
	ComponentResult result = AudioUnitReset([self audioUnit],
											kAudioUnitScope_Global, 
											0);
	if(noErr != result)
		NSLog(@"AudioUnitReset failed");

	if(nil != [self regionBeingScheduled])
		clear_slice_buffer([[self regionBeingScheduled] buffer]);
	if(nil != [self regionBeingRendered])
		clear_slice_buffer([[self regionBeingRendered] buffer]);
}


- (void) clear
{
	if([self isScheduling])
		return;
	
	[self reset];
	
	[self setRegionBeingScheduled:nil];
	[self setRegionBeingRendered:nil];
	
	// This is thread safe because the scheduling thread is inactive
	[[self scheduledAudioRegions] removeAllObjects];
}

- (BOOL) isScheduling
{
	return _scheduling;
}

- (BOOL) isRendering
{
	AudioTimeStamp timeStamp = [self currentPlayTime];
	return (kAudioTimeStampSampleTimeValid & timeStamp.mFlags && -1 != timeStamp.mSampleTime);
}

- (AudioTimeStamp) currentPlayTime
{
	// Determine the last sample that was rendered
	AudioTimeStamp		timeStamp	= { 0 };
	UInt32				dataSize	= sizeof(AudioTimeStamp);
	ComponentResult		result		= AudioUnitGetProperty([self audioUnit],
														   kAudioUnitProperty_CurrentPlayTime,
														   kAudioUnitScope_Global,
														   0,
														   &timeStamp,
														   &dataSize);

	if(noErr != result)
		NSLog(@"Unable to query kAudioUnitProperty_CurrentPlayTime");
	
	return timeStamp;
}

- (SInt64)			framesScheduled					{ return _framesScheduled; }
- (SInt64)			framesRendered					{ return _framesRendered; }

@end

@implementation AudioScheduler (Private)

- (semaphore_t)		semaphore						{ return _semaphore; }

- (NSMutableArray *) scheduledAudioRegions
{
	if(nil == _scheduledAudioRegions)
		_scheduledAudioRegions = [[NSMutableArray alloc] init];
	return _scheduledAudioRegions;
}

- (void) setRegionBeingScheduled:(ScheduledAudioRegion *)region
{
	[_regionBeingScheduled release], _regionBeingScheduled = [region retain];
}

- (void) setRegionBeingRendered:(ScheduledAudioRegion *)region
{
	[_regionBeingRendered release], _regionBeingRendered = [region retain];
}

- (BOOL)			keepScheduling					{ return _keepScheduling; }

- (void) scheduledAdditionalFrames:(UInt32)frameCount
{
	_framesScheduled += frameCount;
	[[self regionBeingScheduled] scheduledAdditionalFrames:frameCount];
}

- (void) renderedAdditionalFrames:(UInt32)frameCount
{
	_framesRendered += frameCount;
	[[self regionBeingRendered] renderedAdditionalFrames:frameCount];
}

- (void) processSlicesInThread:(id)dummy
{
	NSAutoreleasePool		*pool				= [[NSAutoreleasePool alloc] init];
	mach_timespec_t			timeout				= { 2, 0 };
	ScheduledAudioSlice		*slice				= NULL;
	UInt32					frameCount			= 0;
	BOOL					allFramesScheduled	= NO;
	unsigned				i;
	
	// Make this a high-priority thread
	[self setThreadPolicy];
	
	// Notify the delegate that scheduling has started
	if(nil != [self delegate] && [[self delegate] respondsToSelector:@selector(audioSchedulerStartedScheduling:)])
		[[self delegate] performSelectorOnMainThread:@selector(audioSchedulerStartedScheduling:) withObject:self waitUntilDone:NO];

	// Outer scheduling loop, for looping over regions
	while([self keepScheduling]) {

		// Grab the next ScheduledAudioRegion to work with
		if(nil == [self regionBeingScheduled]) {

			@synchronized([self scheduledAudioRegions]) {
				[self setRegionBeingScheduled:[[self scheduledAudioRegions] lastObject]];
				if(nil != [self regionBeingScheduled])
					[[self scheduledAudioRegions] removeLastObject];
			}

			// If a new region was found, notify the delegate
			if(nil != [self regionBeingScheduled]) {
				allFramesScheduled = NO;			
				
				// Notify the delegate that the scheduling has been started for the current region
				if(nil != [self delegate] && [[self delegate] respondsToSelector:@selector(audioSchedulerStartedSchedulingRegion:)])
					[[self delegate] performSelectorOnMainThread:@selector(audioSchedulerStartedSchedulingRegion:)
													  withObject:[NSDictionary dictionaryWithObjectsAndKeys:self, AudioSchedulerObjectKey, _regionBeingScheduled, ScheduledAudioRegionObjectKey, nil]
												   waitUntilDone:NO];
			}
		}
		
		// Inner scheduling loop, for processing an individual region
		while([self keepScheduling] && nil != [self regionBeingScheduled] && NO == allFramesScheduled) {

			// Iterate through the slice buffer, scheduling audio as completed slices become available
			for(i = 0; i < NUMBER_OF_SLICES_IN_BUFFER; ++i) {
				slice = [[self regionBeingScheduled] buffer] + i;
				
				// If the slice is marked as complete, re-use it
				if(kScheduledAudioSliceFlag_Complete & slice->mFlags) {
					
					// Prepare the slice
					clear_buffer_list(slice->mBufferList);
					
					// Read some data
					frameCount = [[self regionBeingScheduled] readAudio:slice->mBufferList frameCount:FRAMES_PER_SLICE];
					
					// EOS?
					if(0 == frameCount) {
						allFramesScheduled = YES;
						
						// Notify the delegate that the last frame of the current region has been scheduled
						if(nil != [self delegate] && [[self delegate] respondsToSelector:@selector(audioSchedulerFinishedSchedulingRegion:)])
							[[self delegate] performSelectorOnMainThread:@selector(audioSchedulerFinishedSchedulingRegion:)
															  withObject:[NSDictionary dictionaryWithObjectsAndKeys:self, AudioSchedulerObjectKey, _regionBeingScheduled, ScheduledAudioRegionObjectKey, nil]
														   waitUntilDone:NO];
						
						// This region is finished
						[self setRegionBeingScheduled:nil];
						
						break;
					}
					
					// Time stamp for this slice
					AudioTimeStamp timeStamp;
					
					timeStamp.mFlags		= kAudioTimeStampSampleTimeValid;
					timeStamp.mSampleTime	= [self scheduledStartTime].mSampleTime + [self framesScheduled];
					
					// Schedule it
					slice->mTimeStamp				= timeStamp;
					slice->mCompletionProc			= scheduledAudioSliceCompletionProc;
					slice->mCompletionProcUserData	= (void *)self;
					slice->mFlags					= 0;
					slice->mNumberFrames			= frameCount;
					
					ComponentResult err = AudioUnitSetProperty([self audioUnit],
															   kAudioUnitProperty_ScheduleAudioSlice, 
															   kAudioUnitScope_Global, 
															   0,
															   slice, 
															   sizeof(ScheduledAudioSlice));
					if(noErr != err) {
						NSLog(@"AudioUnitSetProperty failed: %d", err);
						continue;
					}
					
	#if EXTENDED_DEBUG
					NSLog(@"Scheduling slice %i (%i frames) to start at sample %f", i, frameCount, timeStamp.mSampleTime);
	#endif

					[self scheduledAdditionalFrames:frameCount];
				}
			}

			// Sleep until we are signaled or the timeout happens
			semaphore_timedwait([self semaphore], timeout);
		}		

		// Sleep until we are signaled or the timeout happens
		semaphore_timedwait([self semaphore], timeout);
	}
	
	_scheduling = NO;
	
	// Notify the delegate that scheduling has stopped
	if(nil != [self delegate] && [[self delegate] respondsToSelector:@selector(audioSchedulerStoppedScheduling:)])
		[[self delegate] performSelectorOnMainThread:@selector(audioSchedulerStoppedScheduling:) withObject:self waitUntilDone:NO];
	
	[pool release];
}

- (void) setThreadPolicy
{
	thread_extended_policy_data_t		extendedPolicy;
	thread_precedence_policy_data_t		precedencePolicy;
	
	extendedPolicy.timeshare		= 0;
	precedencePolicy.importance		= 6;
	
	kern_return_t result = thread_policy_set(mach_thread_self(), 
											 THREAD_EXTENDED_POLICY,  
											 (thread_policy_t)&extendedPolicy, 
											 THREAD_EXTENDED_POLICY_COUNT);
	
#if DEBUG
	if(KERN_SUCCESS != result)
		mach_error("Couldn't set AudioScheduler's scheduling thread's extended policy", result);
#endif
	
	result = thread_policy_set(mach_thread_self(), 
							   THREAD_PRECEDENCE_POLICY, 
							   (thread_policy_t)&precedencePolicy, 
							   THREAD_PRECEDENCE_POLICY_COUNT);
	
#if DEBUG
	if(KERN_SUCCESS != result)
		mach_error("Couldn't set AudioScheduler's scheduling thread's precedence policy", result);
#endif
}

@end
