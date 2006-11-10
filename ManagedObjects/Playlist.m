// 
//  Playlist.m
//  Play
//
//  Created by Stephen Booth on 11/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "Playlist.h"

#import "Library.h"

@implementation Playlist 

- (void) awakeFromInsert
{
	[super awakeFromInsert];
	[self setDateCreated:[NSDate date]];
}

- (NSDate *)lastPlayed 
{
    NSDate * tmpValue;
    
    [self willAccessValueForKey: @"lastPlayed"];
    tmpValue = [self primitiveValueForKey: @"lastPlayed"];
    [self didAccessValueForKey: @"lastPlayed"];
    
    return tmpValue;
}

- (void)setLastPlayed:(NSDate *)value 
{
    [self willChangeValueForKey: @"lastPlayed"];
    [self setPrimitiveValue: value forKey: @"lastPlayed"];
    [self didChangeValueForKey: @"lastPlayed"];
}

- (NSString *)name 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey: @"name"];
    tmpValue = [self primitiveValueForKey: @"name"];
    [self didAccessValueForKey: @"name"];
    
    return tmpValue;
}

- (void)setName:(NSString *)value 
{
    [self willChangeValueForKey: @"name"];
    [self setPrimitiveValue: value forKey: @"name"];
    [self didChangeValueForKey: @"name"];
}

- (NSDate *)dateCreated 
{
    NSDate * tmpValue;
    
    [self willAccessValueForKey: @"dateCreated"];
    tmpValue = [self primitiveValueForKey: @"dateCreated"];
    [self didAccessValueForKey: @"dateCreated"];
    
    return tmpValue;
}

- (void)setDateCreated:(NSDate *)value 
{
    [self willChangeValueForKey: @"dateCreated"];
    [self setPrimitiveValue: value forKey: @"dateCreated"];
    [self didChangeValueForKey: @"dateCreated"];
}

- (NSDate *)firstPlayed 
{
    NSDate * tmpValue;
    
    [self willAccessValueForKey: @"firstPlayed"];
    tmpValue = [self primitiveValueForKey: @"firstPlayed"];
    [self didAccessValueForKey: @"firstPlayed"];
    
    return tmpValue;
}

- (void)setFirstPlayed:(NSDate *)value 
{
    [self willChangeValueForKey: @"firstPlayed"];
    [self setPrimitiveValue: value forKey: @"firstPlayed"];
    [self didChangeValueForKey: @"firstPlayed"];
}

- (NSNumber *)playCount 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey: @"playCount"];
    tmpValue = [self primitiveValueForKey: @"playCount"];
    [self didAccessValueForKey: @"playCount"];
    
    return tmpValue;
}

- (void)setPlayCount:(NSNumber *)value 
{
    [self willChangeValueForKey: @"playCount"];
    [self setPrimitiveValue: value forKey: @"playCount"];
    [self didChangeValueForKey: @"playCount"];
}


- (Library *)library 
{
    id tmpObject;
    
    [self willAccessValueForKey: @"library"];
    tmpObject = [self primitiveValueForKey: @"library"];
    [self didAccessValueForKey: @"library"];
    
    return tmpObject;
}

- (void)setLibrary:(Library *)value 
{
    [self willChangeValueForKey: @"library"];
    [self setPrimitiveValue: value
                     forKey: @"library"];
    [self didChangeValueForKey: @"library"];
}

- (NSImage *) image
{
	return nil;
}

- (void) setImage:(NSImage *)image
{
	// no-op
}

@end
