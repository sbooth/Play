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

enum {
	KeyPathPopupButtonTag			= 1,
	PredicateTypePopupButtonTag		= 2
};

@interface DynamicPlaylistCriterion (Private)

- (void)				setupKeyPathPopUpButton;
- (void)				setupPredicateTypePopUpButton;

- (NSAttributeType)		attributeTypeForKeyPath:(NSString *)keyPath;
- (NSString *)			displayNameForKeyPath:(NSString *)keyPath;

- (NSDictionary *)		propertiesDictionaryForKeyPath:(NSString *)keyPath;

@end

@implementation DynamicPlaylistCriterion

- (id) init
{
	if((self = [super init])) {
		BOOL			result;
		
		// Reasonable defaults
		_predicateType	= NSEqualToPredicateOperatorType;
		_attributeType	= NSStringAttributeType;

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

- (void) awakeFromNib
{
	NSPopUpButton		*popUpButton;
	NSString			*keyPath;

	[self setupKeyPathPopUpButton];
	[self setupPredicateTypePopUpButton];

	popUpButton			= [[self view] viewWithTag:KeyPathPopupButtonTag];
	keyPath				= [[[popUpButton selectedItem] representedObject] valueForKey:@"keyPath"];

	[self setKeyPath:keyPath];
}

- (IBAction) didSelectKeyPath:(id)sender
{
	NSDictionary		*representedObject		= [[sender selectedItem] representedObject];
	NSString			*keyPath				= [representedObject valueForKey:@"keyPath"];
	NSNumber			*attributeType			= [representedObject valueForKey:@"attributeType"];
	
	[self setKeyPath:keyPath];
	[self setAttributeType:[attributeType intValue]];
}

- (NSView *) view
{
	switch([self attributeType]) {
		case NSUndefinedAttributeType:		return nil;

		case NSInteger16AttributeType:		return _integer16CriterionViewPrototype;
		case NSInteger32AttributeType:		return _integer32CriterionViewPrototype;
		case NSInteger64AttributeType:		return _integer64CriterionViewPrototype;
		
		case NSDecimalAttributeType:		return _decimalCriterionViewPrototype;
		case NSDoubleAttributeType:			return _doubleCriterionViewPrototype;
		case NSFloatAttributeType:			return _floatCriterionViewPrototype;
		
		case NSStringAttributeType:			return _stringCriterionViewPrototype;
		
		case NSBooleanAttributeType:		return _booleanCriterionViewPrototype;
		
		case NSDateAttributeType:			return _dateCriterionViewPrototype;
		
		case NSBinaryDataAttributeType:		return nil;
			
		default:							return nil;
	}
}

- (NSAttributeType) attributeType
{
	return _attributeType;
}

- (void) setAttributeType:(NSAttributeType)attributeType
{
	// Silently swap out our views if a different type was selected
	if([self attributeType] != attributeType) {
		NSView				*oldView;
		NSPopUpButton		*popUpButton;

		oldView				= [self view];
		_attributeType		= attributeType;
		
		if(nil != oldView) {
			[[oldView superview] addSubview:[self view] positioned:NSWindowAbove relativeTo:oldView];
			[oldView removeFromSuperview];
		}

		// The same predicate types may not be available, so select the first one
		popUpButton			= [[self view] viewWithTag:PredicateTypePopupButtonTag];

		// Similarly, the searchTerm may not be valid either
		[self setSearchTerm:nil];

		[self setupKeyPathPopUpButton];
		[self setupPredicateTypePopUpButton];

		[popUpButton selectItemAtIndex:0];		
	}	
}

- (NSString *) keyPath
{
	return _keyPath;
}

- (void) setKeyPath:(NSString *)keyPath
{
	NSPopUpButton				*popUpButton;
	id							representedObject;
	
	[_keyPath release];
	_keyPath = [keyPath retain];
	
	// First determine the object type of the keyPath that was selected
	popUpButton					= [[self view] viewWithTag:KeyPathPopupButtonTag];
	representedObject			= [self propertiesDictionaryForKeyPath:[self keyPath]];
	
	// Update our attribute type, which could swap out the view
	[self setAttributeType:[[representedObject valueForKey:@"attributeType"] intValue]];

	// Sync the popUpButton's selection (necessary since our view could have changed)
	popUpButton					= [[self view] viewWithTag:KeyPathPopupButtonTag];
	[popUpButton selectItemWithTitle:[representedObject valueForKey:@"displayName"]];
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
	
	if(nil == [self keyPath] || nil == [self searchTerm]) {
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

- (NSString *) description
{
	return [NSString stringWithFormat:@"DynamicPlaylistCriterion: %@", [self predicate]];
}

@end

@implementation DynamicPlaylistCriterion (Private)

- (void) setupKeyPathPopUpButton
{
	NSPopUpButton				*keyPathPopUpButton;
	NSMenu						*buttonMenu;
	NSMenuItem					*menuItem;
	NSArray						*keyPaths;
	NSEnumerator				*enumerator;
	NSString					*keyPath;
	
	keyPathPopUpButton			= [[self view] viewWithTag:KeyPathPopupButtonTag];
	
	[keyPathPopUpButton removeAllItems];
	
	buttonMenu					= [keyPathPopUpButton menu];
	
	keyPaths					= [NSArray arrayWithObjects:@"metadata.title", @"metadata.artist", @"metadata.album", 
		@"metadata.composer", @"metadata.genre", @"metadata.partOfCompilation", @"metadata.date", @"-", 
		@"properties.formatName", @"properties.bitsPerChannel", 
		nil];
	enumerator					= [keyPaths objectEnumerator];
	
	while((keyPath = [enumerator nextObject])) {
		if([keyPath isEqualToString:@"-"]) {
			[buttonMenu addItem:[NSMenuItem separatorItem]];
		}
		else {
			menuItem					= [[NSMenuItem alloc] init];
			[menuItem setTitle:[self displayNameForKeyPath:keyPath]];
			[menuItem setRepresentedObject:[self propertiesDictionaryForKeyPath:keyPath]];
			[buttonMenu addItem:[menuItem autorelease]];
		}
	}
}

- (void) setupPredicateTypePopUpButton
{
	NSPopUpButton				*predicateTypePopUpButton;
	NSMenu						*buttonMenu;
	NSMenuItem					*menuItem;

	predicateTypePopUpButton	= [[self view] viewWithTag:PredicateTypePopupButtonTag];

	[predicateTypePopUpButton removeAllItems];
	
	buttonMenu					= [predicateTypePopUpButton menu];
	
	switch([self attributeType]) {
		case NSInteger16AttributeType:
		case NSInteger32AttributeType:
		case NSInteger64AttributeType:
		case NSDecimalAttributeType:
		case NSDoubleAttributeType:
		case NSFloatAttributeType:
			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"is equal to"];
			[menuItem setTag:NSEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"is not equal to"];
			[menuItem setTag:NSNotEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];

			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"is less than"];
			[menuItem setTag:NSLessThanPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];

			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"is less than or equal to"];
			[menuItem setTag:NSLessThanOrEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];

			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"is greater than"];
			[menuItem setTag:NSGreaterThanPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"is greater than or equal to"];
			[menuItem setTag:NSGreaterThanOrEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			break;
			
		case NSStringAttributeType:
			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"is"];
			[menuItem setTag:NSEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"is not"];
			[menuItem setTag:NSNotEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"contains"];
			[menuItem setTag:NSLikePredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"starts with"];
			[menuItem setTag:NSBeginsWithPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"ends with"];
			[menuItem setTag:NSEndsWithPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			break;
			
		case NSBooleanAttributeType:
			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"is"];
			[menuItem setTag:NSEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"is not"];
			[menuItem setTag:NSNotEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];

			break;
			
		case NSDateAttributeType:
			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"is"];
			[menuItem setTag:NSEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"is not"];
			[menuItem setTag:NSNotEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"is before"];
			[menuItem setTag:NSLessThanPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"is or is before"];
			[menuItem setTag:NSLessThanOrEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"is after"];
			[menuItem setTag:NSGreaterThanPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem		= [[NSMenuItem alloc] init];
			[menuItem setTitle:@"is or is after"];
			[menuItem setTag:NSGreaterThanOrEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];

			break;
			
		case NSUndefinedAttributeType:
		case NSBinaryDataAttributeType:
			// Nothing for now
			break;
	}
	
	[predicateTypePopUpButton selectItemWithTag:[self predicateType]];
}

- (NSAttributeType) attributeTypeForKeyPath:(NSString *)keyPath
{
	return [[[self propertiesDictionaryForKeyPath:keyPath] valueForKey:@"attributeType"] intValue];
}

- (NSString *) displayNameForKeyPath:(NSString *)keyPath
{
	return [[self propertiesDictionaryForKeyPath:keyPath] valueForKey:@"displayName"];
}

- (NSDictionary *) propertiesDictionaryForKeyPath:(NSString *)keyPath
{
	NSString			*displayName		= nil;
	NSAttributeType		attributeType		= NSUndefinedAttributeType;
	
	if([keyPath isEqualToString:@"metadata.title"]) {
		displayName		= @"Title";
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:@"metadata.artist"]) {
		displayName		= @"Artist";
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:@"metadata.album"]) {
		displayName		= @"Album";
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:@"metadata.composer"]) {
		displayName		= @"Composer";
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:@"metadata.genre"]) {
		displayName		= @"Genre";
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:@"metadata.date"]) {
		displayName		= @"Date";
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:@"metadata.partOfCompilation"]) {
		displayName		= @"Compilation";
		attributeType	= NSBooleanAttributeType;
	}
	else if([keyPath isEqualToString:@"properties.formatName"]) {
		displayName		= @"Format";
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:@"properties.bitsPerChannel"]) {
		displayName		= @"Sample Size";
		attributeType	= NSInteger32AttributeType;
	}
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
		keyPath,									@"keyPath",
		displayName,								@"displayName",
		[NSNumber numberWithInt:attributeType],		@"attributeType",
		nil];
}

@end
