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

#import "AudioPropertiesReader.h"
#import "FLACPropertiesReader.h"
#import "OggFLACPropertiesReader.h"
#import "OggVorbisPropertiesReader.h"
#import "MusepackPropertiesReader.h"
#import "CoreAudioPropertiesReader.h"
#import "WavPackPropertiesReader.h"
#import "MonkeysAudioPropertiesReader.h"
#import "MPEGPropertiesReader.h"

#import "AudioStream.h"
#import "UtilityFunctions.h"

NSString *const AudioPropertiesCueSheetKey			= @"org.sbooth.Play.AudioPropertiesReader.CueSheet";
NSString *const AudioPropertiesCueSheetTracksKey	= @"org.sbooth.Play.AudioPropertiesReader.CueSheet.Tracks";
NSString *const AudioPropertiesReaderErrorDomain	= @"org.sbooth.Play.ErrorDomain.AudioPropertiesReader";

@implementation AudioPropertiesReader

+ (AudioPropertiesReader *) propertiesReaderForURL:(NSURL *)url error:(NSError **)error
{
	NSParameterAssert(nil != url);
	NSParameterAssert([url isFileURL]);
	
	AudioPropertiesReader		*result				= nil;
	NSString					*path				= [url path];
	NSString					*pathExtension		= [[path pathExtension] lowercaseString];
	
	if([pathExtension isEqualToString:@"flac"]) {
		result = [[FLACPropertiesReader alloc] init];
		[result setValue:url forKey:StreamURLKey];
	}
	else if([pathExtension isEqualToString:@"ogg"] || [pathExtension isEqualToString:@"oga"]) {
		OggStreamType type = oggStreamType(url);
		
		if(kOggStreamTypeInvalid == type || kOggStreamTypeUnknown == type || kOggStreamTypeSpeex == type) {
			
			if(nil != error) {
				NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
				
				switch(type) {
					case kOggStreamTypeInvalid:
						[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Ogg file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
						[errorDictionary setObject:NSLocalizedStringFromTable(@"Not an Ogg file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
						[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
						break;
						
					case kOggStreamTypeUnknown:
						[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The type of Ogg data in the file \"%@\" could not be determined.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
						[errorDictionary setObject:NSLocalizedStringFromTable(@"Unknown Ogg file type", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
						[errorDictionary setObject:NSLocalizedStringFromTable(@"This data format is not supported for the Ogg container.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
						break;
						
					default:
						[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Ogg file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
						[errorDictionary setObject:NSLocalizedStringFromTable(@"Not an Ogg file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
						[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
						break;
				}
				
				*error = [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
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
		
		[result setValue:url forKey:StreamURLKey];
	}
	else if([pathExtension isEqualToString:@"mpc"]) {
		result = [[MusepackPropertiesReader alloc] init];
		[result setValue:url forKey:StreamURLKey];
	}
	else if([pathExtension isEqualToString:@"wv"]) {
		result = [[WavPackPropertiesReader alloc] init];
		[result setValue:url forKey:StreamURLKey];
	}
	else if([pathExtension isEqualToString:@"ape"]) {
		result = [[MonkeysAudioPropertiesReader alloc] init];
		[result setValue:url forKey:StreamURLKey];
	}
	else if([pathExtension isEqualToString:@"mp3"]) {
		result = [[MPEGPropertiesReader alloc] init];
		[result setValue:url forKey:StreamURLKey];
	}
	else if([getCoreAudioExtensions() containsObject:pathExtension]) {
		result = [[CoreAudioPropertiesReader alloc] init];
		[result setValue:url forKey:StreamURLKey];
	}
	else {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The format of the file \"%@\" was not recognized.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"File Format Not Recognized", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:AudioPropertiesReaderErrorDomain 
										 code:AudioPropertiesReaderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		return nil;
	}
	
	return [result autorelease];
}

- (void) dealloc
{
	[_url release], _url = nil;
	[_properties release], _properties = nil;

	[super dealloc];
}

- (BOOL)			readProperties:(NSError **)error		{ return YES; }

- (NSDictionary *)	properties								{ return [[_properties retain] autorelease]; }
- (NSDictionary *)	cueSheet								{ return [_properties valueForKey:AudioPropertiesCueSheetKey]; }

@end
