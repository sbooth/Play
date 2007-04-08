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
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid MPEG file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not an MPEG file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
										 code:AudioPropertiesReaderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	NSMutableDictionary			*propertiesDictionary		= [NSMutableDictionary dictionary];
	TagLib::MPEG::Properties	*audioProperties			= f.audioProperties();
	
	if(NULL != audioProperties) {
		[propertiesDictionary setValue:NSLocalizedStringFromTable(@"MPEG Audio", @"Formats", @"") forKey:@"fileType"];		
		switch(audioProperties->layer()) {
			case 1:
				[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Layer I", @"Formats", @"") forKey:@"formatType"];		
				break;
			case 2:
				[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Layer II", @"Formats", @"") forKey:@"formatType"];		
				break;
			case 3:
				[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Layer III", @"Formats", @"") forKey:@"formatType"];		
				break;
		}
		
		[propertiesDictionary setValue:[NSNumber numberWithInt:audioProperties->channels()] forKey:@"channelsPerFrame"];
		[propertiesDictionary setValue:[NSNumber numberWithInt:audioProperties->sampleRate()] forKey:@"sampleRate"];

		[propertiesDictionary setValue:[NSNumber numberWithInt:(audioProperties->bitrate() * 1000)] forKey:@"bitrate"];
		[propertiesDictionary setValue:[NSNumber numberWithInt:audioProperties->length()] forKey:@"duration"];
	}
	else {
		[propertiesDictionary setValue:NSLocalizedStringFromTable(@"MPEG Audio", @"Formats", @"") forKey:@"fileType"];		
		[propertiesDictionary setValue:NSLocalizedStringFromTable(@"Layer III", @"Formats", @"") forKey:@"formatType"];		
	}	
	
	[self setValue:propertiesDictionary forKey:@"properties"];
	
	return YES;
}

@end
