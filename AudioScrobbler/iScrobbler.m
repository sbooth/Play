/*
 *  $Id$
 *
 *  Copyright (C) 2006 - 2008 Stephen F. Booth <me@sbooth.org>
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

#import "iScrobbler.h"
#import "AudioStream.h"

@interface iScrobbler (Private)
- (NSDictionary *) dictionaryForStream:(AudioStream *)stream;
@end

@implementation iScrobbler

/*
 com.apple.iTunes.playerInfo
 
 {
 Album = "Ex Tenebris";
 Artist = "White Willow";
 "Disc Count" = 1;
 "Disc Number" = 1;
 Genre = "Progressive Rock";
 Grouping = "dl,dky";
 Location = "file://localhost/Volumes/Media/Music/White%20Willow/Ex%20Tenebris/05%20Thirteen%20Days.mp3";
 Name = "Thirteen Days";
 "Player State" = Playing;
 Rating = 100;
 "Store URL" = "itms://itunes.com/link?n=Thirteen%20Days&an=White%20Willow&pn=Ex%20Tenebris";
 "Total Time" = 170396;
 "Track Count" = 7;
 "Track Number" = 5;
 Year = 1998;
 }
 */


- (void) playbackDidStartForStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	
	
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	[userInfo setObject:@"Playing" forKey:@"Player State"];
	[userInfo addEntriesFromDictionary:[self dictionaryForStream:stream]];

	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"org.sbooth.Play.playerInfo"
																   object:nil
																 userInfo:userInfo];
}

- (void) playbackDidStopForStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);

	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	[userInfo setObject:@"Stopped" forKey:@"Player State"];
	[userInfo addEntriesFromDictionary:[self dictionaryForStream:stream]];
	
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"org.sbooth.Play.playerInfo"
																   object:nil
																 userInfo:userInfo];
}

- (void) playbackDidPauseForStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
	
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	[userInfo setObject:@"Paused" forKey:@"Player State"];
	[userInfo addEntriesFromDictionary:[self dictionaryForStream:stream]];
	
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"org.sbooth.Play.playerInfo"
																   object:nil
																 userInfo:userInfo];
}

- (void) playbackDidResumeForStream:(AudioStream *)stream
{
	[self playbackDidStartForStream:stream];
}

@end

@implementation iScrobbler (Private)

- (NSDictionary *) dictionaryForStream:(AudioStream *)stream
{
	NSParameterAssert(nil != stream);
			
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	
	[userInfo setObject:[[stream valueForKey:StreamURLKey] absoluteString] forKey:@"Location"];
	[userInfo setValue:[stream valueForKey:MetadataArtistKey] forKey:@"Artist"];
	[userInfo setValue:[stream valueForKey:MetadataTitleKey] forKey:@"Name"];
	[userInfo setValue:[stream valueForKey:MetadataAlbumTitleKey] forKey:@"Album"];
	[userInfo setValue:[stream valueForKey:MetadataGenreKey] forKey:@"Genre"];
	[userInfo setValue:[stream valueForKey:MetadataTrackNumberKey] forKey:@"Track Number"];
	[userInfo setValue:[stream valueForKey:MetadataTrackTotalKey] forKey:@"Track Count"];
	[userInfo setValue:[stream valueForKey:MetadataDiscNumberKey] forKey:@"Disc Number"];
	[userInfo setValue:[stream valueForKey:MetadataDiscTotalKey] forKey:@"Disc Count"];

	UInt32 durationInMilliseconds = 1000 * [[stream valueForKey:PropertiesTotalFramesKey] longLongValue] / [[stream valueForKey:PropertiesSampleRateKey] floatValue];
	[userInfo setObject:[NSNumber numberWithInt:durationInMilliseconds] forKey:@"Total Time"];

	return [[userInfo retain] autorelease];
}

@end
