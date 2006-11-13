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
#import "DynamicPlaylistCriterion.h"

@interface DynamicPlaylistInformationSheet (Private)

- (NSMutableArray *)	criteria;

@end

@implementation DynamicPlaylistInformationSheet

+ (void) initialize
{
	[self setKeys:[NSArray arrayWithObject:@"owner"] triggerChangeNotificationsForDependentKey:@"managedObjectContext"];
}

- (id) initWithOwner:(NSPersistentDocument *)owner
{
	if((self = [super init])) {
		BOOL			result;

		_owner			= [owner retain];
		_predicateType	= NSOrPredicateType;

		result			= [NSBundle loadNibNamed:@"DynamicPlaylistInformationSheet" owner:self];
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
	[_owner release],				_owner = nil;
	[_criteria release],			_criteria = nil;
	
	[super dealloc];
}

- (void) awakeFromNib
{
	[_removeCriterionButton setEnabled:(1 < [[self criteria] count])];
	[_predicateTypePopUpButton setEnabled:(1 < [[self criteria] count])];
}

- (NSWindow *) sheet
{
	return [[_sheet retain] autorelease];
}

- (NSManagedObjectContext *) managedObjectContext
{
	return [_owner managedObjectContext];
}

- (void) setPlaylist:(NSManagedObject *)playlist
{
	NSPredicate				*playlistPredicate;
	
	[_playlistObjectController setContent:playlist];
	
	playlistPredicate		= [playlist valueForKey:@"predicate"];
	
	if(nil != playlistPredicate) {
		if([playlistPredicate isKindOfClass:[NSCompoundPredicate class]]) {
			NSCompoundPredicate				*compoundPredicate;
			NSComparisonPredicate			*comparisonPredicate;
			NSExpression					*left, *right;
			DynamicPlaylistCriterion		*criterion;
			NSEnumerator					*enumerator;
			
			compoundPredicate				= (NSCompoundPredicate *)playlistPredicate;
			enumerator						= [[compoundPredicate subpredicates] objectEnumerator];
			
			while((playlistPredicate = [enumerator nextObject])) {
				criterion					= [[DynamicPlaylistCriterion alloc] init];

				if([playlistPredicate isKindOfClass:[NSComparisonPredicate class]]) {
					comparisonPredicate		= (NSComparisonPredicate *)playlistPredicate;
					left					= [comparisonPredicate leftExpression];
					right					= [comparisonPredicate rightExpression];
					
					[criterion setKeyPath:[left keyPath]];
					[criterion setPredicateType:[comparisonPredicate predicateOperatorType]];
					[criterion setSearchTerm:[right constantValue]];					
				}
				
				[self addCriterion:[criterion autorelease]];
			}
		}
		
	}
}

- (IBAction) ok:(id)sender
{
	NSArray					*predicates;
	NSCompoundPredicate		*playlistPredicate;

	predicates				= [[self criteria] valueForKey:@"predicate"];
	
	if(0 < [predicates count]) {
		playlistPredicate		= [[NSCompoundPredicate alloc] initWithType:[self predicateType] subpredicates:predicates];

		[[_playlistObjectController selection] setValue:[playlistPredicate autorelease] forKey:@"predicate"];
	}
	else {
		[[_playlistObjectController selection] setValue:[NSPredicate predicateWithValue:YES] forKey:@"predicate"];
	}
	
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

- (IBAction) add:(id)sender
{
	DynamicPlaylistCriterion	*criterion		= [[DynamicPlaylistCriterion alloc] init];
	
	[self addCriterion:[criterion autorelease]];
}

- (IBAction) remove:(id)sender
{
	[self removeCriterion:[[self criteria] lastObject]];
}

- (void) addCriterion:(DynamicPlaylistCriterion *)criterion
{
	NSView				*criterionView;
	float				viewHeight;
	
	criterionView		= [criterion view];	
	viewHeight			= [criterionView bounds].size.height;
	
	if(0 < [[self criteria] count]) {
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
	
	[[self criteria] addObject:criterion];
	[_criteriaView addSubview:criterionView];
	
	[_removeCriterionButton setEnabled:(1 < [[self criteria] count])];
	[_predicateTypePopUpButton setEnabled:(1 < [[self criteria] count])];
}

- (void) removeCriterion:(DynamicPlaylistCriterion *)criterion
{
	NSView						*criterionView;
	float						viewHeight;
	
	if(0 == [[self criteria] count] || NO == [[self criteria] containsObject:criterion]) {
		return;
	}
	
	criterionView	= [criterion view];
	viewHeight		= [criterionView bounds].size.height;
	
	[[self criteria] removeObject:criterion];
	[criterionView removeFromSuperview];
	
	if(0 < [[self criteria] count]) {
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
	
	[_removeCriterionButton setEnabled:(1 < [[self criteria] count])];
	[_predicateTypePopUpButton setEnabled:(1 < [[self criteria] count])];
}

- (NSCompoundPredicateType) predicateType
{
	return _predicateType;
}

- (void) setPredicateType:(NSCompoundPredicateType)predicateType
{
	_predicateType = predicateType;
}

@end

@implementation DynamicPlaylistInformationSheet (Private)

- (NSMutableArray *) criteria
{
	if(nil == _criteria) {
		_criteria = [[NSMutableArray alloc] init];
	}

	return _criteria;
}

@end
