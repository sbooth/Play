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

#import <Cocoa/Cocoa.h>
#include <AudioToolbox/AudioToolbox.h>

#import "AudioDecoderMethods.h"

// A class encapsulating an AudioDecoder and the buffers and associated internal state that 
// AudioScheduler needs to use a decoder
@interface ScheduledAudioRegion : NSObject
{
	id <AudioDecoderMethods>	_decoder;
	BOOL						_atEnd;
	
	AudioTimeStamp				_startTime;
	
	ScheduledAudioSlice			*_sliceBuffer;

	unsigned					_numberSlices;
	unsigned					_framesPerSlice;

	SInt64						_framesScheduled;
	SInt64						_framesRendered;
}	

+ (ScheduledAudioRegion *) scheduledAudioRegionWithDecoder:(id <AudioDecoderMethods>)decoder;
+ (ScheduledAudioRegion *) scheduledAudioRegionWithDecoder:(id <AudioDecoderMethods>)decoder startTime:(AudioTimeStamp)startTime;

- (id) initWithDecoder:(id <AudioDecoderMethods>)decoder;
- (id) initWithDecoder:(id <AudioDecoderMethods>)decoder startTime:(AudioTimeStamp)startTime;

- (id <AudioDecoderMethods>) decoder;
- (void) setDecoder:(id <AudioDecoderMethods>)decoder;

- (BOOL) atEnd;

- (AudioTimeStamp) startTime;
- (void) setStartTime:(AudioTimeStamp)startTime;

- (SInt64) framesScheduled;
- (SInt64) framesRendered;

- (unsigned) numberOfSlicesInBuffer;
- (unsigned) numberOfFramesPerSlice;

- (void) allocateBuffersWithSliceCount:(unsigned)sliceCount frameCount:(unsigned)frameCount;
- (void) clearSliceBuffer;
- (void) clearSlice:(unsigned)sliceIndex;

- (void) clearFramesScheduled;
- (void) clearFramesRendered;

- (UInt32) readAudioInSlice:(unsigned)sliceIndex;

- (ScheduledAudioSlice *) buffer;
- (ScheduledAudioSlice *) sliceAtIndex:(unsigned)sliceIndex;

- (void) scheduledAdditionalFrames:(UInt32)frameCount;
- (void) renderedAdditionalFrames:(UInt32)frameCount;
@end
