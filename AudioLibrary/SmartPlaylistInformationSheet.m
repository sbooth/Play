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

#import "SmartPlaylistInformationSheet.h"
#import "SmartPlaylistCriterion.h"
#import "SmartPlaylist.h"

@interface SmartPlaylistInformationSheet (Private)
- (NSMutableArray *) criteria;
@end

@implementation SmartPlaylistInformationSheet

- (id) init
{
	if((self = [super init])) {
		BOOL result = [NSBundle loadNibNamed:@"SmartPlaylistInformationSheet" owner:self];
		if(NO == result) {
			NSLog(@"Missing resource: \"SmartPlaylistInformationSheet.nib\".");
			[self release];
			return nil;
		}

		_predicateType	= NSOrPredicateType;
	}
	return self;
}

- (void) dealloc
{
	[_playlist release], _playlist = nil;
	[_criteria release], _criteria = nil;
	
	[super dealloc];
}

- (void) awakeFromNib
{
	[_removeCriterionButton setEnabled:(1 < [[self criteria] count])];
	[_predicateTypePopUpButton setEnabled:(1 < [[self criteria] count])];

	// Set formatters
	
	// Generic numbers
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	
	[_playCountTextField setFormatter:numberFormatter];
	[numberFormatter release];
	
	// Dates
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateStyle:NSDateFormatterFullStyle];
	[dateFormatter setTimeStyle:NSDateFormatterFullStyle];
	
	[_dateCreatedTextField setFormatter:dateFormatter];
	[_firstPlayedTextField setFormatter:dateFormatter];
	[_lastPlayedTextField setFormatter:dateFormatter];
	[dateFormatter release];
}

- (NSWindow *) sheet
{
	return [[_sheet retain] autorelease];
}

- (IBAction) ok:(id)sender
{
	NSArray *predicates = [[self criteria] valueForKey:@"predicate"];
	
	if(0 < [predicates count]) {
		NSCompoundPredicate *playlistPredicate = [[NSCompoundPredicate alloc] initWithType:[self predicateType] subpredicates:predicates];
		[[self smartPlaylist] setValue:playlistPredicate forKey:SmartPlaylistPredicateKey];
	}
	else
		[[self smartPlaylist] setValue:[NSPredicate predicateWithValue:YES] forKey:SmartPlaylistPredicateKey];
	
    [[NSApplication sharedApplication] endSheet:[self sheet] returnCode:NSOKButton];
}

- (IBAction) cancel:(id)sender
{
    [[NSApplication sharedApplication] endSheet:[self sheet] returnCode:NSCancelButton];
}

- (SmartPlaylist *) smartPlaylist
{
	return [[_playlist retain] autorelease];
}

- (void) setSmartPlaylist:(SmartPlaylist *)playlist
{
	[_playlist release];
	_playlist = [playlist retain];
	
	NSComparisonPredicate		*comparisonPredicate;
	NSExpression				*left, *right;
	SmartPlaylistCriterion		*criterion;

	NSPredicate *playlistPredicate = [[self smartPlaylist] valueForKey:SmartPlaylistPredicateKey];
	
	if(nil != playlistPredicate) {
		if([playlistPredicate isKindOfClass:[NSCompoundPredicate class]]) {
			
			NSCompoundPredicate *compoundPredicate		= (NSCompoundPredicate *)playlistPredicate;
			
			[self setPredicateType:[compoundPredicate compoundPredicateType]];
			
			for(playlistPredicate in [compoundPredicate subpredicates]) {
				criterion = [[SmartPlaylistCriterion alloc] init];
				
				if([playlistPredicate isKindOfClass:[NSComparisonPredicate class]]) {
					comparisonPredicate		= (NSComparisonPredicate *)playlistPredicate;
					left					= [comparisonPredicate leftExpression];
					right					= [comparisonPredicate rightExpression];
					
					// IN is reversed
					if(NSInPredicateOperatorType == [comparisonPredicate predicateOperatorType]) {
						[criterion setKeyPath:[right keyPath]];
						[criterion setPredicateType:[comparisonPredicate predicateOperatorType]];
						[criterion setSearchTerm:[left constantValue]];					
					}
					else {
						[criterion setKeyPath:[left keyPath]];
						[criterion setPredicateType:[comparisonPredicate predicateOperatorType]];
						[criterion setSearchTerm:[right constantValue]];					
					}
				}
				
				[self addCriterion:[criterion autorelease]];
			}
		}
		else if([playlistPredicate isKindOfClass:[NSComparisonPredicate class]]) {
			criterion = [[SmartPlaylistCriterion alloc] init];
			
			comparisonPredicate		= (NSComparisonPredicate *)playlistPredicate;
			left					= [comparisonPredicate leftExpression];
			right					= [comparisonPredicate rightExpression];
			
			// IN is reversed
			if(NSInPredicateOperatorType == [comparisonPredicate predicateOperatorType]) {
				[criterion setKeyPath:[right keyPath]];
				[criterion setPredicateType:[comparisonPredicate predicateOperatorType]];
				[criterion setSearchTerm:[left constantValue]];					
			}
			else {
				[criterion setKeyPath:[left keyPath]];
				[criterion setPredicateType:[comparisonPredicate predicateOperatorType]];
				[criterion setSearchTerm:[right constantValue]];					
			}
			
			[self addCriterion:[criterion autorelease]];
		}		
	}
}

/*- (NSUndoManager *) windowWillReturnUndoManager:(NSWindow *)sender
{
	return [_owner undoManager];
}

- (IBAction) undo:(id)sender
{
	[[_owner undoManager] undo];
}

- (IBAction) redo:(id)sender
{
	[[_owner undoManager] redo];
}

- (BOOL) validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
	if([anItem action] == @selector(undo:)) {
		return [[_owner undoManager] canUndo];
	}
	else if([anItem action] == @selector(redo:)) {
		return [[_owner undoManager] canRedo];
	}
	
	return YES;
}*/

- (IBAction) add:(id)sender
{
	SmartPlaylistCriterion *criterion = [[SmartPlaylistCriterion alloc] init];
	
	[self addCriterion:[criterion autorelease]];
}

- (IBAction) remove:(id)sender
{
	[self removeCriterion:[[self criteria] lastObject]];
}

- (void) addCriterion:(SmartPlaylistCriterion *)criterion
{
	NSParameterAssert(nil != criterion);
	
	NSView	*criterionView	= [criterion view];	
	float	viewHeight		= [criterionView bounds].size.height;
	
	if(0 < [[self criteria] count]) {
		NSRect			windowFrame;
		NSRect			subviewFrame;
		
		windowFrame					= [_sheet frame];
		windowFrame.size.height		+= viewHeight;
		windowFrame.origin.y		-= viewHeight;
		
		for(NSView *subview in [_criteriaView subviews]) {
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

- (void) removeCriterion:(SmartPlaylistCriterion *)criterion
{
	NSParameterAssert(nil != criterion);
	
	if(0 == [[self criteria] count] || NO == [[self criteria] containsObject:criterion])
		return;
	
	NSView	*criterionView	= [criterion view];
	float	viewHeight		= [criterionView bounds].size.height;
	
	[[self criteria] removeObject:criterion];
	[criterionView removeFromSuperview];
	
	if(0 < [[self criteria] count]) {
		NSRect			windowFrame;
		NSRect			subviewFrame;
		
		windowFrame					= [_sheet frame];
		windowFrame.size.height		-= viewHeight;
		windowFrame.origin.y		+= viewHeight;
		
		for(NSView *subview in [_criteriaView subviews]) {
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

@implementation SmartPlaylistInformationSheet (Private)

- (NSMutableArray *) criteria
{
	if(nil == _criteria)
		_criteria = [[NSMutableArray alloc] init];

	return [[_criteria retain] autorelease];
}

@end
