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

#import <Cocoa/Cocoa.h>
#include <AudioUnit/AudioUnit.h>

@class AudioLibrary;
@class AudioStream;
@class AudioStreamDecoder;
@class SecondsFormatter;

@interface AudioPlayer : NSObject
{
	AudioUnit				_audioUnit;
	AudioStreamDecoder		*_streamDecoder;
	
	AudioStreamDecoder		*_nextStreamDecoder;
	BOOL					_requestedNextStream;
	
	AudioLibrary			*_owner;
	
	BOOL					_isPlaying;

	SInt64					_frameCounter;
	NSFormatter				*_secondsFormatter;
	
	NSRunLoop				*_runLoop;
}

- (AudioLibrary *)	owner;
- (void)			setOwner:(AudioLibrary *)owner;

- (BOOL)			setStream:(AudioStream *)stream error:(NSError **)error;
- (BOOL)			setNextStream:(AudioStream *)stream error:(NSError **)error;

- (void)			reset;

- (BOOL)			hasValidStream;
- (BOOL)			streamSupportsSeeking;

- (void)			play;
- (void)			playPause;
- (void)			stop;

- (void)			skipForward;
- (void)			skipBackward;
- (void)			skipForward:(UInt32)seconds;
- (void)			skipBackward:(UInt32)seconds;

- (void)			skipToEnd;
- (void)			skipToBeginning;

- (BOOL)			isPlaying;

- (Float32)			volume;
- (void)			setVolume:(Float32)volume;

// UI bindings (updated approximately once per second to avoid excessive CPU loads)
- (SInt64)			totalFrames;

- (SInt64)			currentFrame;
- (void)			setCurrentFrame:(SInt64)currentFrame;

- (NSString *)		totalSecondsString;
- (NSString *)		currentSecondString;
- (NSString *)		secondsRemainingString;

@end
