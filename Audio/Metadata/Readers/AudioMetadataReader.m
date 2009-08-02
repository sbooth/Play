/*
 *  $Id$
 *
 *  Copyright (C) 2006 - 2009 Stephen F. Booth <me@sbooth.org>
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

#import "AudioMetadataReader.h"
#import "FLACMetadataReader.h"
#import "OggFLACMetadataReader.h"
#import "OggVorbisMetadataReader.h"
#import "MusepackMetadataReader.h"
#import "MP3MetadataReader.h"
#import "MP4MetadataReader.h"
#import "WavPackMetadataReader.h"
#import "MonkeysAudioMetadataReader.h"
#import "AIFFMetadataReader.h"
#import "WAVEMetadataReader.h"

#import "AudioStream.h"
#import "UtilityFunctions.h"

NSString *const AudioMetadataReaderErrorDomain = @"org.sbooth.Play.ErrorDomain.AudioMetadataReader";

@implementation AudioMetadataReader

+ (AudioMetadataReader *) metadataReaderForURL:(NSURL *)url error:(NSError **)error
{
	NSParameterAssert(nil != url);
	NSParameterAssert([url isFileURL]);
	
	AudioMetadataReader		*result				= nil;
	NSString				*path				= [url path];;
	NSString				*pathExtension		= [[path pathExtension] lowercaseString];;
	
	if([pathExtension isEqualToString:@"flac"]) {
		result = [[FLACMetadataReader alloc] init];
		[result setValue:url forKey:StreamURLKey];
	}
	// Determine the content type of the ogg stream
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
				
				*error = [NSError errorWithDomain:AudioMetadataReaderErrorDomain 
											 code:AudioMetadataReaderFileFormatNotRecognizedError 
										 userInfo:errorDictionary];
			}
			
			return nil;
		}
		
		switch(type) {
			case kOggStreamTypeVorbis:		result = [[OggVorbisMetadataReader alloc] init];			break;
			case kOggStreamTypeFLAC:		result = [[OggFLACMetadataReader alloc] init];				break;
//			case kOggStreamTypeSpeex:		result = [[AudioMetadataReader alloc] init];				break;
			default:						result = [[AudioMetadataReader alloc] init];				break;
		}

		[result setValue:url forKey:StreamURLKey];
	}
	else if([pathExtension isEqualToString:@"mpc"]) {
		result = [[MusepackMetadataReader alloc] init];
		[result setValue:url forKey:StreamURLKey];
	}
	else if([pathExtension isEqualToString:@"mp3"]) {
		result = [[MP3MetadataReader alloc] init];
		[result setValue:url forKey:StreamURLKey];
	}
	else if([pathExtension isEqualToString:@"mp4"] || [pathExtension isEqualToString:@"m4a"]) {
		result = [[MP4MetadataReader alloc] init];
		[result setValue:url forKey:StreamURLKey];
	}
	else if([pathExtension isEqualToString:@"wv"]) {
		result = [[WavPackMetadataReader alloc] init];
		[result setValue:url forKey:StreamURLKey];
	}
	else if([pathExtension isEqualToString:@"ape"]) {
		result = [[MonkeysAudioMetadataReader alloc] init];
		[result setValue:url forKey:StreamURLKey];
	}
	else if([pathExtension isEqualToString:@"aiff"] || [pathExtension isEqualToString:@"aif"]) {
		result = [[AIFFMetadataReader alloc] init];
		[result setValue:url forKey:StreamURLKey];
	}
	else if([pathExtension isEqualToString:@"wave"] || [pathExtension isEqualToString:@"wav"]) {
		result = [[WAVEMetadataReader alloc] init];
		[result setValue:url forKey:StreamURLKey];
	}
	else {
		result = [[AudioMetadataReader alloc] init];
		[result setValue:url forKey:StreamURLKey];
	}
	
	return [result autorelease];
}

- (void) dealloc
{
	[_url release], _url = nil;
	[_metadata release], _metadata = nil;
	
	[super dealloc];
}

- (BOOL)			readMetadata:(NSError **)error			{ return YES; }

- (NSDictionary *)	metadata								{ return [[_metadata retain] autorelease]; }

@end
