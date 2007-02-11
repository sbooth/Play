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

#import "BrowserOutlineViewDataSource.h"
#import "BrowserNode.h"

@implementation BrowserOutlineViewDataSource

- (void) dealloc
{
	[_rootNode release], _rootNode = nil;
	
	[super dealloc];
}

- (BrowserNode *)	rootNode								{ return _rootNode; }
- (void)			setRootNode:(BrowserNode *)rootNode		{ [_rootNode release], _rootNode = [rootNode retain]; }

- (id) outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
	BrowserNode *node = (nil == item ? [self rootNode] : (BrowserNode *)item);
	return [node childAtIndex:index];
}

- (BOOL) outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	BrowserNode *node = (nil == item ? [self rootNode] : (BrowserNode *)item);
	return (0 != [node countOfChildren]);
}

- (int) outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	BrowserNode *node = (nil == item ? [self rootNode] : (BrowserNode *)item);
	return [node countOfChildren];
}

- (id) outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	BrowserNode *node = (nil == item ? [self rootNode] : (BrowserNode *)item);
	return [[node representedObject] valueForKey:@"name"];
}

- (void) outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	BrowserNode *node = (BrowserNode *)item;
	
	[[node representedObject] setValue:object forKey:@"name"];
}

@end
