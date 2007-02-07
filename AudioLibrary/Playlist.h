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

// ========================================
// Playlist kinds
// ========================================
typedef enum _ePlaylistType {
	ePlaylistTypeStaticPlaylist		= 1,
	ePlaylistTypeFolderPlaylist		= 2,
	ePlaylistTypeDynamicPlaylist	= 3
} ePlaylistType;

@interface Playlist : NSObject
{
	@private
	NSMutableDictionary *_d;
}

// Call this with the values retrieved from the database
- (void) initValue:(id)value forKey:(NSString *)key;

- (ePlaylistType) type;
- (NSString *) tableName;

@end
