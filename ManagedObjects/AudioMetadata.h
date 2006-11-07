//
//  AudioMetadata.h
//  Play
//
//  Created by Stephen Booth on 11/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <CoreData/CoreData.h>

@class AudioStream;

@interface AudioMetadata :  NSManagedObject  
{
}

- (NSString *)date;
- (void)setDate:(NSString *)value;

- (NSString *)albumTitle;
- (void)setAlbumTitle:(NSString *)value;

- (NSString *)composer;
- (void)setComposer:(NSString *)value;

- (NSString *)title;
- (void)setTitle:(NSString *)value;

- (NSString *)genre;
- (void)setGenre:(NSString *)value;

- (NSString *)isrc;
- (void)setIsrc:(NSString *)value;

- (NSString *)albumArtist;
- (void)setAlbumArtist:(NSString *)value;

- (NSNumber *)trackNumber;
- (void)setTrackNumber:(NSNumber *)value;

- (NSNumber *)partOfCompilation;
- (void)setPartOfCompilation:(NSNumber *)value;

- (NSString *)artist;
- (void)setArtist:(NSString *)value;

- (NSNumber *)discTotal;
- (void)setDiscTotal:(NSNumber *)value;

- (NSString *)mcn;
- (void)setMcn:(NSString *)value;

- (NSData *)albumArt;
- (void)setAlbumArt:(NSData *)value;

- (NSString *)comment;
- (void)setComment:(NSString *)value;

- (NSNumber *)trackTotal;
- (void)setTrackTotal:(NSNumber *)value;

- (NSNumber *)discNumber;
- (void)setDiscNumber:(NSNumber *)value;

- (AudioStream *)stream;
- (void)setStream:(AudioStream *)value;

@end
