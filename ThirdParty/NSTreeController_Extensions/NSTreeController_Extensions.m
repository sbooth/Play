/*
 
 File: NSTreeController_Extensions.h
 
 Abstract: Implementation for useful extensions to NSIndexPath and
 NSTreeController for working with the internal objects and walking
 around the tree. This implementation hides the opaque things from
 the rest of our application.
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Computer, Inc. ("Apple") in consideration of your agreement to the
 following terms, and your use, installation, modification or
 redistribution of this Apple software constitutes acceptance of these
 terms.  If you do not agree with these terms, please do not use,
 install, modify or redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software. 
 Neither the name, trademarks, service marks or logos of Apple Computer,
 Inc. may be used to endorse or promote products derived from the Apple
 Software without specific prior written permission from Apple.  Except
 as expressly stated in this notice, no other rights or licenses, express
 or implied, are granted by Apple herein, including but not limited to
 any patent rights that may be infringed by your derivative works or by
 other works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright © 2005 Apple Computer, Inc., All Rights Reserved
 
 */

#import "NSTreeController_Extensions.h"


@interface _NSControllerTreeProxy : NSObject
{
	// opaque
}
- (unsigned int)count;
- (id)nodeAtIndexPath:(id)fp8;
- (id)objectAtIndexPath:(id)fp8;
@end

@interface _NSArrayControllerTreeNode : NSObject
{
	// opaque
}
- (unsigned int)count;
- (id)observedObject;
- (id)parentNode;
- (id)nodeAtIndexPath:(id)fp8;
- (id)subnodeAtIndex:(unsigned int)fp8;
- (BOOL)isLeaf;
- (id)indexPath;
- (id)objectAtIndexPath:(id)fp8;
@end

@interface _NSArrayControllerTreeNode (MyExtensions)
// depth-first search of the tree; returns nil (or empty array) if object(s) not found
- (NSIndexPath *)arrangedIndexPathForObject:(id)object startingAt:(NSIndexPath *)prefix;
- (NSArray *)childrenByDepthFirstSearch;
- (NSArray *)siblingIndexPaths;
@end


@implementation _NSArrayControllerTreeNode (MyExtensions)

- (NSIndexPath *)arrangedIndexPathForObject:(id)object startingAt:(NSIndexPath *)prefix;
{
	unsigned int i;
	
	for ( i = 0; i < [self count]; ++i ) {
		_NSArrayControllerTreeNode	*node = [self subnodeAtIndex: i];
		NSIndexPath					*path = prefix ? [prefix indexPathByAddingIndex: i]
												   : [NSIndexPath indexPathWithIndex: i];
		
		if ( [node observedObject] == object )
			return path;
		else
			if ( (path = [node arrangedIndexPathForObject: object startingAt: path]) )
				return path;
	}
	
	return nil;
}

- (NSArray *)siblingIndexPaths;
{
	_NSArrayControllerTreeNode *parent = [self parentNode];
	
	if ( parent ) {
		unsigned int    i, count = [parent count];
		NSMutableArray *result = [NSMutableArray arrayWithCapacity: count];

		for ( i = 0; i < count; ++i )
			[result addObject: [[parent subnodeAtIndex: i] indexPath]];
		
		return result;
	}
	else
		return nil;
}


- (NSArray *)childrenByDepthFirstSearch;
{
	NSMutableArray *result = [NSMutableArray arrayWithCapacity: 3];
	unsigned int	i;
	
	for ( i = 0; i < [self count]; ++i ) {
		_NSArrayControllerTreeNode	*node = [self subnodeAtIndex: i];
		
		if ( node ) {
			[result addObject: node];
			[result addObjectsFromArray: [node childrenByDepthFirstSearch]];			
		}
	}
	
	return result;	
}

@end

@implementation NSIndexPath (MyExtensions)

- (unsigned int)lastIndex;
{
	return [self indexAtPosition: [self length] - 1];
}

- (BOOL)isAncestorOfIndexPath:(NSIndexPath *)other; // i.e., other descends from receiver
{
	unsigned int l1 = [self length], l2 = [other length];
	
	if ( l1 < l2 ) {
		unsigned int elems1[l1], elems2[l2], i;
		
		[self getIndexes: elems1];
		[other getIndexes: elems2];
		
		for ( i = 0; i < l1; ++i )
			if ( elems1[i] != elems2[i] )
				return NO;
		
		return YES;
	}
	
	return NO;
}

- (BOOL)isSiblingOfIndexPath:(NSIndexPath *)other; // i.e., other has same parent as receiver
{
	unsigned int l1 = [self length], l2 = [other length];
	
	if ( l1 == l2 ) {
		unsigned int elems1[l1], elems2[l2], i;
		
		[self getIndexes: elems1];
		[other getIndexes: elems2];
		
		for ( i = 0; i < l1 - 1; ++i )
			if ( elems1[i] != elems2[i] )
				return NO;
		
		return YES;
	}
	
	return NO;
}

- (NSIndexPath *)firstCommonAncestorWithIndexPath:(NSIndexPath *)other;
{
	unsigned int l1 = [self length], l2 = [other length];
	
	if ( l1 && l2 ) {
		unsigned int elems1[l1], elems2[l2], i, min = ( l1 < l2 ) ? l1-1 : l2-1;
		
		[self getIndexes: elems1];
		[other getIndexes: elems2];
		
		for ( i = 0; i < min; ++i )
			if ( elems1[i] != elems2[i] )
				break;
		
		return i ? [NSIndexPath indexPathWithIndexes: elems1 length: i] : nil;
	}
	
	return nil;
}

+ (NSIndexPath *)firstCommonAncestorAmongIndexPaths:(NSArray *)paths;
{
	if ( [paths count] < 1 ) return nil;
	
	NSEnumerator *pathEnumerator = [paths objectEnumerator];
	NSIndexPath  *path1 = [pathEnumerator nextObject], *path, *result = [path1 indexPathByRemovingLastIndex];
	
	while ( (path = [pathEnumerator nextObject]) ) {
		NSIndexPath *candidate = [path firstCommonAncestorWithIndexPath: path1];
		
		if ( !candidate ) return nil;
		
		if ( [candidate length] < [result length] ) result = candidate;
	}
	
	return result;
}

@end

@implementation NSTreeController (MyExtensions)

- (_NSArrayControllerTreeNode *)arrangedRoot
{
	return [[[self arrangedObjects] nodeAtIndexPath: [NSIndexPath indexPathWithIndex: 0]] parentNode];
}

- (id)objectAtArrangedIndexPath:(NSIndexPath *)path;
{
	return [[self arrangedObjects] objectAtIndexPath: path];
}

- (NSArray *)siblingsAtArrangedIndexPath:(NSIndexPath *)path;
{
	NSArray	 *siblingPaths = [[[self arrangedObjects] nodeAtIndexPath: path] siblingIndexPaths];
	
	if ( siblingPaths ) {
		unsigned int    i, count = [siblingPaths count];
		NSMutableArray *result = [NSMutableArray arrayWithCapacity: count];

		for ( i = 0; i < count; ++i )
			[result addObject: [self objectAtArrangedIndexPath: [siblingPaths objectAtIndex: i]]];
		
		return result;
	}
	else
		return nil;
}

// depth-first search of the tree; returns nil if object isn't found

- (NSIndexPath *)arrangedIndexPathForObject:(id)object startingAt:(NSIndexPath *)parent;
{
	_NSArrayControllerTreeNode *node = parent ? [[self arrangedObjects] nodeAtIndexPath: parent] : [self arrangedRoot];
	return [node arrangedIndexPathForObject: object startingAt: parent];
}

- (NSIndexPath *)arrangedIndexPathForObject:(id)object;
{
	return [self arrangedIndexPathForObject: object startingAt: nil];
}

+ (id)objectForOutlineItem:(id)item;
{
	_NSArrayControllerTreeNode *node = (_NSArrayControllerTreeNode *)item;
	
	return [node observedObject];
}

+ (NSArray *)objectsForOutlineItems:(NSArray *)items;
{
	NSMutableArray	*selectedObjects = [NSMutableArray arrayWithCapacity: [items count]];
	NSEnumerator	*enumerator = [items objectEnumerator];
	
	_NSArrayControllerTreeNode *node;
	
	while ( (node = [enumerator nextObject]) )
		[selectedObjects addObject: [node observedObject]];
	
	return selectedObjects;
}

- (id)outlineItemForObject:(id)object;
{
	return [self outlineItemForArrangedIndexPath: [self arrangedIndexPathForObject: object]];
}

- (NSArray *)outlineItemsForObjects:(NSArray *)objects;
{
	NSMutableArray	*outlineItems = [NSMutableArray arrayWithCapacity: [objects count]];
	NSEnumerator	*enumerator = [objects objectEnumerator];
	NSIndexPath		*object;
	
	while ( (object = [enumerator nextObject]) )
		[outlineItems addObject: [self outlineItemForArrangedIndexPath: [self arrangedIndexPathForObject: object]]];
	
	return outlineItems;	
}

- (id)outlineItemForArrangedIndexPath:(NSIndexPath *)path;
{
	return [[self arrangedObjects] nodeAtIndexPath: path];
}

+ (NSIndexPath *)arrangedIndexPathForOutlineItem:(id)item;
{
	return [(_NSArrayControllerTreeNode *)item indexPath];
}

- (NSArray *)outlineItemsForArrangedIndexPaths:(NSArray *)paths;
{
	NSMutableArray	*outlineItems = [NSMutableArray arrayWithCapacity: [paths count]];
	NSEnumerator	*enumerator = [paths objectEnumerator];
	NSIndexPath		*path;
	
	while ( (path = [enumerator nextObject]) )
		[outlineItems addObject: [[self arrangedObjects] nodeAtIndexPath: path]];
	
	return outlineItems;	
}

- (NSArray *)childOutlineItemsByDepthFirstSearchUnderItem:(id)item;
{
	return [(_NSArrayControllerTreeNode *)item childrenByDepthFirstSearch];
}

- (NSArray *)childObjectsByDepthFirstSearchStartingAt:(NSIndexPath *)parent
{
	_NSArrayControllerTreeNode	*node = parent ? [[self arrangedObjects] nodeAtIndexPath: parent] : [self arrangedRoot];
	NSArray						*items = [node childrenByDepthFirstSearch];
	
	if ( items ) {
		NSMutableArray	*result = [NSMutableArray arrayWithCapacity: [items count]];
		NSEnumerator	*enumerator = [items objectEnumerator];
		id				 item;
		
		while ( (item = [enumerator nextObject]) )
			[result addObject: [item observedObject]];
		
		return result;
	}
	
	return nil;
}

@end
