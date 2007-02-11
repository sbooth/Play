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

#import "AlbumTitlesNodeData.h"
#import "AudioLibrary.h"
#import "AlbumTitleNodeData.h"
#import "BrowserNode.h"

@implementation AlbumTitlesNodeData

- (id) init
{
	if((self = [super initWithName:NSLocalizedStringFromTable(@"Albums", @"General", @"")])) {
		_albumTitles = [[NSMutableArray alloc] init];
		return self;
	}	
	return nil;
}

- (void) dealloc
{
	[_albumTitles release], _albumTitles = nil;
	
	[super dealloc];
}

- (void) refreshData
{
	[_albumTitles release];
	_albumTitles = [[[AudioLibrary defaultLibrary] allAlbumTitles] mutableCopy];
}

- (unsigned) countOfChildren			{ return [_albumTitles count]; }

- (BrowserNode *) childAtIndex:(unsigned)index
{
	NSString *albumTitle = [_albumTitles objectAtIndex:index];
	AlbumTitleNodeData *representedObject = [[AlbumTitleNodeData alloc] initWithName:albumTitle];
	[representedObject setSelectable:YES];
	return [[[BrowserNode alloc] initWithParent:[self node] representedObject:[representedObject autorelease]] autorelease];
}

@end
