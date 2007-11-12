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

#import "WavPackPropertiesReader.h"
#import "AudioStream.h"
#include <wavpack/wavpack.h>

@implementation WavPackPropertiesReader

- (BOOL) readProperties:(NSError **)error
{
	NSString *path = [[self valueForKey:StreamURLKey] path];

	char errorMsg [80];
	WavpackContext *wpc = WavpackOpenFileInput([path fileSystemRepresentation], errorMsg, 0, 0);
	if(NULL == wpc) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid WavPack file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a WavPack file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
										 code:AudioPropertiesReaderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	NSMutableDictionary *propertiesDictionary = [NSMutableDictionary dictionary];

	[propertiesDictionary setValue:NSLocalizedStringFromTable(@"WavPack", @"Formats", @"") forKey:PropertiesFileTypeKey];
	[propertiesDictionary setValue:NSLocalizedStringFromTable(@"WavPack", @"Formats", @"") forKey:PropertiesDataFormatKey];
	[propertiesDictionary setValue:NSLocalizedStringFromTable(@"WavPack", @"Formats", @"") forKey:PropertiesFormatDescriptionKey];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:WavpackGetNumSamples(wpc)] forKey:PropertiesTotalFramesKey];
	[propertiesDictionary setValue:[NSNumber numberWithInt:WavpackGetBitsPerSample(wpc)] forKey:PropertiesBitsPerChannelKey];
	[propertiesDictionary setValue:[NSNumber numberWithInt:WavpackGetNumChannels(wpc)] forKey:PropertiesChannelsPerFrameKey];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:WavpackGetSampleRate(wpc)] forKey:PropertiesSampleRateKey];
	[propertiesDictionary setValue:[NSNumber numberWithDouble:WavpackGetAverageBitrate(wpc, YES)] forKey:PropertiesBitrateKey];	
	
	[self setValue:propertiesDictionary forKey:@"properties"];
	
	WavpackCloseFile(wpc);
	
	return YES;
}

@end
