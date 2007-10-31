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

#import "AudioDecoderMethods.h"

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

// Superclass for an audio decoder covering an entire file
@interface AudioDecoder : NSObject <AudioDecoderMethods>
{
	NSURL							*_url;				// The location of the stream to be decoded
	
	AudioStreamBasicDescription		_format;			// The type of PCM data provided by this decoder
	AudioChannelLayout				_channelLayout;		// The channel layout for the PCM data	

	AudioStreamBasicDescription		_sourceFormat;		// The native (PCM) format of the source file
}

// Return an AudioDecoder of the appropriate class
+ (AudioDecoder *) decoderWithURL:(NSURL *)url error:(NSError **)error;

// Designated initializer
- (id) initWithURL:(NSURL *)url error:(NSError **)error;

// The stream this decoder will process
- (NSURL *) URL;
@end
