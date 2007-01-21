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
#include <ogg/os_types.h>
#include <ogg/ogg.h>
#include <vorbis/vorbisfile.h>

@implementation OggVorbisPropertiesReader

- (BOOL) readProperties:(NSError **)error
{
	NSMutableDictionary				*propertiesDictionary;
	NSString						*path;
	OggVorbis_File					vf;
	vorbis_info						*ovInfo;
	FILE							*file;
	int								result;
	ogg_int64_t						totalFrames;
	long							bitrate;
	
	path							= [[self valueForKey:@"url"] path];
	file							= fopen([path fileSystemRepresentation], "r");
	
	if(NULL == file) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"Unable to open the file \"%@\".", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Unable to open" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file may have been moved or you may not have read permission." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
														  code:AudioPropertiesReaderInputOutputError 
													  userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	result							= ov_test(file, &vf, NULL, 0);
	
	if(0 != result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid Ogg (Vorbis) file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not an Ogg (Vorbis) file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
														  code:AudioPropertiesReaderFileFormatNotRecognizedError 
													  userInfo:errorDictionary];
		}
		
		result			= fclose(file);
		NSAssert1(EOF != result, @"Unable to close the input file (%s).", strerror(errno));	
		
		return NO;
	}
	
	result							= ov_test_open(&vf);
	NSAssert(0 == result, NSLocalizedStringFromTable(@"Unable to open the input file.", @"Exceptions", @""));
	
	// Get input file information
	ovInfo							= ov_info(&vf, -1);
	
	NSAssert(NULL != ovInfo, @"Unable to get information on Ogg Vorbis stream.");
	
	totalFrames						= ov_pcm_total(&vf, -1);
	bitrate							= ov_bitrate(&vf, -1);
	
	propertiesDictionary			= [NSMutableDictionary dictionary];
	
	[propertiesDictionary setValue:@"Vorbis" forKey:@"formatName"];
	[propertiesDictionary setValue:[NSNumber numberWithLongLong:totalFrames] forKey:@"totalFrames"];
	[propertiesDictionary setValue:[NSNumber numberWithLong:bitrate] forKey:@"bitrate"];
	//	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:16] forKey:@"bitsPerChannel"];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:ovInfo->channels] forKey:@"channelsPerFrame"];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:ovInfo->rate] forKey:@"sampleRate"];
	[propertiesDictionary setValue:[NSNumber numberWithDouble:(double)totalFrames / ovInfo->rate] forKey:@"duration"];
		
	
	[self setValue:propertiesDictionary forKey:@"properties"];
	
	result							= ov_clear(&vf);
	NSAssert(0 == result, NSLocalizedStringFromTable(@"Unable to close the input file.", @"Exceptions", @""));
	
	return YES;
}

@end
