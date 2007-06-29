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

#import "CoreAudioDecoder.h"
#import "AudioStream.h"
#include <AudioToolbox/AudioFormat.h>

@implementation CoreAudioDecoder

- (id) initWithURL:(NSURL *)url error:(NSError **)error
{
	NSParameterAssert(nil != url);
	
	if((self = [super initWithURL:url error:error])) {
		
		// Open the input file
		FSRef ref;
		NSString *path = [[self URL] path];
		
		OSStatus result = FSPathMakeRef((const UInt8 *)[path fileSystemRepresentation], &ref, NULL);
		if(noErr != result) {
			if(nil != error) {
				NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
				
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" could not be found.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"File Not Found", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"The file may have been renamed or deleted, or exist on removable media.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
				
				*error = [NSError errorWithDomain:AudioDecoderErrorDomain 
											 code:AudioDecoderFileNotFoundError 
										 userInfo:errorDictionary];
			}
			[self release];			
			return nil;
		}
		
		result = ExtAudioFileOpen(&ref, &_extAudioFile);
		if(noErr != result) {
			if(nil != error) {
				NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
				
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The format of the file \"%@\" was not recognized.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"File Format Not Recognized", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
				[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
				
				*error = [NSError errorWithDomain:AudioDecoderErrorDomain 
											 code:AudioDecoderInputOutputError 
										 userInfo:errorDictionary];
			}
			[self release];			
			return nil;
		}
		
		// Query file format
		UInt32 dataSize = sizeof(_sourceFormat);
		result = ExtAudioFileGetProperty(_extAudioFile, kExtAudioFileProperty_FileDataFormat, &dataSize, &_sourceFormat);
		NSAssert1(noErr == result, @"AudioFileGetProperty failed: %@", UTCreateStringForOSType(result));
				
		// Tell the ExtAudioFile the format in which we'd like our data
		_format.mSampleRate			= _sourceFormat.mSampleRate;
		_format.mChannelsPerFrame	= _sourceFormat.mChannelsPerFrame;
		
		result = ExtAudioFileSetProperty(_extAudioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(_format), &_format);
		NSAssert1(noErr == result, @"ExtAudioFileSetProperty failed: %@", UTCreateStringForOSType(result));
		
		// Setup the channel layout
		dataSize = sizeof(_channelLayout);
		result = ExtAudioFileGetProperty(_extAudioFile, kExtAudioFileProperty_FileChannelLayout, &dataSize, &_channelLayout);
		NSAssert1(noErr == result, @"AudioFileGetProperty failed: %@", UTCreateStringForOSType(result));
	}
	return self;
}

- (void) dealloc
{
	if(_extAudioFile) {
		// Close the output file
		OSStatus result = ExtAudioFileDispose(_extAudioFile);
		NSAssert1(noErr == result, @"ExtAudioFileDispose failed: %@", UTCreateStringForOSType(result));
		_extAudioFile = NULL;
	}
	
	[super dealloc];
}

- (SInt64) totalFrames
{
	SInt64 totalFrames = -1;
	UInt32 dataSize = sizeof(totalFrames);
	
	OSStatus result = ExtAudioFileGetProperty(_extAudioFile, kExtAudioFileProperty_FileLengthFrames, &dataSize, &totalFrames);
	if(noErr != result)
		NSLog(@"Unable to determine total frames");
	
	return totalFrames;
}

- (SInt64) currentFrame
{
	SInt64 currentFrame = -1;
	
	OSStatus result = ExtAudioFileTell(_extAudioFile, &currentFrame);
	if(noErr != result)
		NSLog(@"Unable to determine total frames");
	
	return currentFrame;
}

- (BOOL) supportsSeeking
{
	return YES;
}

- (SInt64) seekToFrame:(SInt64)frame
{
	NSParameterAssert(0 <= frame && frame < [self totalFrames]);
	
	OSStatus result = ExtAudioFileSeek(_extAudioFile, frame);
	if(noErr != result)
		return -1;
	
	return [self currentFrame];
}

- (UInt32) readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount
{
	NSParameterAssert(NULL != bufferList);
	NSParameterAssert(bufferList->mNumberBuffers == _format.mChannelsPerFrame);
	NSParameterAssert(0 < frameCount);
	
	OSStatus result = ExtAudioFileRead(_extAudioFile, &frameCount, bufferList);
	if(noErr != result)
		NSLog(@"Error reading from ExtAudioFile: %i",result);
	
	return frameCount;
}

@end
