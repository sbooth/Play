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

#import "PlaylistEntry.h"
#import "DatabaseContext.h"

NSString * const	PlaylistEntryDidChangeNotification		= @"org.sbooth.Play.PlaylistEntryDidChangeNotification";

NSString * const	PlaylistEntryObjectKey					= @"org.sbooth.Play.PlaylistEntry";

NSString * const	PlaylistObjectIDKey						= @"playlistID";
NSString * const	AudioStreamObjectIDKey					= @"streamID";
NSString * const	PlaylistEntryPositionKey				= @"position";

@implementation PlaylistEntry

+ (id) insertPlaylistEntryWithInitialValues:(NSDictionary *)keyedValues inDatabaseContext:(DatabaseContext *)context;
{
	NSParameterAssert(nil != context);
	
	PlaylistEntry *entry = [[PlaylistEntry alloc] initWithDatabaseContext:context];
	
	// Call init: methods here to avoid sending change notifications to the context
	[entry initValuesForKeysWithDictionary:keyedValues];
	
	if(NO == [context insertPlaylistEntry:entry]) {
		[entry release], entry = nil;
	}
	
	return [entry autorelease];
}

- (AudioStream *) stream
{
	return [[self databaseContext] streamForID:[self valueForKey:AudioStreamObjectIDKey]];
}

- (Playlist *) playlist
{
	return [[self databaseContext] playlistForID:[self valueForKey:PlaylistObjectIDKey]];
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"[%@] %@ %@ (%@)", [self valueForKey:ObjectIDKey], [self valueForKey:PlaylistEntryPositionKey], [self stream], [self playlist]];
}

#pragma mark Callbacks

- (void) didSave
{
	[[NSNotificationCenter defaultCenter] postNotificationName:PlaylistEntryDidChangeNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:self forKey:PlaylistEntryObjectKey]];
}

#pragma mark Reimplementations

- (NSArray *) databaseKeys
{
	if(nil == _databaseKeys) {
		_databaseKeys	= [[NSArray alloc] initWithObjects:
			ObjectIDKey, 
			
			PlaylistObjectIDKey, 			
			AudioStreamObjectIDKey,
			PlaylistEntryPositionKey,
			
			nil];
	}	
	return _databaseKeys;
}

@end
