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

#import <CoreData/CoreData.h>

@class Playlist;
@class AudioStream;

@interface Library :  NSManagedObject  
{
}

// Access to-many relationship via -[NSObject mutableSetValueForKey:]
- (void)addPlaylistsObject:(Playlist *)value;
- (void)removePlaylistsObject:(Playlist *)value;

// Access to-many relationship via -[NSObject mutableSetValueForKey:]
- (void)addStreamsObject:(AudioStream *)value;
- (void)removeStreamsObject:(AudioStream *)value;

- (AudioStream *)nowPlaying;
- (void)setNowPlaying:(AudioStream *)value;

- (AudioStream *) streamObjectForURL:(NSURL *)url error:(NSError **)error;

- (void) removeStreamObjectForURL:(NSURL *)url error:(NSError **)error;

@end
