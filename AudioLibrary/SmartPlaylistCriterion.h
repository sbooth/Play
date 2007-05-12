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

@interface SmartPlaylistCriterion : NSObject
{
	// View prototypes
	IBOutlet NSView				*_integer16CriterionViewPrototype;
	IBOutlet NSView				*_integer32CriterionViewPrototype;
	IBOutlet NSView				*_integer64CriterionViewPrototype;

	IBOutlet NSView				*_decimalCriterionViewPrototype;
	IBOutlet NSView				*_doubleCriterionViewPrototype;
	IBOutlet NSView				*_floatCriterionViewPrototype;
	
	IBOutlet NSView				*_stringCriterionViewPrototype;
	
	IBOutlet NSView				*_booleanCriterionViewPrototype;
	
	IBOutlet NSView				*_dateCriterionViewPrototype;

@private
		
	NSView						*_view;

	// The type of attribute being represented
	NSAttributeType				_attributeType;

	NSString					*_keyPath;
	NSPredicateOperatorType		_predicateType;
	id							_searchTerm;
}

- (IBAction)					didSelectKeyPath:(id)sender;

- (NSView *)					view;

- (NSAttributeType)				attributeType;
- (void)						setAttributeType:(NSAttributeType)attributeType;

- (NSString *)					keyPath;
- (void)						setKeyPath:(NSString *)keyPath;

- (NSPredicateOperatorType)		predicateType;
- (void)						setPredicateType:(NSPredicateOperatorType)predicateType;

- (id)							searchTerm;
- (void)						setSearchTerm:(id)searchTerm;

- (NSPredicate *)				predicate;

@end
