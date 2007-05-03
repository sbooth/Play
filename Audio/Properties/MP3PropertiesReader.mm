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

#import "MP3PropertiesReader.h"
#import "AudioStream.h"
#include <taglib/mpegfile.h>

@implementation MP3PropertiesReader

- (BOOL) readProperties:(NSError **)error
{
	NSString				*path		= [_url path];
	TagLib::MPEG::File		f			([path fileSystemRepresentation]);
	
	if(NO == f.isValid()) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid MPEG file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not an MPEG file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
										 code:AudioPropertiesReaderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	NSMutableDictionary			*propertiesDictionary		= [NSMutableDictionary dictionary];
	TagLib::MPEG::Properties	*audioProperties			= f.audioProperties();
	
	if(NULL != audioProperties) {
		[propertiesDictionary setValue:NSLocalizedStringFromTable(@"MPEG-1", @"Formats", @"") forKey:PropertiesFileTypeKey];		
		switch(audioProperties->layer()) {
			case 1:
				[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Audio Layer I", @"Formats", @"") forKey:PropertiesFormatTypeKey];		
				break;
			case 2:
				[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Audio Layer II", @"Formats", @"") forKey:PropertiesFormatTypeKey];		
				break;
			case 3:
				[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Audio Layer III", @"Formats", @"") forKey:PropertiesFormatTypeKey];		
				break;
		}
		
		[propertiesDictionary setValue:[NSNumber numberWithInt:audioProperties->channels()] forKey:PropertiesChannelsPerFrameKey];
		[propertiesDictionary setValue:[NSNumber numberWithInt:audioProperties->sampleRate()] forKey:PropertiesSampleRateKey];

		[propertiesDictionary setValue:[NSNumber numberWithInt:(audioProperties->bitrate() * 1000)] forKey:PropertiesBitrateKey];
		[propertiesDictionary setValue:[NSNumber numberWithInt:audioProperties->length()] forKey:PropertiesDurationKey];
	}
	else {
		[propertiesDictionary setValue:NSLocalizedStringFromTable(@"MPEG-1", @"Formats", @"") forKey:PropertiesFileTypeKey];		
		[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Audio Layer III", @"Formats", @"") forKey:PropertiesFormatTypeKey];		
	}	
	
	[self setValue:propertiesDictionary forKey:@"properties"];
	
	return YES;
}

@end
