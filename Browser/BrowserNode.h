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

@class BrowserNodeData;

// ========================================
// A node in the source list
// ========================================
@interface BrowserNode : NSObject
{
	BrowserNode		*_parent;
	NSMutableArray	*_children;
	
	BrowserNodeData	*_representedObject;
}

- (id) initWithParent:(BrowserNode *)parent;
- (id) initWithRepresentedObject:(BrowserNodeData *)representedObject;
- (id) initWithParent:(BrowserNode *)parent representedObject:(BrowserNodeData *)representedObject;

// ========================================
// Parent management
- (BrowserNode *) parent;
- (void) setParent:(BrowserNode *)parent;

- (void) removeFromParent;

// ========================================
// Child management
- (NSArray *) children;
- (unsigned) countOfChildren;

- (BrowserNode *) firstChild;
- (BrowserNode *) lastChild;

- (BrowserNode *) childAtIndex:(unsigned)index;
- (unsigned) indexOfChild:(BrowserNode *)child;

- (void) addChild:(BrowserNode *)child;
- (void) insertChild:(BrowserNode *)child atIndex:(unsigned)index;
- (void) insertChildren:(NSArray *)children atIndexes:(NSIndexSet *)indexes;

- (void) removeChild:(BrowserNode *)child;

- (void) sortChildren;
- (void) recursivelySortChildren;

// ========================================
// Relationship management
- (BOOL) isDescendantOfNode:(BrowserNode *)node;
- (BOOL) isDescendantOfNodes:(NSArray *)nodes;

// ========================================
// Represented object
- (BrowserNodeData *) representedObject;
- (void) setRepresentedObject:(BrowserNodeData *)representedObject;

@end
