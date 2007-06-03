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

@class AudioDecoder;

@interface ScheduledAudioRegion : NSObject
{
	AudioDecoder			*_decoder;
	AudioTimeStamp			_startTime;
	SInt64					_startingFrame;
	UInt32					_framesToPlay;
	unsigned				_loopCount;
	
	UInt32					_framesReadInCurrentLoop;
	SInt64					_totalFramesRead;
	unsigned				_completedLoops;
	
	SInt64					_framesScheduled;
	SInt64					_framesRendered;
}	

// ========================================
// Creation
// ========================================
+ (ScheduledAudioRegion *) scheduledAudioRegionForDecoder:(AudioDecoder *)decoder;

+ (ScheduledAudioRegion *) scheduledAudioRegionForDecoder:(AudioDecoder *)decoder startingFrame:(SInt64)startingFrame;
+ (ScheduledAudioRegion *) scheduledAudioRegionForDecoder:(AudioDecoder *)decoder startingFrame:(SInt64)startingFrame framesToPlay:(unsigned)framesToPlay;
+ (ScheduledAudioRegion *) scheduledAudioRegionForDecoder:(AudioDecoder *)decoder startingFrame:(SInt64)startingFrame framesToPlay:(unsigned)framesToPlay loopCount:(unsigned)loopCount;

+ (ScheduledAudioRegion *) scheduledAudioRegionForDecoder:(AudioDecoder *)decoder startTime:(AudioTimeStamp)startTime;
+ (ScheduledAudioRegion *) scheduledAudioRegionForDecoder:(AudioDecoder *)decoder startTime:(AudioTimeStamp)startTime startingFrame:(SInt64)startingFrame;
+ (ScheduledAudioRegion *) scheduledAudioRegionForDecoder:(AudioDecoder *)decoder startTime:(AudioTimeStamp)startTime startingFrame:(SInt64)startingFrame framesToPlay:(unsigned)framesToPlay;
+ (ScheduledAudioRegion *) scheduledAudioRegionForDecoder:(AudioDecoder *)decoder startTime:(AudioTimeStamp)startTime startingFrame:(SInt64)startingFrame framesToPlay:(unsigned)framesToPlay loopCount:(unsigned)loopCount;

// ========================================
// Properties
// ========================================
- (AudioDecoder *) decoder;
- (void) setDecoder:(AudioDecoder *)decoder;

- (AudioTimeStamp) startTime;
- (void) setStartTime:(AudioTimeStamp)startTime;

- (SInt64) startingFrame;
- (void) setStartingFrame:(SInt64)startingFrame;

- (UInt32) framesToPlay;
- (void) setFramesToPlay:(UInt32)fframesToPlay;

- (unsigned) loopCount;
- (void) setLoopCount:(unsigned)loopCount;

// ========================================
// Audio access
// ========================================
- (unsigned) completedLoops;

- (UInt32) totalFrames;
- (SInt64) currentFrame;
- (SInt64) seekToFrame:(SInt64)frame;

- (SInt64) framesScheduled;
- (SInt64) framesRendered;

@end
