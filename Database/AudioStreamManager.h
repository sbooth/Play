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

#import <Cocoa/Cocoa.h>
#include "sqlite3.h"

@class AudioStream;

// ========================================
// Singleton class that provides access to the AudioStream objects contained
// in the database managed by the CollectionManager
// Provides a single, unique object for each stream
// This class does not guarantee fast access!
// This class is KVC-compliant (read only) for the key "streams"
// ========================================
@interface AudioStreamManager : NSObject
{
	@private
	sqlite3					*_db;				// The database to use, owned by CollectionManager
	NSMutableDictionary		*_sql;				// Prepared SQL statements
	NSMapTable 				*_streams;			// Registered streams
}

// ========================================
// The shared instance
+ (AudioStreamManager *) streamManager;

// ========================================
// AudioStream support
- (NSArray *) streams;
- (NSArray *) streamsForArtist:(NSString *)artist;
- (NSArray *) streamsForAlbumTitle:(NSString *)albumTitle;
//- (NSArray *) streamsForPlaylist:(Playlist *)playlist;

- (AudioStream *) streamForID:(NSNumber *)objectID;
- (AudioStream *) streamForURL:(NSURL *)url;

- (BOOL) insertStream:(AudioStream *)stream;
- (void) saveStream:(AudioStream *)stream;
- (void) deleteStream:(AudioStream *)stream;
- (void) revertStream:(AudioStream *)stream;

@end
