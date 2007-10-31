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

#include <CoreAudio/CoreAudioTypes.h>

// ========================================
// A decoder is responsible for reading audio data in some format and providing
// it as 32-bit float non-interleaved PCM (canonical Core Audio format)
// ========================================
@protocol AudioDecoderMethods
// The type of PCM data provided by this decoder
- (AudioStreamBasicDescription) format;
- (NSString *) formatDescription;

// The layout of the channels this decoder provides
- (AudioChannelLayout) channelLayout;
- (NSString *) channelLayoutDescription;

// Attempt to read frameCount frames of audio, returning the actual number of frames read
- (UInt32) readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount;

// The native (PCM) format of the source
- (AudioStreamBasicDescription) sourceFormat;
- (NSString *) sourceFormatDescription;

// Source audio information
- (SInt64) totalFrames;
- (SInt64) currentFrame;
- (SInt64) framesRemaining;

// Seeking support
- (BOOL) supportsSeeking;
- (SInt64) seekToFrame:(SInt64)frame;
@end
