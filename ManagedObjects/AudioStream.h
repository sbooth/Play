//
//  AudioStream.h
//  Play
//
//  Created by Stephen Booth on 11/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <CoreData/CoreData.h>

@class AudioMetadata;
@class StaticPlaylist;
@class Library;

@interface AudioStream :  NSManagedObject  
{
}

- (NSString *)url;
- (void)setUrl:(NSString *)value;

- (NSNumber *)playCount;
- (void)setPlayCount:(NSNumber *)value;

- (NSDate *)firstPlayed;
- (void)setFirstPlayed:(NSDate *)value;

- (NSDate *)lastPlayed;
- (void)setLastPlayed:(NSDate *)value;

- (NSDate *)dateAdded;
- (void)setDateAdded:(NSDate *)value;

- (NSNumber *)isPlaying;
- (void)setIsPlaying:(NSNumber *)value;

- (NSManagedObject *)properties;
- (void)setProperties:(NSManagedObject *)value;

- (AudioMetadata *)metadata;
- (void)setMetadata:(AudioMetadata *)value;

// Access to-many relationship via -[NSObject mutableSetValueForKey:]
- (void)addPlaylistsObject:(StaticPlaylist *)value;
- (void)removePlaylistsObject:(StaticPlaylist *)value;

- (Library *)library;
- (void)setLibrary:(Library *)value;

@end
