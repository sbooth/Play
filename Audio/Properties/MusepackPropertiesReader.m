/*
 *  $Id$
 *
 *  Copyright (C) 2006 Stephen F. Booth <me@sbooth.org>
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

#import "MusepackPropertiesReader.h"
#include <mpcdec/mpcdec.h>

@implementation MusepackPropertiesReader

- (BOOL) readProperties:(NSError **)error
{
	NSMutableDictionary				*propertiesDictionary;
	NSString						*path;
	FILE							*file;
	mpc_reader_file					reader_file;
	mpc_decoder						decoder;
	mpc_streaminfo					streaminfo;
	int								result;
	mpc_int32_t						intResult;
	mpc_bool_t						boolResult;
	
	path			= [[self valueForKey:@"url"] path];
	file			= fopen([path fileSystemRepresentation], "r");
	
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
	
	mpc_reader_setup_file_reader(&reader_file, file);
	
	// Get input file information
	mpc_streaminfo_init(&streaminfo);
	intResult		= mpc_streaminfo_read(&streaminfo, &reader_file.reader);
	
	if(ERROR_CODE_OK != intResult) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid Musepack file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not a Musepack file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
														  code:AudioPropertiesReaderFileFormatNotRecognizedError 
													  userInfo:errorDictionary];
		}
		
		result			= fclose(file);
		NSAssert1(EOF != result, @"Unable to close the input file (%s).", strerror(errno));	
		
		return NO;
	}
	
	// Set up the decoder
	mpc_decoder_setup(&decoder, &reader_file.reader);
	boolResult		= mpc_decoder_initialize(&decoder, &streaminfo);
	NSAssert(YES == boolResult, NSLocalizedStringFromTable(@"Unable to intialize the Musepack decoder.", @"Exceptions", @""));
	
	propertiesDictionary			= [NSMutableDictionary dictionary];
	
	[propertiesDictionary setValue:@"Musepack" forKey:@"formatName"];
	[propertiesDictionary setValue:[NSNumber numberWithLongLong:mpc_streaminfo_get_length_samples(&streaminfo)] forKey:@"totalFrames"];
	//	[propertiesDictionary setValue:[NSNumber numberWithLong:bitrate] forKey:@"averageBitrate"];
	//	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:16] forKey:@"bitsPerChannel"];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:streaminfo.channels] forKey:@"channelsPerFrame"];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:streaminfo.sample_freq] forKey:@"sampleRate"];				
	
	[self setValue:propertiesDictionary forKey:@"properties"];
	
	result							= fclose(file);	
	NSAssert1(EOF != result, @"Unable to close the input file (%s).", strerror(errno));	
	
	return YES;
}

@end