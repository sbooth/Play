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
#import "BrowserNodeData.h"

@interface BrowserNode (Private)
- (void) removeChildrenIdenticalTo:(NSArray *)children;
@end

@implementation BrowserNode

- (id) init
{
	if((self = [super init])) {
		_children = [[NSMutableArray alloc] init];
		return self;
	}
	return nil;
}

- (id) initWithParent:(BrowserNode *)parent
{
	NSParameterAssert(nil != parent);
	
	if((self = [self init])) {
		[parent addChild:self];
		return self;
	}
	return nil;
}

- (id) initWithRepresentedObject:(BrowserNodeData *)representedObject
{
	NSParameterAssert(nil != representedObject);
	
	if((self = [self init])) {
		[self setRepresentedObject:representedObject];
		return self;
	}
	return nil;
}

- (id) initWithParent:(BrowserNode *)parent representedObject:(BrowserNodeData *)representedObject
{
	NSParameterAssert(nil != parent);
	NSParameterAssert(nil != representedObject);
	
	if((self = [self init])) {
		[parent addChild:self];
		[self setRepresentedObject:representedObject];
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_children release], _children = nil;
	[_representedObject release], _representedObject = nil;

	[super dealloc];
}

#pragma mark Parent Management

- (BrowserNode *)		parent								{ return _parent; }
- (void)				setParent:(BrowserNode *)parent		{ _parent = parent; }

- (void)				removeFromParent					{ [[self parent] removeChild:self]; }

#pragma mark Child Management

- (NSArray *)			children							{ return _children; }
- (unsigned)			countOfChildren						{ return [_children count]; }

- (BrowserNode *)		firstChild							{ return [[self children] objectAtIndex:0]; }
- (BrowserNode *)		lastChild							{ return [[self children] lastObject]; }

- (BrowserNode *)		childAtIndex:(unsigned)index		{ return [[self children] objectAtIndex:index]; }
- (unsigned)			indexOfChild:(BrowserNode *)child	{ return [[self children] indexOfObject:child]; }

- (void) addChild:(BrowserNode *)child
{
	NSParameterAssert(nil != child);
	
	[_children addObject:child];
	[child setParent:self];
}

- (void) insertChild:(BrowserNode *)child atIndex:(unsigned)index
{
	NSParameterAssert(nil != child);
	
	[_children insertObject:child atIndex:index];
	[child setParent:self];
}

- (void) insertChildren:(NSArray *)children atIndexes:(NSIndexSet *)indexes
{
	NSParameterAssert(nil != children);
	NSParameterAssert(0 != [children count]);
	
	[_children insertObjects:children atIndexes:indexes];
	[_children makeObjectsPerformSelector:@selector(setParent:) withObject:self];
}

- (void) removeChild:(BrowserNode *)child
{
	NSParameterAssert(nil != child);
	
	unsigned index = [self indexOfChild:child];
	if(NSNotFound != index) {
		[self removeChildrenIdenticalTo:[NSArray arrayWithObject:[self childAtIndex:index]]];
	}
}

- (void) sortChildren
{
	[_children sortUsingSelector:@selector(compare:)];
}

- (void) recursivelySortChildren
{
	[_children sortUsingSelector:@selector(compare:)];
	[_children makeObjectsPerformSelector: @selector(recursivelySortChildren)];
}

#pragma mark Relationship Management

- (BOOL) isDescendantOfNode:(BrowserNode *)node
{
	NSParameterAssert(nil != node);
	
	BrowserNode *parent = self;
	
	while(nil != parent) {
		if(parent == node) {
			return YES;	
		}
		parent = [parent parent];
	}
	return NO;
}

- (BOOL) isDescendantOfNodes:(NSArray *)nodes
{
	NSParameterAssert(nil != nodes);
	
	NSEnumerator	*enumerator		= [nodes objectEnumerator];
	BrowserNode	*node			= nil;
	
	while((node = [enumerator nextObject])) {
		if([self isDescendantOfNode:node]) {
			return YES;	
		}
	}
	return NO;
}

- (NSComparisonResult) compare:(BrowserNode *)node
{
	return [[self representedObject] compare:[node representedObject]];
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"<%@>: %@", [self class], [self representedObject]];
}

#pragma mark Represented object

- (BrowserNodeData *) representedObject
{
	return _representedObject;
}

- (void) setRepresentedObject:(BrowserNodeData *)representedObject
{
	[_representedObject setNode:nil];
	[_representedObject release];
	_representedObject = [representedObject retain];
	[_representedObject setNode:self];
}

@end

@implementation BrowserNode (Private)

- (void) removeChildrenIdenticalTo:(NSArray *)children
{
	NSParameterAssert(nil != children);
	
	NSEnumerator	*childEnumerator	= [children objectEnumerator];
	BrowserNode	*child				= nil;

	[children makeObjectsPerformSelector:@selector(setParent:) withObject:nil];

	while((child = [childEnumerator nextObject])) {
		[_children removeObjectIdenticalTo:child];
	}
}

@end
