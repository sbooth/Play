// 
//  AudioStream.m
//  Play
//
//  Created by Stephen Booth on 11/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "AudioStream.h"

#import "AudioMetadata.h"
#import "StaticPlaylist.h"
#import "Library.h"

@implementation AudioStream 

- (NSString *)url 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey: @"url"];
    tmpValue = [self primitiveValueForKey: @"url"];
    [self didAccessValueForKey: @"url"];
    
    return tmpValue;
}

- (void)setUrl:(NSString *)value 
{
    [self willChangeValueForKey: @"url"];
    [self setPrimitiveValue: value forKey: @"url"];
    [self didChangeValueForKey: @"url"];
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

- (NSDate *)dateAdded 
{
    NSDate * tmpValue;
    
    [self willAccessValueForKey: @"dateAdded"];
    tmpValue = [self primitiveValueForKey: @"dateAdded"];
    [self didAccessValueForKey: @"dateAdded"];
    
    return tmpValue;
}

- (void)setDateAdded:(NSDate *)value 
{
    [self willChangeValueForKey: @"dateAdded"];
    [self setPrimitiveValue: value forKey: @"dateAdded"];
    [self didChangeValueForKey: @"dateAdded"];
}

- (NSNumber *)isPlaying 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey: @"isPlaying"];
    tmpValue = [self primitiveValueForKey: @"isPlaying"];
    [self didAccessValueForKey: @"isPlaying"];
    
    return tmpValue;
}

- (void)setIsPlaying:(NSNumber *)value 
{
    [self willChangeValueForKey: @"isPlaying"];
    [self setPrimitiveValue: value forKey: @"isPlaying"];
    [self didChangeValueForKey: @"isPlaying"];
}


- (NSManagedObject *)properties 
{
    id tmpObject;
    
    [self willAccessValueForKey: @"properties"];
    tmpObject = [self primitiveValueForKey: @"properties"];
    [self didAccessValueForKey: @"properties"];
    
    return tmpObject;
}

- (void)setProperties:(NSManagedObject *)value 
{
    [self willChangeValueForKey: @"properties"];
    [self setPrimitiveValue: value
                     forKey: @"properties"];
    [self didChangeValueForKey: @"properties"];
}



- (AudioMetadata *)metadata 
{
    id tmpObject;
    
    [self willAccessValueForKey: @"metadata"];
    tmpObject = [self primitiveValueForKey: @"metadata"];
    [self didAccessValueForKey: @"metadata"];
    
    return tmpObject;
}

- (void)setMetadata:(AudioMetadata *)value 
{
    [self willChangeValueForKey: @"metadata"];
    [self setPrimitiveValue: value
                     forKey: @"metadata"];
    [self didChangeValueForKey: @"metadata"];
}



- (void)addPlaylistsObject:(StaticPlaylist *)value 
{    
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"playlists" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    
    [[self primitiveValueForKey: @"playlists"] addObject: value];
    
    [self didChangeValueForKey:@"playlists" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    
    [changedObjects release];
}

- (void)removePlaylistsObject:(StaticPlaylist *)value 
{
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"playlists" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    
    [[self primitiveValueForKey: @"playlists"] removeObject: value];
    
    [self didChangeValueForKey:@"playlists" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    
    [changedObjects release];
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


@end
