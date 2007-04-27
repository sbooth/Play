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

#import "CoreAudioPropertiesReader.h"
#import "AudioStream.h"
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/ExtendedAudioFile.h>

@implementation CoreAudioPropertiesReader

- (BOOL) readProperties:(NSError **)error
{
	ExtAudioFileRef					extAudioFile;
	NSString						*path;
	OSStatus						result;
	UInt32							specifierSize;
	FSRef							ref;
	SInt64							totalFrames;
	AudioStreamBasicDescription		asbd, asbdCopy;
	NSString						*fileFormat;
//	UInt32							isVBR;
	NSMutableDictionary				*propertiesDictionary;
	
	// Open the input file
	path		= [[self valueForKey:StreamURLKey] path];
	result		= FSPathMakeRef((const UInt8 *)[[[self valueForKey:StreamURLKey] path] fileSystemRepresentation], &ref, NULL);
	
	if(noErr != result) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" could not be found.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"File Not Found", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file may have been renamed or deleted, or exist on removable media.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
										 code:AudioPropertiesReaderInputOutputError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	result = ExtAudioFileOpen(&ref, &extAudioFile);
	
	if(noErr != result) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The format of the file \"%@\" was not recognized.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"File Format Not Recognized", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
										 code:AudioPropertiesReaderInputOutputError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	// Query file type
	specifierSize		= sizeof(AudioStreamBasicDescription);
	result				= ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_FileDataFormat, &specifierSize, &asbd);
	NSAssert1(noErr == result, @"AudioFileGetProperty failed: %@", UTCreateStringForOSType(result));
	
	// This doesn't work how I would expect it to
//	specifierSize					= sizeof(isVBR);
//	result							= AudioFormatGetProperty(kAudioFormatProperty_FormatIsVBR, sizeof(asbd), &asbd, &specifierSize, &isVBR);
//	NSAssert1(noErr == result, @"AudioFormatGetProperty(kAudioFormatProperty_FormatIsVBR) failed: %@", UTCreateStringForOSType(result));
	
	// Zero out part of the asbd so we only get the format's name
	memset(&asbdCopy, 0, sizeof(AudioStreamBasicDescription));
	asbdCopy.mFormatID			= asbd.mFormatID;
	asbdCopy.mFormatFlags		= asbd.mFormatFlags;
	
	specifierSize		= sizeof(fileFormat);
	result				= AudioFormatGetProperty(kAudioFormatProperty_FormatName, sizeof(AudioStreamBasicDescription), &asbdCopy, &specifierSize, &fileFormat);
	NSAssert1(noErr == result, @"AudioFormatGetProperty failed: %@", UTCreateStringForOSType(result));
	
	specifierSize		= sizeof(totalFrames);
	result				= ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_FileLengthFrames, &specifierSize, &totalFrames);
	NSAssert1(noErr == result, @"ExtAudioFileGetProperty(kExtAudioFileProperty_FileLengthFrames) failed: %@", UTCreateStringForOSType(result));
		
	propertiesDictionary = [NSMutableDictionary dictionary];
	
	[propertiesDictionary setValue:[fileFormat autorelease] forKey:PropertiesFormatTypeKey];
	[propertiesDictionary setValue:[NSNumber numberWithLongLong:totalFrames] forKey:PropertiesTotalFramesKey];
	if(0 != asbd.mBitsPerChannel) {
		[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:asbd.mBitsPerChannel] forKey:PropertiesBitsPerChannelKey];
	}
	else if(kAudioFormatAppleLossless == asbd.mFormatID && kAppleLosslessFormatFlag_16BitSourceData & asbd.mFormatFlags) {
		[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:16] forKey:PropertiesBitsPerChannelKey];
		
	}
	else if(kAudioFormatAppleLossless == asbd.mFormatID && kAppleLosslessFormatFlag_20BitSourceData & asbd.mFormatFlags) {
		[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:20] forKey:PropertiesBitsPerChannelKey];
		
	}
	else if(kAudioFormatAppleLossless == asbd.mFormatID && kAppleLosslessFormatFlag_24BitSourceData & asbd.mFormatFlags) {
		[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:24] forKey:PropertiesBitsPerChannelKey];
		
	}
	else if(kAudioFormatAppleLossless == asbd.mFormatID && kAppleLosslessFormatFlag_32BitSourceData & asbd.mFormatFlags) {
		[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:32] forKey:PropertiesBitsPerChannelKey];
		
	}
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:asbd.mChannelsPerFrame] forKey:PropertiesChannelsPerFrameKey];
	[propertiesDictionary setValue:[NSNumber numberWithDouble:asbd.mSampleRate] forKey:PropertiesSampleRateKey];
	[propertiesDictionary setValue:[NSNumber numberWithDouble:(double)totalFrames / asbd.mSampleRate] forKey:PropertiesDurationKey];
//	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:isVBR] forKey:@"isVBR"];
	
	[self setValue:propertiesDictionary forKey:@"properties"];
	
	// Close the output file
	result = ExtAudioFileDispose(extAudioFile);
	NSAssert1(noErr == result, @"ExtAudioFileDispose failed: %@", UTCreateStringForOSType(result));
	
	return YES;
}

@end
