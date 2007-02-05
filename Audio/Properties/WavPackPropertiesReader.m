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
#include <wavpack/wavpack.h>

@implementation WavPackPropertiesReader

- (BOOL) readProperties:(NSError **)error
{
	NSMutableDictionary				*propertiesDictionary;
	NSString						*path;
    WavpackContext					*wpc;
	char							errorMsg [80];

	path							= [[self valueForKey:@"url"] path];

	wpc = WavpackOpenFileInput([path fileSystemRepresentation], errorMsg, 0, 0);
	if(NULL == wpc) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid WavPack file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not a WavPack file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
														  code:AudioPropertiesReaderFileFormatNotRecognizedError 
													  userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	propertiesDictionary			= [NSMutableDictionary dictionary];

	[propertiesDictionary setValue:NSLocalizedStringFromTable(@"WavPack", @"Formats", @"") forKey:@"fileType"];
	[propertiesDictionary setValue:NSLocalizedStringFromTable(@"WavPack", @"Formats", @"") forKey:@"formatType"];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:WavpackGetNumSamples(wpc)] forKey:@"totalFrames"];
	[propertiesDictionary setValue:[NSNumber numberWithInt:WavpackGetBitsPerSample(wpc)] forKey:@"bitsPerChannel"];
	[propertiesDictionary setValue:[NSNumber numberWithInt:WavpackGetNumChannels(wpc)] forKey:@"channelsPerFrame"];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:WavpackGetSampleRate(wpc)] forKey:@"sampleRate"];
	[propertiesDictionary setValue:[NSNumber numberWithDouble:(double)WavpackGetNumSamples(wpc) / WavpackGetSampleRate(wpc)] forKey:@"duration"];
	
	
	[self setValue:propertiesDictionary forKey:@"properties"];
	
	WavpackCloseFile(wpc);
	
	return YES;
}

@end
