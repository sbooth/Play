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

#import "AudioDecoder.h"
#import "FLACDecoder.h"
#import "OggFLACDecoder.h"
#import "OggVorbisDecoder.h"
#import "MusepackDecoder.h"
#import "CoreAudioDecoder.h"
#import "WavPackDecoder.h"
#import "MonkeysAudioDecoder.h"
#import "MPEGDecoder.h"

#import "AudioStream.h"
#import "UtilityFunctions.h"

#include <AudioToolbox/AudioFormat.h>

NSString *const AudioDecoderErrorDomain = @"org.sbooth.Play.ErrorDomain.AudioDecoder";

@implementation AudioDecoder

+ (void) initialize
{
	[self exposeBinding:@"currentFrame"];
	[self exposeBinding:@"totalFrames"];
	[self exposeBinding:@"framesRemaining"];
	
	[self setKeys:[NSArray arrayWithObjects:@"currentFrame", @"totalFrames", nil] triggerChangeNotificationsForDependentKey:@"framesRemaining"];
}

+ (AudioDecoder *) decoderWithURL:(NSURL *)url error:(NSError **)error
{
	NSParameterAssert(nil != url);
	NSParameterAssert([url isFileURL]);
	
	AudioDecoder		*result				= nil;
	NSString			*path				= [url path];
	NSString			*pathExtension		= [[path pathExtension] lowercaseString];

/*	FSRef				ref;
	NSString			*uti				= nil;	
	
	FSPathMakeRef((const UInt8 *)[path fileSystemRepresentation], &ref, NULL);
	
	OSStatus lsResult = LSCopyItemAttribute(&ref, kLSRolesAll, kLSItemContentType, (CFTypeRef *)&uti);

	NSLog(@"UTI for %@:%@", url, uti);
	[uti release];*/
	
	// Ensure the file exists
	if(NO == [[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" could not be found.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"File Not Found", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file may have been renamed or deleted, or exist on removable media.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:AudioDecoderErrorDomain 
										 code:AudioDecoderFileNotFoundError 
									 userInfo:errorDictionary];
		}
		return nil;	
	}
	
	if([pathExtension isEqualToString:@"flac"])
		result = [[FLACDecoder alloc] initWithURL:url error:error];
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
				
				*error = [NSError errorWithDomain:AudioDecoderErrorDomain 
											 code:AudioDecoderFileFormatNotRecognizedError 
										 userInfo:errorDictionary];
			}
			
			return nil;
		}
		
		switch(type) {
			case kOggStreamTypeVorbis:		result = [[OggVorbisDecoder alloc] initWithURL:url error:error];				break;
			case kOggStreamTypeFLAC:		result = [[OggFLACDecoder alloc] initWithURL:url error:error];				break;
//			case kOggStreamTypeSpeex:		result = [[AudioDecoder alloc] initWithURL:url error:error];					break;
			default:						result = nil;												break;
		}
	}
	else if([pathExtension isEqualToString:@"mpc"])
		result = [[MusepackDecoder alloc] initWithURL:url error:error];
	else if([pathExtension isEqualToString:@"wv"])
		result = [[WavPackDecoder alloc] initWithURL:url error:error];
	else if([pathExtension isEqualToString:@"ape"])
		result = [[MonkeysAudioDecoder alloc] initWithURL:url error:error];
	else if([pathExtension isEqualToString:@"mp3"])
		result = [[MPEGDecoder alloc] initWithURL:url error:error];
	else if([getCoreAudioExtensions() containsObject:pathExtension])
		result = [[CoreAudioDecoder alloc] initWithURL:url error:error];
	else {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The format of the file \"%@\" was not recognized.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"File Format Not Recognized", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:AudioDecoderErrorDomain 
										 code:AudioDecoderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		return nil;
	}
	
	return [result autorelease];
}

- (id) init
{
	// This will fail on purpose
	return [self initWithURL:nil error:nil];
}

- (id) initWithURL:(NSURL *)url error:(NSError **)error;
{
	NSParameterAssert(nil != url);
	
	if((self = [super init])) {
		_url = [url copy];

		// Canonical Core Audio format
		_format.mFormatID			= kAudioFormatLinearPCM;
		_format.mFormatFlags		= kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
		
		_format.mBitsPerChannel		= 8 * sizeof(float);
		
		_format.mBytesPerPacket		= (_format.mBitsPerChannel / 8);
		_format.mFramesPerPacket	= 1;
		_format.mBytesPerFrame		= _format.mBytesPerPacket * _format.mFramesPerPacket;		
	}
	return self;
}

- (void) dealloc
{
	[_url release], _url = nil;

	[super dealloc];
}

- (NSURL *)							URL					{ return [[_url retain] autorelease]; }
- (AudioStreamBasicDescription)		format				{ return _format; }
- (AudioChannelLayout)				channelLayout		{ return _channelLayout; }

- (NSString *) formatDescription
{
	NSString	*description	= nil;
	UInt32		specifierSize	= sizeof(description);
	
	OSStatus err = AudioFormatGetProperty(kAudioFormatProperty_FormatName, 
										  sizeof(_format), 
										  &_format, 
										  &specifierSize, 
										  &description);
	if(noErr != err)
		NSLog(@"AudioFormatGetProperty (kAudioFormatProperty_FormatName) failed: %i", err);
	
	return [description autorelease];
}

/*- (BOOL) hasChannelLayout
{
	return (0 != _channelLayout.mChannelLayoutTag || 0 != _channelLayout.mChannelBitmap || 0 != _channelLayout.mNumberChannelDescriptions);
}*/

- (NSString *) channelLayoutDescription
{
	NSString	*description	= nil;
	UInt32		specifierSize	= sizeof(description);
	
	OSStatus err = AudioFormatGetProperty(kAudioFormatProperty_ChannelLayoutName, 
										  sizeof(_channelLayout), 
										  &_channelLayout, 
										  &specifierSize, 
										  &description);
	if(noErr != err)
		NSLog(@"AudioFormatGetProperty (kAudioFormatProperty_ChannelLayoutName) failed: %i", err);
			
	return [description autorelease];
}

- (UInt32) readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount
{
	NSParameterAssert(NULL != bufferList);
	NSParameterAssert(0 < frameCount);
	
	// Default implementation returns silence
	UInt32 channel;
	for(channel = 0; channel < bufferList->mNumberBuffers; ++channel)
		memset(bufferList->mBuffers[channel].mData, 0, frameCount * sizeof(float));
	
	return frameCount;
}

- (AudioStreamBasicDescription)		sourceFormat		{ return _sourceFormat; }

- (NSString *) sourceFormatDescription
{
	AudioStreamBasicDescription		sourceFormat			= [self sourceFormat];	
	NSString						*sourceFormatName		= nil;
	UInt32							sourceFormatNameSize	= sizeof(sourceFormatName);
	
	OSStatus err = AudioFormatGetProperty(kAudioFormatProperty_FormatName, sizeof(sourceFormat), &sourceFormat, &sourceFormatNameSize, &sourceFormatName);
	if(noErr != err)
		return nil;	
	
	return [sourceFormatName autorelease];
}

- (SInt64)			totalFrames								{ return 0; }
- (SInt64)			currentFrame							{ return 0; }
- (SInt64)			framesRemaining 						{ return ([self totalFrames] - [self currentFrame]); }

- (BOOL)			supportsSeeking							{ return NO; }
- (SInt64)			seekToFrame:(SInt64)frame				{ return -1; }

- (NSString *)		description								{ return [[[self URL] path] lastPathComponent]; }

@end
