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

#import "BrowserNodeData.h"
#import "BrowserNode.h"

@implementation BrowserNodeData

- (id) initWithName:(NSString *)name
{
	if((self = [super init])) {
		[self setName:name];
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_node release], _node = nil;
	[_name release], _name = nil;
	[_icon release], _icon = nil;
	
	[super dealloc];
}

- (BrowserNode *)		node								{ return _node; }
- (void)				setNode:(BrowserNode *)node			{ [_node release]; _node = [node retain]; }

- (NSString *)			name								{ return _name; }
- (void)				setName:(NSString *)name			{ [_name release]; _name = [name retain]; }

- (BOOL)				isSelectable						{ return _isSelectable; }
- (void)				setSelectable:(BOOL)selectable		{ _isSelectable = selectable; }

- (NSImage *)			icon								{ return _icon; }
- (void)				setIcon:(NSImage *)icon				{ [_icon release]; _icon = [icon retain]; }

- (NSComparisonResult) compare:(BrowserNodeData *)data
{
	return [_name compare:[data valueForKey:@"name"]];
}

- (NSString *) description
{
	return _name;
}

@end
