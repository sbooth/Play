/*
 
 File: NSTreeController_Extensions.m
 
 Abstract: Implementation for useful extensions to NSIndexPath and
 NSTreeController for working with the internal objects and walking
 around the tree. We have deliberately avoided using instance vars
 or any method that starts with the underscore (_) to minimize the
 chance that this will all break one day.
 
 Definitions for Apple opaque object types courtesy of class-dump 3.0,
 which is Copyright ©1997-1998, 2000-2001, 2004 by Steve Nygard. 
 
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

#import <Cocoa/Cocoa.h>


@interface NSIndexPath (MyExtensions)

	// get us the final piece of the index path, i.e, the one that tells
	// us were this path fits among its siblings

- (unsigned int)lastIndex;

	// answer whether receiver is the ancestor (other is a descendant)

- (BOOL)isAncestorOfIndexPath:(NSIndexPath *)other;

	// answer whether receiver has same immediate parent as other

- (BOOL)isSiblingOfIndexPath:(NSIndexPath *)other;

	// find a common ancestor in the tree controller
	// return nil if no common ancestor
	// these may not be necessary

- (NSIndexPath *)firstCommonAncestorWithIndexPath:(NSIndexPath *)other;
+ (NSIndexPath *)firstCommonAncestorAmongIndexPaths:(NSArray *)otherPaths;

@end

@interface NSTreeController (MyExtensions)

	// convert between NSIndexPaths and managed objects observed by the controller
	// used internally, but might be useful if we use the "find common ancestor"
	// capability

- (id)objectAtArrangedIndexPath:(NSIndexPath *)path;
- (NSIndexPath *)arrangedIndexPathForObject:(id)object;
- (NSIndexPath *)arrangedIndexPathForObject:(id)object startingAt:(NSIndexPath *)parent;
- (NSArray *)siblingsAtArrangedIndexPath:(NSIndexPath *)path;

	// convert between NSOutlineView items and managed objects observed by the controller

+ (id)objectForOutlineItem:(id)item;
+ (NSArray *)objectsForOutlineItems:(NSArray *)items;

- (id)outlineItemForObject:(id)object;
- (NSArray *)outlineItemsForObjects:(NSArray *)objects;

	// convert between NSOutlineView items and NSIndexPaths

- (id)outlineItemForArrangedIndexPath:(NSIndexPath *)path;
- (NSArray *)outlineItemsForArrangedIndexPaths:(NSArray *)paths;

+ (NSIndexPath *)arrangedIndexPathForOutlineItem:(id)item;

	// recursively find all descendants of an outline item (return outline items
	// which can be converted to objects with objectsForOutlineItems:

- (NSArray *)childOutlineItemsByDepthFirstSearchUnderItem:(id)item;

@end
