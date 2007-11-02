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
// A node in the browser
// Semantics: Parents retain their children, and children maintain
// a weak reference to their parent
// KVC-compliant for "name", "icon", "children", and "parent"
// ========================================
@interface BrowserNode : NSObject
{
	@protected
	NSString		*_name;
	NSImage			*_icon;
	
	BrowserNode		*_parent;
	NSMutableArray	*_children;
}

// ========================================
// Creation shortcuts
+ (id) nodeWithName:(NSString *)name;
+ (id) nodeWithIcon:(NSImage *)icon;
+ (id) nodeWithName:(NSString *)name icon:(NSImage *)icon;

// ========================================
// Designated initializer
- (id) initWithName:(NSString *)name;

// ========================================
// View properties
- (NSString *) 	name;
- (void) 		setName:(NSString *)name;
- (BOOL)		nameIsEditable;

- (NSImage *) 	icon;
- (void) 		setIcon:(NSImage *)icon;

// ========================================
// Relationship traversal
- (BrowserNode *) 	root;

- (BrowserNode *) 	parent;

- (unsigned) 		childCount;

- (BrowserNode *) 	firstChild;
- (BrowserNode *) 	lastChild;

- (BrowserNode *) 	childAtIndex:(unsigned)index;
- (unsigned) 		indexOfChild:(BrowserNode *)child;
- (unsigned) 		indexOfChildIdenticalTo:(BrowserNode *)child;

- (BrowserNode *) 	findChildNamed:(NSString *)name;

- (BrowserNode *) 	nextSibling;
- (BrowserNode *) 	previousSibling;

- (BOOL) 			isLeaf;

// ========================================
// Relationship management
- (void) setParent:(BrowserNode *)parent;

- (void) addChild:(BrowserNode *)child;
- (void) insertChild:(BrowserNode *)child atIndex:(unsigned)index;

- (void) removeChild:(BrowserNode *)child;
- (void) removeChildAtIndex:(unsigned)index;

- (void) removeChildrenAtIndexes:(NSIndexSet *)indexes;
- (void) removeAllChildren;

- (void) sortChildren;
- (void) sortChildrenRecursively;

// ========================================
// KVC Accessors
- (unsigned) 		countOfChildren;
- (BrowserNode *) 	objectInChildrenAtIndex:(unsigned)index;
- (void) 			getChildren:(id *)buffer range:(NSRange)range;

// ========================================
// KVC Mutators
- (void) insertObject:(BrowserNode *)object inChildrenAtIndex:(unsigned)index;
- (void) removeObjectFromChildrenAtIndex:(unsigned)index;

@end
