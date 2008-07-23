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
	UInt32							specifierSize;
	FSRef							ref;
	SInt64							totalFrames;
//	UInt32							isVBR;
	NSMutableDictionary				*propertiesDictionary	= [NSMutableDictionary dictionary];

	// Open the input file
	NSString	*path	= [[self valueForKey:StreamURLKey] path];
	OSStatus	result	= FSPathMakeRef((const UInt8 *)[[[self valueForKey:StreamURLKey] path] fileSystemRepresentation], &ref, NULL);
	
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
	
	// Open the audio file
	AudioFileID audioFileID = NULL;
	
	result = AudioFileOpen(&ref, fsRdPerm, 0, &audioFileID); 
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

	// Determine the file type
	AudioFileTypeID		audioFileTypeID		= 0;
	NSString			*fileType			= nil;

	specifierSize	= sizeof(AudioFileTypeID);
	result			= AudioFileGetProperty(audioFileID, kAudioFilePropertyFileFormat, &specifierSize, &audioFileTypeID);
	NSAssert1(noErr == result, @"AudioFileGetProperty failed: %@", UTCreateStringForOSType(result));

	specifierSize	= sizeof(fileType);
	result			= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_FileTypeName, sizeof(audioFileTypeID), &audioFileTypeID, &specifierSize, &fileType);
	NSAssert1(noErr == result, @"AudioFileGetGlobalInfo failed: %@", UTCreateStringForOSType(result));
	
	[propertiesDictionary setValue:fileType forKey:PropertiesFileTypeKey];

	// And data format
	NSString						*dataFormat			= nil;
	AudioStreamBasicDescription		asbd;

	specifierSize	= sizeof(AudioStreamBasicDescription);
	result			= AudioFileGetProperty(audioFileID, kAudioFilePropertyDataFormat, &specifierSize, &asbd);
	NSAssert1(noErr == result, @"AudioFileGetProperty failed: %@", UTCreateStringForOSType(result));
	
	if(0 != asbd.mBitsPerChannel)
		[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:asbd.mBitsPerChannel] forKey:PropertiesBitsPerChannelKey];
	else if(kAudioFormatAppleLossless == asbd.mFormatID && kAppleLosslessFormatFlag_16BitSourceData == asbd.mFormatFlags)
		[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:16] forKey:PropertiesBitsPerChannelKey];
	else if(kAudioFormatAppleLossless == asbd.mFormatID && kAppleLosslessFormatFlag_20BitSourceData == asbd.mFormatFlags)
		[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:20] forKey:PropertiesBitsPerChannelKey];
	else if(kAudioFormatAppleLossless == asbd.mFormatID && kAppleLosslessFormatFlag_24BitSourceData == asbd.mFormatFlags)
		[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:24] forKey:PropertiesBitsPerChannelKey];
	else if(kAudioFormatAppleLossless == asbd.mFormatID && kAppleLosslessFormatFlag_32BitSourceData == asbd.mFormatFlags)
		[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:32] forKey:PropertiesBitsPerChannelKey];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:asbd.mChannelsPerFrame] forKey:PropertiesChannelsPerFrameKey];
	[propertiesDictionary setValue:[NSNumber numberWithDouble:asbd.mSampleRate] forKey:PropertiesSampleRateKey];
	
	// Zero out part of the asbd so we only get the format's name
	asbd.mSampleRate		= 0;
	asbd.mBytesPerPacket	= 0;
	asbd.mFramesPerPacket	= 0;
	asbd.mBytesPerFrame		= 0;
	asbd.mChannelsPerFrame	= 0;
	asbd.mBitsPerChannel	= 0;
	asbd.mReserved			= 0;
	
	specifierSize	= sizeof(dataFormat);
	result			= AudioFormatGetProperty(kAudioFormatProperty_FormatName, sizeof(AudioStreamBasicDescription), &asbd, &specifierSize, &dataFormat);
	NSAssert1(noErr == result, @"AudioFormatGetProperty failed: %@", UTCreateStringForOSType(result));

	[propertiesDictionary setValue:dataFormat forKey:PropertiesDataFormatKey];

	// For container formats the description should be the dataFormat
	if(kAudioFileMPEG4Type == audioFileTypeID || kAudioFileM4AType == audioFileTypeID || kAudioFileCAFType == audioFileTypeID)
		[propertiesDictionary setValue:dataFormat forKey:PropertiesFormatDescriptionKey];
	else
		[propertiesDictionary setValue:fileType forKey:PropertiesFormatDescriptionKey];

	// Open as an ExtAudioFile to count frames	
	result = ExtAudioFileWrapAudioFileID(audioFileID, NO, &extAudioFile);
	NSAssert1(noErr == result, @"ExtAudioFileWrapAudioFileID failed: %@", UTCreateStringForOSType(result));
	
	specifierSize	= sizeof(totalFrames);
	result			= ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_FileLengthFrames, &specifierSize, &totalFrames);
	NSAssert1(noErr == result, @"ExtAudioFileGetProperty(kExtAudioFileProperty_FileLengthFrames) failed: %@", UTCreateStringForOSType(result));

	[propertiesDictionary setValue:[NSNumber numberWithLongLong:totalFrames] forKey:PropertiesTotalFramesKey];
		
	[self setValue:propertiesDictionary forKey:@"properties"];
	
	// Close the files
	result = ExtAudioFileDispose(extAudioFile);
	NSAssert1(noErr == result, @"ExtAudioFileDispose failed: %@", UTCreateStringForOSType(result));

	result = AudioFileClose(audioFileID);
	NSAssert1(noErr == result, @"AudioFileDispose failed: %@", UTCreateStringForOSType(result));
	
	return YES;
}

@end
