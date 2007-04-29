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

#import "CoreAudioStreamDecoder.h"
#import "AudioStream.h"
#include <AudioToolbox/AudioFormat.h>

@implementation CoreAudioStreamDecoder

- (NSString *) sourceFormatDescription
{
	OSStatus						result;
	UInt32							specifierSize;
	AudioStreamBasicDescription		asbd;
	NSString						*fileFormat;
	
	// Query file type
	specifierSize		= sizeof(AudioStreamBasicDescription);
	result				= ExtAudioFileGetProperty(_extAudioFile, kExtAudioFileProperty_FileDataFormat, &specifierSize, &asbd);
	NSAssert1(noErr == result, @"AudioFileGetProperty failed: %@", UTCreateStringForOSType(result));

	specifierSize		= sizeof(fileFormat);
	result				= AudioFormatGetProperty(kAudioFormatProperty_FormatName, sizeof(AudioStreamBasicDescription), &asbd, &specifierSize, &fileFormat);
	NSAssert1(noErr == result, @"AudioFormatGetProperty failed: %@", UTCreateStringForOSType(result));
	
	return [fileFormat autorelease];
}

- (BOOL) supportsSeeking
{
	return YES;
}

- (SInt64) performSeekToFrame:(SInt64)frame
{
	OSStatus	result;
	
	result			= ExtAudioFileSeek(_extAudioFile, frame);
	
	if(noErr != result) {
		return -1;
	}
	
	return frame;
}

- (BOOL) setupDecoder:(NSError **)error
{
	OSStatus						result;
	NSString						*path;
	UInt32							dataSize;
	FSRef							ref;
	SInt64							totalFrames;
	AudioStreamBasicDescription		asbd;
	AudioChannelLayout				channelLayout;
	
	[super setupDecoder:error];

	// Open the input file
	path			= [[[self stream] valueForKey:StreamURLKey] path];
	result			= FSPathMakeRef((const UInt8 *)[path fileSystemRepresentation], &ref, NULL);

	if(noErr != result) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" could not be found.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"File Not Found", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file may have been renamed or deleted, or exist on removable media.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:AudioStreamDecoderErrorDomain 
										 code:AudioStreamDecoderInputOutputError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	result = ExtAudioFileOpen(&ref, &_extAudioFile);

	if(noErr != result) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The format of the file \"%@\" was not recognized.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"File Format Not Recognized", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:AudioStreamDecoderErrorDomain 
										 code:AudioStreamDecoderInputOutputError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	// Query file type and channel layout
	dataSize		= sizeof(AudioStreamBasicDescription);
	result			= ExtAudioFileGetProperty(_extAudioFile, kExtAudioFileProperty_FileDataFormat, &dataSize, &asbd);
	NSAssert1(noErr == result, @"AudioFileGetProperty failed: %@", UTCreateStringForOSType(result));
	
	dataSize		= sizeof(AudioChannelLayout);
	result			= ExtAudioFileGetProperty(_extAudioFile, kExtAudioFileProperty_FileChannelLayout, &dataSize, &channelLayout);
	NSAssert1(noErr == result, @"AudioFileGetProperty failed: %@", UTCreateStringForOSType(result));
		
	dataSize		= sizeof(totalFrames);
	result			= ExtAudioFileGetProperty(_extAudioFile, kExtAudioFileProperty_FileLengthFrames, &dataSize, &totalFrames);
	NSAssert1(noErr == result, @"ExtAudioFileGetProperty(kExtAudioFileProperty_FileLengthFrames) failed: %@", UTCreateStringForOSType(result));
	
	[self setTotalFrames:totalFrames];
	
	// Tell the ExtAudioFile the format in which we'd like our data
	_pcmFormat						= asbd;
	_channelLayout					= channelLayout;

	_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
	_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	
	// Preserve mSampleRate and mChannelsPerFrame
	_pcmFormat.mBitsPerChannel		= (0 == _pcmFormat.mBitsPerChannel ? 16 : _pcmFormat.mBitsPerChannel);
	
	_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
	_pcmFormat.mFramesPerPacket		= 1;
	_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
	
	result = ExtAudioFileSetProperty(_extAudioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(_pcmFormat), &_pcmFormat);
	NSAssert1(noErr == result, @"ExtAudioFileSetProperty failed: %@", UTCreateStringForOSType(result));
	
	return YES;
}

- (BOOL) cleanupDecoder:(NSError **)error
{
	if(NULL != _extAudioFile) {
		// Close the output file
		OSStatus result = ExtAudioFileDispose(_extAudioFile);
		NSAssert1(noErr == result, @"ExtAudioFileDispose failed: %@", UTCreateStringForOSType(result));
		_extAudioFile = NULL;
	}
	
	[super cleanupDecoder:error];

	return YES;
}

- (void) fillPCMBuffer
{
	UInt32				bytesToWrite, bytesAvailableToWrite;
	void				*writePointer;
	OSStatus			result;
	AudioBufferList		bufferList;
	UInt32				frameCount;
	
	for(;;) {
		bytesToWrite				= RING_BUFFER_WRITE_CHUNK_SIZE;
		bytesAvailableToWrite		= [[self pcmBuffer] lengthAvailableToWriteReturningPointer:&writePointer];
		
		if(bytesAvailableToWrite < bytesToWrite) {
			break;
		}

		bufferList.mNumberBuffers				= 1;
		bufferList.mBuffers[0].mNumberChannels	= [self pcmFormat].mChannelsPerFrame;
		bufferList.mBuffers[0].mData			= writePointer;
		bufferList.mBuffers[0].mDataByteSize	= bytesAvailableToWrite;
		frameCount								= bufferList.mBuffers[0].mDataByteSize / [self pcmFormat].mBytesPerFrame;
		
		result									= ExtAudioFileRead(_extAudioFile, &frameCount, &bufferList);
		
		if(noErr != result) {
			NSLog(@"ExtAudioFileRead failed: %i", result);
			return;
		}
		
		if(0 < bufferList.mBuffers[0].mDataByteSize) {
			[[self pcmBuffer] didWriteLength:bufferList.mBuffers[0].mDataByteSize];				
		}
		
		if(0 == bufferList.mBuffers[0].mDataByteSize || 0 == frameCount) {
			[self setAtEndOfStream:YES];
			break;
		}
	}
}

@end
