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
#import "DatabaseObject.h"

// ========================================
// Notification Names
// ========================================
extern NSString * const		AudioStreamDidChangeNotification;

// ========================================
// Notification Keys
// ========================================
extern NSString * const		AudioStreamObjectKey;

// ========================================
// KVC key names for persistent properties
// ========================================
extern NSString * const		StreamURLKey;

extern NSString * const		StatisticsDateAddedKey;
extern NSString * const		StatisticsFirstPlayedDateKey;
extern NSString * const		StatisticsLastPlayedDateKey;
extern NSString * const		StatisticsPlayCountKey;

extern NSString * const		MetadataTitleKey;
extern NSString * const		MetadataAlbumTitleKey;
extern NSString * const		MetadataArtistKey;
extern NSString * const		MetadataAlbumArtistKey;
extern NSString * const		MetadataGenreKey;
extern NSString * const		MetadataComposerKey;
extern NSString * const		MetadataDateKey;
extern NSString * const		MetadataCompilationKey;
extern NSString * const		MetadataTrackNumberKey;
extern NSString * const		MetadataTrackTotalKey;
extern NSString * const		MetadataDiscNumberKey;
extern NSString * const		MetadataDiscTotalKey;
extern NSString * const		MetadataCommentKey;
extern NSString * const		MetadataISRCKey;
extern NSString * const		MetadataMCNKey;

extern NSString * const		PropertiesFileTypeKey;
extern NSString * const		PropertiesFormatTypeKey;
extern NSString * const		PropertiesBitsPerChannelKey;
extern NSString * const		PropertiesChannelsPerFrameKey;
extern NSString * const		PropertiesSampleRateKey;
extern NSString * const		PropertiesTotalFramesKey;
extern NSString * const		PropertiesDurationKey;
extern NSString * const		PropertiesBitrateKey;

@interface AudioStream : DatabaseObject
{
	BOOL	_playing;
	id		_albumArt;
}

+ (id) insertStreamForURL:(NSURL *)URL withInitialValues:(NSDictionary *)keyedValues inDatabaseContext:(DatabaseContext *)context;

- (NSString *) filename;
- (NSString *) pathname;

- (BOOL) isPlaying;
- (void) setPlaying:(BOOL)playing;

@end
