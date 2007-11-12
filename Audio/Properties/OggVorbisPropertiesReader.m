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

#import "OggVorbisPropertiesReader.h"
#import "AudioStream.h"
#include <ogg/os_types.h>
#include <ogg/ogg.h>
#include <vorbis/vorbisfile.h>

@implementation OggVorbisPropertiesReader

- (BOOL) readProperties:(NSError **)error
{	
	NSString	*path		= [[self valueForKey:StreamURLKey] path];
	FILE		*file		= fopen([path fileSystemRepresentation], "r");
	
	if(NULL == file) {
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
	
	OggVorbis_File vf;
	int result = ov_test(file, &vf, NULL, 0);
	
	if(0 != result) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Ogg Vorbis file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not an Ogg Vorbis file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
										 code:AudioPropertiesReaderInputOutputError 
									 userInfo:errorDictionary];
		}
		
		result = fclose(file);
		NSAssert1(EOF != result, @"Unable to close the input file (%s).", strerror(errno));	
		
		return NO;
	}
	
	result = ov_test_open(&vf);
	NSAssert(0 == result, NSLocalizedStringFromTable(@"Unable to open the input file.", @"Errors", @""));
	
	// Get input file information
	vorbis_info *ovInfo = ov_info(&vf, -1);
	NSAssert(NULL != ovInfo, @"Unable to get information on Ogg Vorbis stream.");
	
	ogg_int64_t				totalFrames				= ov_pcm_total(&vf, -1);
	long					bitrate					= ov_bitrate(&vf, -1);
	
	NSMutableDictionary		*propertiesDictionary	= [NSMutableDictionary dictionary];
	
	[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Ogg", @"Formats", @"") forKey:PropertiesFileTypeKey];
	[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Vorbis", @"Formats", @"") forKey:PropertiesDataFormatKey];
	[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Ogg Vorbis", @"Formats", @"") forKey:PropertiesFormatDescriptionKey];
	[propertiesDictionary setValue:[NSNumber numberWithLongLong:totalFrames] forKey:PropertiesTotalFramesKey];
	[propertiesDictionary setValue:[NSNumber numberWithLong:bitrate] forKey:PropertiesBitrateKey];
//	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:16] forKey:PropertiesBitsPerChannelKey];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:ovInfo->channels] forKey:PropertiesChannelsPerFrameKey];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:ovInfo->rate] forKey:PropertiesSampleRateKey];
	
	[self setValue:propertiesDictionary forKey:@"properties"];
	
	result = ov_clear(&vf);
	NSAssert(0 == result, NSLocalizedStringFromTable(@"Unable to close the input file.", @"Errors", @""));
	
	return YES;
}

@end
