//
//  Playlist.h
//  Play
//
//  Created by Stephen Booth on 11/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <CoreData/CoreData.h>

@class Library;

@interface Playlist :  NSManagedObject  
{
}

- (NSDate *)lastPlayed;
- (void)setLastPlayed:(NSDate *)value;

- (NSString *)name;
- (void)setName:(NSString *)value;

- (NSDate *)dateCreated;
- (void)setDateCreated:(NSDate *)value;

- (NSDate *)firstPlayed;
- (void)setFirstPlayed:(NSDate *)value;

- (NSNumber *)playCount;
- (void)setPlayCount:(NSNumber *)value;

- (Library *)library;
- (void)setLibrary:(Library *)value;

- (NSImage *)image;
- (void)setImage:(NSImage *)image;

@end
