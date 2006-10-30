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
#import "OggFLACPropertiesReader.h"
#import "OggVorbisPropertiesReader.h"
#import "MusepackPropertiesReader.h"
#import "CoreAudioPropertiesReader.h"
#import "WavPackPropertiesReader.h"
#import "MonkeysAudioPropertiesReader.h"

#import "UtilityFunctions.h"

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
		OggStreamType			type		= oggStreamType(url);
		
		if(kOggStreamTypeInvalid == type || kOggStreamTypeUnknown == type || kOggStreamTypeSpeex == type) {
			
			if(nil != error) {
				NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
				
				switch(type) {
					case kOggStreamTypeInvalid:
						[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid Ogg stream.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
						[errorDictionary setObject:@"Not an Ogg stream" forKey:NSLocalizedFailureReasonErrorKey];
						[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
						break;
						
					case kOggStreamTypeUnknown:
						[errorDictionary setObject:[NSString stringWithFormat:@"The type of Ogg stream in the file \"%@\" could not be determined.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
						[errorDictionary setObject:@"Unknown Ogg stream type" forKey:NSLocalizedFailureReasonErrorKey];
						[errorDictionary setObject:@"This data format is not supported for the Ogg container." forKey:NSLocalizedRecoverySuggestionErrorKey];						
						break;
						
					default:
						[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid Ogg stream.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
						[errorDictionary setObject:@"Not an Ogg stream" forKey:NSLocalizedFailureReasonErrorKey];
						[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
						break;
				}
				
				*error					= [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
															  code:AudioPropertiesReaderFileFormatNotRecognizedError 
														  userInfo:errorDictionary];
			}
			
			return nil;
		}
		
		switch(type) {
			case kOggStreamTypeVorbis:		result = [[OggVorbisPropertiesReader alloc] init];			break;
			case kOggStreamTypeFLAC:		result = [[OggFLACPropertiesReader alloc] init];			break;
//			case kOggStreamTypeSpeex:		result = [[AudioPropertiesReader alloc] init];				break;
			default:						result = nil;												break;
		}
		
		[result setValue:url forKey:@"url"];
	}
	else if([pathExtension isEqualToString:@"mpc"]) {
		result						= [[MusepackPropertiesReader alloc] init];
		
		[result setValue:url forKey:@"url"];
	}
	else if([pathExtension isEqualToString:@"wv"]) {
		result						= [[WavPackPropertiesReader alloc] init];
		
		[result setValue:url forKey:@"url"];
	}
	else if([pathExtension isEqualToString:@"ape"]) {
		result						= [[MonkeysAudioPropertiesReader alloc] init];
		
		[result setValue:url forKey:@"url"];
	}
	else if([getCoreAudioExtensions() containsObject:pathExtension]) {
		result						= [[CoreAudioPropertiesReader alloc] init];
		
		[result setValue:url forKey:@"url"];
	}
	else {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary;
			
			errorDictionary			= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The format of the file \"%@\" was not recognized.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"File Format Not Recognized" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error					= [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
														  code:AudioPropertiesReaderFileFormatNotRecognizedError 
													  userInfo:errorDictionary];
		}
		
		result						= nil;
	}
	
	return [result autorelease];
}

- (BOOL)			readProperties:(NSError **)error		{ return YES; }

@end
