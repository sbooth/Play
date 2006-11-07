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

#import "Library.h"

#import "Playlist.h"
#import "AudioStream.h"

@implementation Library 


- (void)addPlaylistsObject:(Playlist *)value 
{    
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"playlists" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    
    [[self primitiveValueForKey: @"playlists"] addObject: value];
    
    [self didChangeValueForKey:@"playlists" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    
    [changedObjects release];
}

- (void)removePlaylistsObject:(Playlist *)value 
{
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"playlists" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    
    [[self primitiveValueForKey: @"playlists"] removeObject: value];
    
    [self didChangeValueForKey:@"playlists" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    
    [changedObjects release];
}


- (void)addStreamsObject:(AudioStream *)value 
{    
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"streams" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    
    [[self primitiveValueForKey: @"streams"] addObject: value];
    
    [self didChangeValueForKey:@"streams" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    
    [changedObjects release];
}

- (void)removeStreamsObject:(AudioStream *)value 
{
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"streams" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    
    [[self primitiveValueForKey: @"streams"] removeObject: value];
    
    [self didChangeValueForKey:@"streams" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    
    [changedObjects release];
}


- (AudioStream *)nowPlaying 
{
    id tmpObject;
    
    [self willAccessValueForKey: @"nowPlaying"];
    tmpObject = [self primitiveValueForKey: @"nowPlaying"];
    [self didAccessValueForKey: @"nowPlaying"];
    
    return tmpObject;
}

- (void)setNowPlaying:(AudioStream *)value 
{
    [self willChangeValueForKey: @"nowPlaying"];
    [self setPrimitiveValue: value
                     forKey: @"nowPlaying"];
    [self didChangeValueForKey: @"nowPlaying"];
}


@end
