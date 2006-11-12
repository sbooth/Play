/*
 *  $Id$
 *
 *  Copyright (C) 2006 Stephen F. Booth <me@sbooth.org>
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

#import "DynamicPlaylistInformationSheet.h"
#import "LibraryDocument.h"

@interface DynamicPlaylistInformationSheet (Private)

- (NSMutableArray *)	criterionViews;

@end

@implementation DynamicPlaylistInformationSheet

+ (void) initialize
{
	[self setKeys:[NSArray arrayWithObject:@"owner"] triggerChangeNotificationsForDependentKey:@"managedObjectContext"];
}

- (id) initWithOwner:(NSPersistentDocument *)owner
{
	if((self = [super init])) {
		BOOL		result;

		_owner		= [owner retain];

		result		= [NSBundle loadNibNamed:@"DynamicPlaylistInformationSheet" owner:self];
		if(NO == result) {
			NSLog(@"Missing resource: \"DynamicPlaylistInformationSheet.nib\".");
			[self release];
			return nil;
		}
				
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	[_owner release],					_owner = nil;
	[_criterionViews release],			_criterionViews = nil;
	
	[super dealloc];
}

- (void) awakeFromNib
{
	[self addCriterion:self];
}

- (NSWindow *) sheet
{
	return [[_sheet retain] autorelease];
}

- (NSManagedObjectContext *) managedObjectContext
{
	return [_owner managedObjectContext];
}

- (IBAction) ok:(id)sender
{
    [[NSApplication sharedApplication] endSheet:[self sheet] returnCode:NSOKButton];
}

- (IBAction) cancel:(id)sender
{
    [[NSApplication sharedApplication] endSheet:[self sheet] returnCode:NSCancelButton];
}

- (IBAction) undo:(id)sender
{
	[[[self managedObjectContext] undoManager] undo];
}

- (IBAction) redo:(id)sender
{
	[[[self managedObjectContext] undoManager] redo];
}

- (BOOL) validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
	if([anItem action] == @selector(undo:)) {
		return [[[self managedObjectContext] undoManager] canUndo];
	}
	else if([anItem action] == @selector(redo:)) {
		return [[[self managedObjectContext] undoManager] canRedo];
	}
	
	return YES;
}

- (IBAction) addCriterion:(id)sender
{
	NSData		*tempData;
	NSView		*criterionView;
	float		viewHeight;

	// Since NSView doesn't implement NSCopying, hack around it
//	criterionView	= [_stringCriterionViewPrototype copy];
	tempData		= [NSKeyedArchiver archivedDataWithRootObject:_stringCriterionViewPrototype];
	criterionView	= [NSKeyedUnarchiver unarchiveObjectWithData:tempData];
	
	viewHeight		= [criterionView bounds].size.height;
	
	if(0 < [[self criterionViews] count]) {
		NSRect			windowFrame;
		NSEnumerator	*enumerator;
		NSView			*subview;
		NSRect			subviewFrame;

		windowFrame					= [_sheet frame];
		windowFrame.size.height		+= viewHeight;
		windowFrame.origin.y		-= viewHeight;
		enumerator					= [[_criteriaView subviews] objectEnumerator];
		
		while((subview = [enumerator nextObject])) {
			subviewFrame			= [subview frame];
			subviewFrame.origin.y	+= viewHeight;

			[subview setFrame:subviewFrame];
		}
		
		[_sheet setFrame:windowFrame display:YES animate:YES];
	}

	[[self criterionViews] addObject:criterionView];
	[_criteriaView addSubview:criterionView];

	[_removeCriterionButton setEnabled:(1 < [[self criterionViews] count])];
	[_predicateTypePopUpButton setEnabled:(1 < [[self criterionViews] count])];
}

- (IBAction) removeCriterion:(id)sender
{
	NSView		*criterionView;
	float		viewHeight;

	if(0 == [[self criterionViews] count]) {
		return;
	}
	
	criterionView	= [[self criterionViews] lastObject];
	viewHeight		= [criterionView bounds].size.height;
	
	[[self criterionViews] removeLastObject];
	[criterionView removeFromSuperview];
	
	if(0 < [[self criterionViews] count]) {
		NSRect			windowFrame;
		NSEnumerator	*enumerator;
		NSView			*subview;
		NSRect			subviewFrame;
		
		windowFrame					= [_sheet frame];
		windowFrame.size.height		-= viewHeight;
		windowFrame.origin.y		+= viewHeight;
		enumerator					= [[_criteriaView subviews] objectEnumerator];
		
		while((subview = [enumerator nextObject])) {
			subviewFrame			= [subview frame];
			subviewFrame.origin.y	-= viewHeight;
			
			[subview setFrame:subviewFrame];
		}

		[_sheet setFrame:windowFrame display:YES animate:YES];
	}

	[_removeCriterionButton setEnabled:(1 < [[self criterionViews] count])];
	[_predicateTypePopUpButton setEnabled:(1 < [[self criterionViews] count])];
}

@end

@implementation DynamicPlaylistInformationSheet (Private)

- (NSMutableArray *) criterionViews
{
	if(nil == _criterionViews) {
		_criterionViews = [[NSMutableArray alloc] init];
	}

	return _criterionViews;
}

@end
