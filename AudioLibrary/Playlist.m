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

#import "Playlist.h"
#import "AudioLibrary.h"

@implementation Playlist

- (id) init
{
	if((self = [super init])) {
		_d = [[NSMutableDictionary alloc] init];
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_d release], _d = nil;
	[super dealloc];
}

- (id) valueForKey:(NSString *)key
{
	return [_d valueForKey:key];
}

- (void) initValue:(id)value forKey:(NSString *)key
{
	[_d setValue:value forKey:key];	
}

- (void) setValue:(id)value forKey:(NSString *)key
{
	[_d setValue:value forKey:key];
	
	// Propagate changes to database
	[[AudioLibrary defaultLibrary] playlistDidChange:self];
}

- (unsigned) hash
{
	// Database ID is guaranteed to be unique
	return [[_d valueForKey:@"id"] unsignedIntValue];
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"[%@] %@", [_d valueForKey:@"id"], [_d valueForKey:@"name"]];
}

@end
