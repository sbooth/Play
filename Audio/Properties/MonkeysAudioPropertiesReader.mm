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

#import "MonkeysAudioPropertiesReader.h"
#import "AudioStream.h"
#include <mac/All.h>
#include <mac/MACLib.h>
#include <mac/APEDecompress.h>
#include <mac/CharacterHelper.h>

@implementation MonkeysAudioPropertiesReader

- (BOOL) readProperties:(NSError **)error
{	
	// Setup converter
	NSString	*path	= [[self valueForKey:StreamURLKey] path];
	str_utf16	*chars	= GetUTF16FromANSI([path fileSystemRepresentation]);
	NSAssert(NULL != chars, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	
	int result;
	IAPEDecompress *decompressor = CreateIAPEDecompress(chars, &result);	
	if(NULL == decompressor || ERROR_SUCCESS != result) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Monkey's Audio file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a Monkey's Audio file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
										 code:AudioPropertiesReaderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
				
		return NO;
	}

	NSMutableDictionary *propertiesDictionary = [NSMutableDictionary dictionary];
	
	[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Monkey's Audio", @"Formats", @"") forKey:PropertiesFileTypeKey];
	[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Monkey's Audio", @"Formats", @"") forKey:PropertiesDataFormatKey];
	[propertiesDictionary setValue:NSLocalizedStringFromTable(@"APE", @"Formats", @"") forKey:PropertiesFormatDescriptionKey];
	[propertiesDictionary setValue:[NSNumber numberWithLongLong:decompressor->GetInfo(APE_DECOMPRESS_TOTAL_BLOCKS)] forKey:PropertiesTotalFramesKey];
//	[propertiesDictionary setValue:[NSNumber numberWithLong:bitrate] forKey:@"averageBitrate"];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:decompressor->GetInfo(APE_INFO_BITS_PER_SAMPLE)] forKey:PropertiesBitsPerChannelKey];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:decompressor->GetInfo(APE_INFO_CHANNELS)] forKey:PropertiesChannelsPerFrameKey];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:decompressor->GetInfo(APE_INFO_SAMPLE_RATE)] forKey:PropertiesSampleRateKey];
		
	[self setValue:propertiesDictionary forKey:@"properties"];
		
	delete [] chars;	
	delete decompressor;
	
	return YES;
}

@end
