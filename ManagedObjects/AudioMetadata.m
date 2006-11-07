// 
//  AudioMetadata.m
//  Play
//
//  Created by Stephen Booth on 11/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "AudioMetadata.h"
#import "AudioStream.h"

#import "AudioMetadataWriter.h"

@implementation AudioMetadata 

- (NSString *)date 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey: @"date"];
    tmpValue = [self primitiveValueForKey: @"date"];
    [self didAccessValueForKey: @"date"];
    
    return tmpValue;
}

- (void)setDate:(NSString *)value 
{
    [self willChangeValueForKey: @"date"];
    [self setPrimitiveValue: value forKey: @"date"];
    [self didChangeValueForKey: @"date"];
}

- (NSString *)albumTitle 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey: @"albumTitle"];
    tmpValue = [self primitiveValueForKey: @"albumTitle"];
    [self didAccessValueForKey: @"albumTitle"];
    
    return tmpValue;
}

- (void)setAlbumTitle:(NSString *)value 
{
    [self willChangeValueForKey: @"albumTitle"];
    [self setPrimitiveValue: value forKey: @"albumTitle"];
    [self didChangeValueForKey: @"albumTitle"];
}

- (NSString *)composer 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey: @"composer"];
    tmpValue = [self primitiveValueForKey: @"composer"];
    [self didAccessValueForKey: @"composer"];
    
    return tmpValue;
}

- (void)setComposer:(NSString *)value 
{
    [self willChangeValueForKey: @"composer"];
    [self setPrimitiveValue: value forKey: @"composer"];
    [self didChangeValueForKey: @"composer"];
}

- (NSString *)title 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey: @"title"];
    tmpValue = [self primitiveValueForKey: @"title"];
    [self didAccessValueForKey: @"title"];
    
    return tmpValue;
}

- (void)setTitle:(NSString *)value 
{
    [self willChangeValueForKey: @"title"];
    [self setPrimitiveValue: value forKey: @"title"];
    [self didChangeValueForKey: @"title"];
}

- (NSString *)genre 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey: @"genre"];
    tmpValue = [self primitiveValueForKey: @"genre"];
    [self didAccessValueForKey: @"genre"];
    
    return tmpValue;
}

- (void)setGenre:(NSString *)value 
{
    [self willChangeValueForKey: @"genre"];
    [self setPrimitiveValue: value forKey: @"genre"];
    [self didChangeValueForKey: @"genre"];
}

- (NSString *)isrc 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey: @"isrc"];
    tmpValue = [self primitiveValueForKey: @"isrc"];
    [self didAccessValueForKey: @"isrc"];
    
    return tmpValue;
}

- (void)setIsrc:(NSString *)value 
{
    [self willChangeValueForKey: @"isrc"];
    [self setPrimitiveValue: value forKey: @"isrc"];
    [self didChangeValueForKey: @"isrc"];
}

- (NSString *)albumArtist 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey: @"albumArtist"];
    tmpValue = [self primitiveValueForKey: @"albumArtist"];
    [self didAccessValueForKey: @"albumArtist"];
    
    return tmpValue;
}

- (void)setAlbumArtist:(NSString *)value 
{
    [self willChangeValueForKey: @"albumArtist"];
    [self setPrimitiveValue: value forKey: @"albumArtist"];
    [self didChangeValueForKey: @"albumArtist"];
}

- (NSNumber *)trackNumber 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey: @"trackNumber"];
    tmpValue = [self primitiveValueForKey: @"trackNumber"];
    [self didAccessValueForKey: @"trackNumber"];
    
    return tmpValue;
}

- (void)setTrackNumber:(NSNumber *)value 
{
    [self willChangeValueForKey: @"trackNumber"];
    [self setPrimitiveValue: value forKey: @"trackNumber"];
    [self didChangeValueForKey: @"trackNumber"];
}

- (NSNumber *)partOfCompilation 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey: @"partOfCompilation"];
    tmpValue = [self primitiveValueForKey: @"partOfCompilation"];
    [self didAccessValueForKey: @"partOfCompilation"];
    
    return tmpValue;
}

- (void)setPartOfCompilation:(NSNumber *)value 
{
    [self willChangeValueForKey: @"partOfCompilation"];
    [self setPrimitiveValue: value forKey: @"partOfCompilation"];
    [self didChangeValueForKey: @"partOfCompilation"];
}

- (NSString *)artist 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey: @"artist"];
    tmpValue = [self primitiveValueForKey: @"artist"];
    [self didAccessValueForKey: @"artist"];
    
    return tmpValue;
}

- (void)setArtist:(NSString *)value 
{
    [self willChangeValueForKey: @"artist"];
    [self setPrimitiveValue: value forKey: @"artist"];
    [self didChangeValueForKey: @"artist"];
}

- (NSNumber *)discTotal 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey: @"discTotal"];
    tmpValue = [self primitiveValueForKey: @"discTotal"];
    [self didAccessValueForKey: @"discTotal"];
    
    return tmpValue;
}

- (void)setDiscTotal:(NSNumber *)value 
{
    [self willChangeValueForKey: @"discTotal"];
    [self setPrimitiveValue: value forKey: @"discTotal"];
    [self didChangeValueForKey: @"discTotal"];
}

- (NSString *)mcn 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey: @"mcn"];
    tmpValue = [self primitiveValueForKey: @"mcn"];
    [self didAccessValueForKey: @"mcn"];
    
    return tmpValue;
}

- (void)setMcn:(NSString *)value 
{
    [self willChangeValueForKey: @"mcn"];
    [self setPrimitiveValue: value forKey: @"mcn"];
    [self didChangeValueForKey: @"mcn"];
}

- (NSData *)albumArt 
{
    NSData * tmpValue;
    
    [self willAccessValueForKey: @"albumArt"];
    tmpValue = [self primitiveValueForKey: @"albumArt"];
    [self didAccessValueForKey: @"albumArt"];
    
    return tmpValue;
}

- (void)setAlbumArt:(NSData *)value 
{
    [self willChangeValueForKey: @"albumArt"];
    [self setPrimitiveValue: value forKey: @"albumArt"];
    [self didChangeValueForKey: @"albumArt"];
}

- (NSString *)comment 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey: @"comment"];
    tmpValue = [self primitiveValueForKey: @"comment"];
    [self didAccessValueForKey: @"comment"];
    
    return tmpValue;
}

- (void)setComment:(NSString *)value 
{
    [self willChangeValueForKey: @"comment"];
    [self setPrimitiveValue: value forKey: @"comment"];
    [self didChangeValueForKey: @"comment"];
}

- (NSNumber *)trackTotal 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey: @"trackTotal"];
    tmpValue = [self primitiveValueForKey: @"trackTotal"];
    [self didAccessValueForKey: @"trackTotal"];
    
    return tmpValue;
}

- (void)setTrackTotal:(NSNumber *)value 
{
    [self willChangeValueForKey: @"trackTotal"];
    [self setPrimitiveValue: value forKey: @"trackTotal"];
    [self didChangeValueForKey: @"trackTotal"];
}

- (NSNumber *)discNumber 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey: @"discNumber"];
    tmpValue = [self primitiveValueForKey: @"discNumber"];
    [self didAccessValueForKey: @"discNumber"];
    
    return tmpValue;
}

- (void)setDiscNumber:(NSNumber *)value 
{
    [self willChangeValueForKey: @"discNumber"];
    [self setPrimitiveValue: value forKey: @"discNumber"];
    [self didChangeValueForKey: @"discNumber"];
}


- (AudioStream *)stream 
{
    id tmpObject;
    
    [self willAccessValueForKey: @"stream"];
    tmpObject = [self primitiveValueForKey: @"stream"];
    [self didAccessValueForKey: @"stream"];
    
    return tmpObject;
}

- (void)setStream:(AudioStream *)value 
{
    [self willChangeValueForKey: @"stream"];
    [self setPrimitiveValue: value
                     forKey: @"stream"];
    [self didChangeValueForKey: @"stream"];
}

- (void)willSave
{
	NSURL					*url;
	NSError					*error;
	AudioMetadataWriter		*metadataWriter;
	BOOL					result;

	// Only save metadata when we are updated (not inserted or deleted)
	if(NO == [self isUpdated]) {
		return;
	}
	
	error					= nil;
	url						= [NSURL URLWithString:[[self stream] url]];
	metadataWriter			= [AudioMetadataWriter metadataWriterForURL:url error:&error];
	
	// Not all stream types support writing of metadata
	if(nil == metadataWriter) {
		
		if(nil != error) {
			NSLog(@"Unable to create metadata writer for \"%@\": %@", url, error);
//			[[[NSDocumentController sharedDocumentController] currentDocument] presentError:error];
		}

		return;
	}

#if DEBUG
	NSLog(@"Saving metadata to %@", url);
#endif
	
	result					= [metadataWriter writeMetadata:self error:&error];
	if(NO == result) {
		NSLog(@"Unable to save metadata for \"%@\": %@", url, error);
//		[[[NSDocumentController sharedDocumentController] currentDocument] presentError:error];
	}
}
@end
