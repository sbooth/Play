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

#import "AudioPropertiesReader.h"
#import "FLACPropertiesReader.h"
#import "OggVorbisPropertiesReader.h"
#import "MusepackPropertiesReader.h"

NSString *const AudioPropertiesReaderErrorDomain = @"org.sbooth.Play.ErrorDomain.AudioPropertiesReader";

@implementation AudioPropertiesReader

+ (AudioPropertiesReader *) propertiesReaderForURL:(NSURL *)url error:(NSError **)error
{
	NSParameterAssert(nil != url);
	NSParameterAssert([url isFileURL]);
	
	AudioPropertiesReader			*result;
	NSString						*path;
	NSString						*pathExtension;
	
	path							= [url path];
	pathExtension					= [[path pathExtension] lowercaseString];
	
	if([pathExtension isEqualToString:@"flac"]) {
		result						= [[FLACPropertiesReader alloc] init];
		
		[result setValue:url forKey:@"url"];
	}
	else if([pathExtension isEqualToString:@"ogg"]) {
		result						= [[OggVorbisPropertiesReader alloc] init];
		
		[result setValue:url forKey:@"url"];
	}
	else if([pathExtension isEqualToString:@"mpc"]) {
		result						= [[MusepackPropertiesReader alloc] init];
		
		[result setValue:url forKey:@"url"];
	}
	else {
		result						= [[AudioPropertiesReader alloc] init];
		
		[result setValue:url forKey:@"url"];
	}
	
	return [result autorelease];
}

- (BOOL)			readProperties:(NSError **)error		{ return YES; }

@end
