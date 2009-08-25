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

#import "BrowserNode.h"

@implementation BrowserNode

+ (void) initialize
{
	[self exposeBinding:@"name"];
	[self exposeBinding:@"icon"];

	[self exposeBinding:@"parent"];
	[self exposeBinding:@"children"];
	
	[self setKeys:[NSArray arrayWithObject:@"children"] triggerChangeNotificationsForDependentKey:@"countOfChildren"];
	[self setKeys:[NSArray arrayWithObject:@"children"] triggerChangeNotificationsForDependentKey:@"isLeaf"];
}

#pragma mark Creation shortcuts

+ (id) nodeWithName:(NSString *)name
{
	BrowserNode *result = [[BrowserNode alloc] initWithName:name];
	return [result autorelease];
}

+ (id) nodeWithIcon:(NSImage *)icon
{
	BrowserNode *result = [[BrowserNode alloc] init];
	[result setIcon:icon];
	return [result autorelease];
}

+ (id) nodeWithName:(NSString *)name icon:(NSImage *)icon
{
	BrowserNode *result = [[BrowserNode alloc] initWithName:name];
	[result setIcon:icon];
	return [result autorelease];
}

- (id) init
{
	if((self = [super init]))
		_children = [[NSMutableArray alloc] init];
	return self;
}

- (id) initWithName:(NSString *)name
{
	NSParameterAssert(nil != name);
	
	if((self = [super init])) {
		_children = [[NSMutableArray alloc] init];
		_name = [name retain];
	}
	return self;
}

- (void) dealloc
{
	[self removeAllChildren];
	
	[_children release], _children = nil;
	
	[_name release], _name = nil;
	[_icon release], _icon = nil;
	
	[super dealloc];
}

- (NSComparisonResult) compare:(BrowserNode *)node
{
	return [[self name] compare:[node name]];
}

#pragma mark View properties

- (NSString *) name
{
	return [[_name retain] autorelease];
}

- (void) setName:(NSString *)name
{
	[_name release];
	_name = [name retain];
}

- (BOOL) nameIsEditable
{
	return NO;
}

- (NSImage *) icon
{
	return [[_icon retain] autorelease];
}

- (void) setIcon:(NSImage *)icon
{
	[_icon release];
	_icon = [icon retain];
}

#pragma mark Relationship traversal

- (BrowserNode *) root
{
	BrowserNode *node = [self parent];
	while(nil != node)
		node = [node parent];
	return node;
}

- (BrowserNode *) parent
{
	return [[_parent retain] autorelease];
}

- (unsigned) childCount
{
	return [_children count];
}

- (BrowserNode *) firstChild
{
	return (0 != [_children count] ? [_children objectAtIndex:0] : nil);
}

- (BrowserNode *) lastChild
{
	return [_children lastObject];
}

- (BrowserNode *) childAtIndex:(unsigned)index
{
	return [_children objectAtIndex:index];
}

- (unsigned) indexOfChild:(BrowserNode *)child
{
	NSParameterAssert(nil != child);

	return [_children indexOfObject:child];
}

- (unsigned) indexOfChildIdenticalTo:(BrowserNode *)child
{
	NSParameterAssert(nil != child);
	
	return [_children indexOfObjectIdenticalTo:child];
}

- (BrowserNode *) findChildNamed:(NSString *)name
{
	// Breadth-first search
	BrowserNode *match = nil;
	
	for(BrowserNode *child in _children) {
		if([[child name] isEqualToString:name]) {
			match = child;
			break;
		}
	}
	
	if(nil == match) {
		for(BrowserNode *child in _children) {
			match = [child findChildNamed:name];
			if(match)
				break;
		}
	}
	
	return match;
}

- (BrowserNode *) nextSibling
{
	unsigned myIndex = [[self parent] indexOfChild:self];
	if(myIndex + 1 < [[self parent] childCount])
		return [[self parent] childAtIndex:myIndex + 1];
	return nil;
}

- (BrowserNode *) previousSibling
{
	unsigned myIndex = [[self parent] indexOfChild:self];
	if(0 < myIndex - 1 && myIndex - 1 > [[self parent] childCount])
		return [[self parent] childAtIndex:myIndex - 1];
	return nil;
}

- (BOOL) isLeaf
{
	return (0 == [_children count]);
}

#pragma mark Relationship management

- (void) setParent:(BrowserNode *)parent
{
	_parent = parent; // Weak reference
}

- (void) addChild:(BrowserNode *)child
{
	[self insertObject:child inChildrenAtIndex:[_children count]];
}

- (void) insertChild:(BrowserNode *)child atIndex:(unsigned)index
{
	[self insertObject:child inChildrenAtIndex:index];
}

- (void) removeChild:(BrowserNode *)child
{
	[self removeObjectFromChildrenAtIndex:[self indexOfChild:child]];
}

- (void) removeChildAtIndex:(unsigned)index
{
	[self removeObjectFromChildrenAtIndex:index];
}

- (void) removeChildrenAtIndexes:(NSIndexSet *)indexes
{
	NSParameterAssert(nil != indexes);
	
	NSArray *orphans = [_children objectsAtIndexes:indexes];
	[orphans makeObjectsPerformSelector:@selector(setParent:) withObject:nil];
	[self willChangeValueForKey:@"children"];
	[_children removeObjectsAtIndexes:indexes];
	[self didChangeValueForKey:@"children"];
}

- (void) removeAllChildren
{
	[_children makeObjectsPerformSelector:@selector(setParent:) withObject:nil];
	[self willChangeValueForKey:@"children"];
	[_children removeAllObjects];
	[self didChangeValueForKey:@"children"];
}

- (void) sortChildren
{
	[self willChangeValueForKey:@"children"];
	[_children sortUsingSelector:@selector(compare:)];
	[self didChangeValueForKey:@"children"];
}

- (void) sortChildrenRecursively
{
	[self willChangeValueForKey:@"children"];
	[_children sortUsingSelector:@selector(compare:)];
	[_children makeObjectsPerformSelector:@selector(sortChildrenRecursivelyUsingSelector:)];
	[self didChangeValueForKey:@"children"];
}

- (unsigned) countOfChildren
{
	return [_children count];
}

- (BrowserNode *) objectInChildrenAtIndex:(unsigned)index
{
	return [_children objectAtIndex:index];
}

- (void) getChildren:(id *)buffer range:(NSRange)range
{
	return [_children getObjects:buffer range:range];
}

- (void) insertObject:(BrowserNode *)object inChildrenAtIndex:(unsigned)index
{
	NSParameterAssert(nil != object);

	[object setParent:self];
	[_children insertObject:object atIndex:index];
}

- (void) removeObjectFromChildrenAtIndex:(unsigned)index
{
	[[_children objectAtIndex:index] setParent:nil];
	[_children removeObjectAtIndex:index];
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"%@: %@", [self name], _children];
}

@end
