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

#import "DynamicPlaylistCriterion.h"
#import "DynamicPlaylistInformationSheet.h"

enum {
	KeyPathPopupButtonTag			= 1,
	PredicateTypePopupButtonTag		= 2
};

@interface DynamicPlaylistCriterion (Private)

- (void)				setView:(NSView *)view;

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
	[_view release],			_view = nil;
	[_keyPath release],			_keyPath = nil;
	[_searchTerm release],		_searchTerm = nil;
	
	[super dealloc];
}

- (void) awakeFromNib
{
	NSPopUpButton		*popUpButton;
	NSString			*keyPath;

	// Reasonable defaults
	_predicateType	= NSEqualToPredicateOperatorType;
	[self setAttributeType:NSStringAttributeType];
	
	//	[self setupKeyPathPopUpButton];
//	[self setupPredicateTypePopUpButton];

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
	return _view;	
}

- (NSAttributeType) attributeType
{
	return _attributeType;
}

- (void) setAttributeType:(NSAttributeType)attributeType
{
	// Swap out views if a different attributeType was selected
	if([self attributeType] != attributeType) {
		NSView				*oldView;
		NSPopUpButton		*popUpButton;

		oldView				= [self view];
		_attributeType		= attributeType;
		
		// Determine the view that matches our new attributeType
		switch([self attributeType]) {
			case NSUndefinedAttributeType:		[self setView:nil];									break;
				
			case NSInteger16AttributeType:		[self setView:_integer16CriterionViewPrototype];	break;
			case NSInteger32AttributeType:		[self setView:_integer32CriterionViewPrototype];	break;
			case NSInteger64AttributeType:		[self setView:_integer64CriterionViewPrototype];	break;
				
			case NSDecimalAttributeType:		[self setView:_decimalCriterionViewPrototype];		break;
			case NSDoubleAttributeType:			[self setView:_doubleCriterionViewPrototype];		break;
			case NSFloatAttributeType:			[self setView:_floatCriterionViewPrototype];		break;
				
			case NSStringAttributeType:			[self setView:_stringCriterionViewPrototype];		break;
				
			case NSBooleanAttributeType:		[self setView:_booleanCriterionViewPrototype];		break;
				
			case NSDateAttributeType:			[self setView:_dateCriterionViewPrototype];			break;
				
			case NSBinaryDataAttributeType:		[self setView:nil];									break;
				
			default:							[self setView:nil];									break;
		}
		
		if(nil != oldView) {
			NSView			*superview			= [oldView superview];
			
			[[self view] setFrame:[oldView frame]];
			[oldView removeFromSuperview];
			[superview addSubview:[self view]];
		}

		[self setupKeyPathPopUpButton];
		[self setupPredicateTypePopUpButton];
		
		// The same predicate types may not be available, so select the first one
		popUpButton			= [[self view] viewWithTag:PredicateTypePopupButtonTag];

		[popUpButton selectItemAtIndex:0];
		[self setPredicateType:[[popUpButton selectedItem] tag]];

		// Similarly, the searchTerm may not be valid either
		[self setSearchTerm:nil];

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
	
	if(nil == [self keyPath]/* || nil == [self searchTerm]*/) {
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

- (void) setView:(NSView *)view
{
	[_view release];
	_view = [view retain];
}

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
	
	keyPaths					= [NSArray arrayWithObjects:
		@"metadata.title", @"metadata.artist", @"metadata.album", 
		@"metadata.composer", @"metadata.genre", @"metadata.partOfCompilation", @"metadata.date", 
		@"metadata.trackNumber", @"metadata.trackTotal", @"metadata.discNumber", @"metadata.discTotal", 
		@"metadata.isrc", @"metadata.mcn",
		@"-", 
		@"properties.formatName", @"properties.bitsPerChannel", @"properties.bitrate", @"properties.channelsPerFrame", 
		@"properties.duration", @"properties.sampleRate", 
		@"-",
		@"dateAdded", @"firstPlayed", @"lastPlayed", @"playCount",
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
	else if([keyPath isEqualToString:@"properties.bitrate"]) {
		displayName		= @"Bitrate";
		attributeType	= NSInteger32AttributeType;
	}
	else if([keyPath isEqualToString:@"properties.channelsPerFrame"]) {
		displayName		= @"Channels";
		attributeType	= NSInteger32AttributeType;
	}
	else if([keyPath isEqualToString:@"properties.duration"]) {
		displayName		= @"Duration";
		attributeType	= NSDoubleAttributeType;
	}
	else if([keyPath isEqualToString:@"properties.sampleRate"]) {
		displayName		= @"Sample Rate";
		attributeType	= NSDoubleAttributeType;
	}
	else if([keyPath isEqualToString:@"dateAdded"]) {
		displayName		= @"Date Added";
		attributeType	= NSDateAttributeType;
	}
	else if([keyPath isEqualToString:@"firstPlayed"]) {
		displayName		= @"First Played";
		attributeType	= NSDateAttributeType;
	}
	else if([keyPath isEqualToString:@"lastPlayed"]) {
		displayName		= @"Last Played";
		attributeType	= NSDateAttributeType;
	}
	else if([keyPath isEqualToString:@"playCount"]) {
		displayName		= @"Play Count";
		attributeType	= NSInteger32AttributeType;
	}
	else if([keyPath isEqualToString:@"metadata.discNumber"]) {
		displayName		= @"Disc Number";
		attributeType	= NSInteger32AttributeType;
	}
	else if([keyPath isEqualToString:@"metadata.discTotal"]) {
		displayName		= @"Total Discs";
		attributeType	= NSInteger32AttributeType;
	}
	else if([keyPath isEqualToString:@"metadata.trackNumber"]) {
		displayName		= @"Track Number";
		attributeType	= NSInteger32AttributeType;
	}
	else if([keyPath isEqualToString:@"metadata.trackTotal"]) {
		displayName		= @"Total Tracks";
		attributeType	= NSInteger32AttributeType;
	}
	else if([keyPath isEqualToString:@"metadata.isrc"]) {
		displayName		= @"ISRC";
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:@"metadata.mcn"]) {
		displayName		= @"MCN";
		attributeType	= NSStringAttributeType;
	}
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
		keyPath,									@"keyPath",
		displayName,								@"displayName",
		[NSNumber numberWithInt:attributeType],		@"attributeType",
		nil];
}

@end
