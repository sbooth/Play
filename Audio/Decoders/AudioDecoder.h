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
#include <CoreAudio/CoreAudioTypes.h>

// ========================================
// Error Codes
// ========================================
extern NSString * const			AudioDecoderErrorDomain;

enum {
	AudioDecoderFileNotFoundError				= 0,
	AudioDecoderFileFormatNotRecognizedError	= 1,
	AudioDecoderFileFormatNotSupportedError		= 2,
	AudioDecoderInputOutputError				= 3
};

@class AudioStream;

// A decoder reads audio data in some format and provides it as 32-bit float non-interleaved PCM
@interface AudioDecoder : NSObject
{
	AudioStream						*_stream;			// The stream to be decoded
	
	AudioStreamBasicDescription		_format;			// The type of PCM data provided by this decoder
	AudioChannelLayout				_channelLayout;		// The channel layout for the PCM data	
}

+ (AudioDecoder *) audioDecoderForStream:(AudioStream *)stream error:(NSError **)error;

// Designated initializer
- (id) initWithStream:(AudioStream *)stream error:(NSError **)error;

// The stream this decoder will process
- (AudioStream *) stream;

// The type of PCM data provided by this AudioDecoder
- (AudioStreamBasicDescription) format;
- (NSString *) formatDescription;

// The layout of the channels this AudioDecoder provides
- (AudioChannelLayout) channelLayout;
- (NSString *) channelLayoutDescription;

// Attempt to read frameCount frames of audio, returning the actual number of frames read
- (UInt32) readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount;

// ========================================
// Input audio information
// ========================================
- (SInt64) totalFrames;
- (SInt64) currentFrame;
- (SInt64) framesRemaining;

- (BOOL) supportsSeeking;
- (SInt64) seekToFrame:(SInt64)frame;

// ========================================
// Subclasses must implement these methods!
// ========================================

// The format of audio data contained in the raw stream at _url
- (NSString *) sourceFormatDescription;

@end
