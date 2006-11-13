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

#import "DynamicPlaylistCriterion.h"
#import "DynamicPlaylistInformationSheet.h"

@implementation DynamicPlaylistCriterion

- (id) init
{
	if((self = [super init])) {
		BOOL			result;
		
		_predicateType	= NSEqualToPredicateOperatorType;
		
		result			= [NSBundle loadNibNamed:@"DynamicPlaylistCriterion" owner:self];
		if(NO == result) {
			NSLog(@"Missing resource: \"DynamicPlaylistCriterion.nib\".");
			[self release];
			return nil;
		}
		
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	[_keyPath release],			_keyPath = nil;
	[_searchTerm release],		_searchTerm = nil;
	
	[super dealloc];
}

- (NSView *) view
{
	return _stringCriterionViewPrototype;
}

- (NSString *) keyPath
{
	return _keyPath;
}

- (void) setKeyPath:(NSString *)keyPath
{
	[_keyPath release];
	_keyPath = [keyPath retain];
}

- (NSPredicateOperatorType) predicateType
{
	return _predicateType;
}

- (void) setPredicateType:(NSPredicateOperatorType)predicateType
{
	_predicateType = predicateType;
}

- (id) searchTerm
{
	return _searchTerm;
}

- (void) setSearchTerm:(id)searchTerm
{
	[_searchTerm release];
	_searchTerm = [searchTerm retain];
}

- (NSPredicate *) predicate
{
	NSExpression		*left, *right;
	
	if(nil == [self keyPath]) {
		return [NSPredicate predicateWithValue:YES];
	}
	
	left				= [NSExpression expressionForKeyPath:[self keyPath]];
	right				= [NSExpression expressionForConstantValue:[self searchTerm]];
	
	return [NSComparisonPredicate predicateWithLeftExpression:left
											  rightExpression:right
													 modifier:NSDirectPredicateModifier
														 type:[self predicateType]
													  options:NSCaseInsensitivePredicateOption/*NSDiacriticInsensitivePredicateOption*/];
	
}

@end
