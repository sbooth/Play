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

#import "MP3PropertiesReader.h"
#include <taglib/mpegfile.h>
#include <taglib/xingheader.h>

@implementation MP3PropertiesReader

- (BOOL) readProperties:(NSError **)error
{
	NSMutableDictionary						*propertiesDictionary;
	NSString								*path				= [_url path];
	TagLib::MPEG::File						f					([path fileSystemRepresentation], true, TagLib::AudioProperties::Accurate);
	TagLib::MPEG::Properties				*audioProperties;
	const TagLib::MPEG::XingHeader			*xingHeader;
//	TagLib::String							s;
	
	if(NO == f.isValid()) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid MP3 file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not an MP3 file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
														  code:AudioPropertiesReaderFileFormatNotRecognizedError 
													  userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	propertiesDictionary					= [NSMutableDictionary dictionary];
	audioProperties							= f.audioProperties();
	
	if(NULL != audioProperties) {
		[propertiesDictionary setValue:[NSString stringWithFormat:@"MPEG Layer %i", audioProperties->layer()] forKey:@"formatName"];
		
		[propertiesDictionary setValue:[NSNumber numberWithInt:audioProperties->channels()] forKey:@"channelsPerFrame"];
		[propertiesDictionary setValue:[NSNumber numberWithInt:audioProperties->sampleRate()] forKey:@"sampleRate"];

		[propertiesDictionary setValue:[NSNumber numberWithInt:(audioProperties->bitrate() * 1000)] forKey:@"bitrate"];
		[propertiesDictionary setValue:[NSNumber numberWithInt:audioProperties->length()] forKey:@"duration"];

		xingHeader							= audioProperties->xingHeader();
		
		if(NULL != xingHeader) {
			[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:xingHeader->totalFrames()] forKey:@"totalFrames"];
		}
	}
	else {
		[propertiesDictionary setValue:@"MPEG Layer 3" forKey:@"formatName"];		
	}	
	
	[self setValue:propertiesDictionary forKey:@"properties"];
	
	return YES;
}

@end
