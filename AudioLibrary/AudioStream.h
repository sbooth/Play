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
// Key Names
// ========================================
extern NSString * const		kMetadataTitleKey;
extern NSString * const		kMetadataAlbumTitleKey;
extern NSString * const		kMetadataArtistKey;
extern NSString * const		kMetadataAlbumArtistKey;

@interface AudioStream : NSObject
{
	NSMutableDictionary *_streamInfo;
	NSArray				*_databaseKeys;

	BOOL				_isDirty;
	
	BOOL				_isPlaying;
	id					_albumArt;
}

// Call this with the values retrieved from the database
- (void) initValue:(id)value forKey:(NSString *)key;

- (BOOL) isDirty;
- (void) setIsDirty:(BOOL)isDirty;

- (BOOL) isPlaying;
- (void) setIsPlaying:(BOOL)isPlaying;

@end
