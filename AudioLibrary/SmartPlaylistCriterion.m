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

#import "SmartPlaylistCriterion.h"
#import "SmartPlaylistInformationSheet.h"
#import "AudioStream.h"

enum {
	KeyPathPopupButtonTag			= 1,
	PredicateTypePopupButtonTag		= 2,
	SearchTermControlTag			= 3
};

@interface SmartPlaylistCriterion (Private)

- (void) setView:(NSView *)view;

- (void) setupKeyPathPopUpButton;
- (void) setupPredicateTypePopUpButton;

- (NSAttributeType) attributeTypeForKeyPath:(NSString *)keyPath;
- (NSString *) displayNameForKeyPath:(NSString *)keyPath;

- (NSDictionary *) propertiesDictionaryForKeyPath:(NSString *)keyPath;

- (void) unbindSearchTerm;
- (void) bindSearchTerm;

@end

@implementation SmartPlaylistCriterion

- (id) init
{
	if((self = [super init])) {
		BOOL result = [NSBundle loadNibNamed:@"SmartPlaylistCriterion" owner:self];
		if(NO == result) {
			NSLog(@"Missing resource: \"SmartPlaylistCriterion.nib\".");
			[self release];
			return nil;
		}
	}
	
	return self;
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
	// Set localized date formatters
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
	
	[[_dateCriterionViewPrototype viewWithTag:SearchTermControlTag] setFormatter:dateFormatter];
	
	[dateFormatter release];

	// Set localized number formatters
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];

	[[_integer16CriterionViewPrototype viewWithTag:SearchTermControlTag] setFormatter:numberFormatter];
	[[_integer32CriterionViewPrototype viewWithTag:SearchTermControlTag] setFormatter:numberFormatter];
	[[_integer64CriterionViewPrototype viewWithTag:SearchTermControlTag] setFormatter:numberFormatter];
	
	[[_decimalCriterionViewPrototype viewWithTag:SearchTermControlTag] setFormatter:numberFormatter];
	[[_floatCriterionViewPrototype viewWithTag:SearchTermControlTag] setFormatter:numberFormatter];
	[[_doubleCriterionViewPrototype viewWithTag:SearchTermControlTag] setFormatter:numberFormatter];
	
	[numberFormatter release];
	
	// Reasonable defaults
	_predicateType	= NSEqualToPredicateOperatorType;
	[self setAttributeType:NSStringAttributeType];
	
//	[self setupKeyPathPopUpButton];
//	[self setupPredicateTypePopUpButton];

	NSPopUpButton	*popUpButton	= [[self view] viewWithTag:KeyPathPopupButtonTag];
	NSString		*keyPath		= [[[popUpButton selectedItem] representedObject] valueForKey:@"keyPath"];

	[self setKeyPath:keyPath];
}

- (IBAction) didSelectKeyPath:(id)sender
{
	NSDictionary	*representedObject		= [[sender selectedItem] representedObject];
	NSString		*keyPath				= [representedObject valueForKey:@"keyPath"];
	NSNumber		*attributeType			= [representedObject valueForKey:@"attributeType"];
	
	[self setKeyPath:keyPath];
	[self setAttributeType:[attributeType intValue]];
}

- (NSView *) view
{
	return [[_view retain] autorelease];
}

- (NSAttributeType) attributeType
{
	return _attributeType;
}

- (void) setAttributeType:(NSAttributeType)attributeType
{
	// Swap out views if a different attributeType was selected
	if([self attributeType] != attributeType) {
		NSView *oldView = [self view];

		// Having all the prototype views bound to searchTerm simultaneously can cause errors, for example
		// an NSDate does not respond to intValue, which the integer views expect
		// So all bindings must be established programatically
		[self unbindSearchTerm];
		
		_attributeType = attributeType;
		
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
			NSView *superview = [oldView superview];
			
			[[self view] setFrame:[oldView frame]];
			[oldView removeFromSuperview];
			[superview addSubview:[self view]];
		}

		[self setupKeyPathPopUpButton];
		[self setupPredicateTypePopUpButton];
		
		// The same predicate types may not be available, so select the first one
		NSPopUpButton *popUpButton = [[self view] viewWithTag:PredicateTypePopupButtonTag];

		[popUpButton selectItemAtIndex:0];
		[self setPredicateType:[[popUpButton selectedItem] tag]];

		// Similarly, the searchTerm may not be valid either
		[self setSearchTerm:nil];

		[self bindSearchTerm];
	}	
}

- (NSString *) keyPath
{
	return [[_keyPath retain] autorelease];
}

- (void) setKeyPath:(NSString *)keyPath
{
	[_keyPath release];
	_keyPath = [keyPath retain];
	
	// First determine the object type of the keyPath that was selected
	NSPopUpButton	*popUpButton		= [[self view] viewWithTag:KeyPathPopupButtonTag];
	id				representedObject	= [self propertiesDictionaryForKeyPath:[self keyPath]];
	
	// Update our attribute type, which could swap out the view
	[self setAttributeType:[[representedObject valueForKey:@"attributeType"] intValue]];

	// Sync the popUpButton's selection (necessary since our view could have changed)
	popUpButton = [[self view] viewWithTag:KeyPathPopupButtonTag];
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
	return [[_searchTerm retain] autorelease];
}

- (void) setSearchTerm:(id)searchTerm
{
	[_searchTerm release];
	_searchTerm = [searchTerm retain];
}

- (NSPredicate *) predicate
{
	if(nil == [self keyPath]/* || nil == [self searchTerm]*/)
		return [NSPredicate predicateWithValue:YES];
	
	NSExpression	*left		= [NSExpression expressionForKeyPath:[self keyPath]];
	NSExpression	*right		= [NSExpression expressionForConstantValue:[self searchTerm]];
	
	// IN is reversed
	if(NSInPredicateOperatorType == [self predicateType]) {
		return [NSComparisonPredicate predicateWithLeftExpression:right
												  rightExpression:left
														 modifier:NSDirectPredicateModifier
															 type:[self predicateType]
														  options:NSCaseInsensitivePredicateOption/*NSDiacriticInsensitivePredicateOption*/];	
	}
	
	return [NSComparisonPredicate predicateWithLeftExpression:left
											  rightExpression:right
													 modifier:NSDirectPredicateModifier
														 type:[self predicateType]
													  options:NSCaseInsensitivePredicateOption/*NSDiacriticInsensitivePredicateOption*/];	
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"SmartPlaylistCriterion: %@", [self predicate]];
}

@end

@implementation SmartPlaylistCriterion (Private)

- (void) setView:(NSView *)view
{
	[_view release];
	_view = [view retain];
}

- (void) setupKeyPathPopUpButton
{
	NSMenuItem	*menuItem	= nil;
	
	NSPopUpButton *keyPathPopUpButton = [[self view] viewWithTag:KeyPathPopupButtonTag];
	[keyPathPopUpButton removeAllItems];
	
	NSMenu *buttonMenu = [keyPathPopUpButton menu];
	
	NSArray *keyPaths = [NSArray arrayWithObjects:
		MetadataTitleKey, MetadataAlbumTitleKey, MetadataArtistKey, MetadataAlbumArtistKey,
		MetadataGenreKey, MetadataComposerKey, MetadataDateKey, MetadataCompilationKey, 
		MetadataTrackNumberKey, MetadataTrackTotalKey, MetadataDiscNumberKey, MetadataDiscTotalKey, 
		MetadataISRCKey, MetadataMCNKey, MetadataBPMKey,
		@"-", 
		PropertiesFileTypeKey, PropertiesDataFormatKey, PropertiesFormatDescriptionKey, 
		PropertiesBitsPerChannelKey, PropertiesChannelsPerFrameKey, PropertiesSampleRateKey, 
		PropertiesTotalFramesKey, @"duration", PropertiesBitrateKey,
		@"-",
		StatisticsDateAddedKey, StatisticsFirstPlayedDateKey, StatisticsLastPlayedDateKey, StatisticsLastSkippedDateKey,
		StatisticsPlayCountKey, StatisticsSkipCountKey, StatisticsRatingKey,
		nil];
	
	for(NSString *keyPath in keyPaths) {
		if([keyPath isEqualToString:@"-"]) {
			[buttonMenu addItem:[NSMenuItem separatorItem]];
		}
		else {
			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:[self displayNameForKeyPath:keyPath]];
			[menuItem setRepresentedObject:[self propertiesDictionaryForKeyPath:keyPath]];
			[buttonMenu addItem:[menuItem autorelease]];
		}
	}
}

- (void) setupPredicateTypePopUpButton
{
	NSMenuItem *menuItem = nil;

	NSPopUpButton *predicateTypePopUpButton = [[self view] viewWithTag:PredicateTypePopupButtonTag];
	[predicateTypePopUpButton removeAllItems];
	
	NSMenu *buttonMenu = [predicateTypePopUpButton menu];
	
	switch([self attributeType]) {
		case NSInteger16AttributeType:
		case NSInteger32AttributeType:
		case NSInteger64AttributeType:
		case NSDecimalAttributeType:
		case NSDoubleAttributeType:
		case NSFloatAttributeType:
			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"is equal to", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"is not equal to", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSNotEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];

			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"is less than", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSLessThanPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];

			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"is less than or equal to", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSLessThanOrEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];

			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"is greater than", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSGreaterThanPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"is greater than or equal to", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSGreaterThanOrEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			break;
			
		case NSStringAttributeType:
			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"is", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"is not", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSNotEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"contains", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSInPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"starts with", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSBeginsWithPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"ends with", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSEndsWithPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];

			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"matches", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSMatchesPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			break;
			
		case NSBooleanAttributeType:
			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"is", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"is not", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSNotEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];

			break;
			
		case NSDateAttributeType:
			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"is", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"is not", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSNotEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"is before", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSLessThanPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"is or is before", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSLessThanOrEqualToPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"is after", @"SmartPlaylistCriteria", @"")];
			[menuItem setTag:NSGreaterThanPredicateOperatorType];
			[buttonMenu addItem:[menuItem autorelease]];
			
			menuItem = [[NSMenuItem alloc] init];
			[menuItem setTitle:NSLocalizedStringFromTable(@"is or is after", @"SmartPlaylistCriteria", @"")];
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
	
	if([keyPath isEqualToString:MetadataTitleKey]) {
		displayName		= NSLocalizedStringFromTable(@"Title", @"AudioStream", @"");
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:MetadataAlbumTitleKey]) {
		displayName		= NSLocalizedStringFromTable(@"Album Title", @"AudioStream", @"");
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:MetadataArtistKey]) {
		displayName		= NSLocalizedStringFromTable(@"Artist", @"AudioStream", @"");
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:MetadataAlbumArtistKey]) {
		displayName		= NSLocalizedStringFromTable(@"Album Artist", @"AudioStream", @"");
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:MetadataGenreKey]) {
		displayName		= NSLocalizedStringFromTable(@"Genre", @"AudioStream", @"");
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:MetadataComposerKey]) {
		displayName		= NSLocalizedStringFromTable(@"Composer", @"AudioStream", @"");
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:MetadataDateKey]) {
		displayName		= NSLocalizedStringFromTable(@"Date", @"AudioStream", @"");
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:MetadataCompilationKey]) {
		displayName		= NSLocalizedStringFromTable(@"Part of a Compilation", @"AudioStream", @"");
		attributeType	= NSBooleanAttributeType;
	}
	else if([keyPath isEqualToString:MetadataTrackNumberKey]) {
		displayName		= NSLocalizedStringFromTable(@"Track Number", @"AudioStream", @"");
		attributeType	= NSInteger32AttributeType;
	}
	else if([keyPath isEqualToString:MetadataTrackTotalKey]) {
		displayName		= NSLocalizedStringFromTable(@"Track Total", @"AudioStream", @"");
		attributeType	= NSInteger32AttributeType;
	}
	else if([keyPath isEqualToString:MetadataDiscNumberKey]) {
		displayName		= NSLocalizedStringFromTable(@"Disc Number", @"AudioStream", @"");
		attributeType	= NSInteger32AttributeType;
	}
	else if([keyPath isEqualToString:MetadataDiscTotalKey]) {
		displayName		= NSLocalizedStringFromTable(@"Disc Total", @"AudioStream", @"");
		attributeType	= NSDoubleAttributeType;
	}
	else if([keyPath isEqualToString:MetadataISRCKey]) {
		displayName		= NSLocalizedStringFromTable(@"ISRC", @"AudioStream", @"");
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:MetadataMCNKey]) {
		displayName		= NSLocalizedStringFromTable(@"MCN", @"AudioStream", @"");
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:MetadataBPMKey]) {
		displayName		= NSLocalizedStringFromTable(@"BPM", @"AudioStream", @"");
		attributeType	= NSInteger32AttributeType;
	}
	else if([keyPath isEqualToString:PropertiesFileTypeKey]) {
		displayName		= NSLocalizedStringFromTable(@"File Type", @"AudioStream", @"");
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:PropertiesDataFormatKey]) {
		displayName		= NSLocalizedStringFromTable(@"Data Format", @"AudioStream", @"");
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:PropertiesFormatDescriptionKey]) {
		displayName		= NSLocalizedStringFromTable(@"Format Description", @"AudioStream", @"");
		attributeType	= NSStringAttributeType;
	}
	else if([keyPath isEqualToString:PropertiesBitsPerChannelKey]) {
		displayName		= NSLocalizedStringFromTable(@"Sample Size", @"AudioStream", @"");
		attributeType	= NSInteger32AttributeType;
	}
	else if([keyPath isEqualToString:PropertiesChannelsPerFrameKey]) {
		displayName		= NSLocalizedStringFromTable(@"Channels", @"AudioStream", @"");
		attributeType	= NSInteger32AttributeType;
	}
	else if([keyPath isEqualToString:PropertiesSampleRateKey]) {
		displayName		= NSLocalizedStringFromTable(@"Sample Rate", @"AudioStream", @"");
		attributeType	= NSDoubleAttributeType;
	}
	else if([keyPath isEqualToString:PropertiesTotalFramesKey]) {
		displayName		= NSLocalizedStringFromTable(@"Total Frames", @"AudioStream", @"");
		attributeType	= NSInteger64AttributeType;
	}
	else if([keyPath isEqualToString:@"duration"]) {
		displayName		= NSLocalizedStringFromTable(@"Duration", @"AudioStream", @"");
		attributeType	= NSDoubleAttributeType;
	}
	else if([keyPath isEqualToString:PropertiesBitrateKey]) {
		displayName		= NSLocalizedStringFromTable(@"Bitrate", @"AudioStream", @"");
		attributeType	= NSDoubleAttributeType;
	}
	else if([keyPath isEqualToString:StatisticsDateAddedKey]) {
		displayName		= NSLocalizedStringFromTable(@"Date Added", @"AudioStream", @"");
		attributeType	= NSDateAttributeType;
	}
	else if([keyPath isEqualToString:StatisticsFirstPlayedDateKey]) {
		displayName		= NSLocalizedStringFromTable(@"First Played", @"AudioStream", @"");
		attributeType	= NSDateAttributeType;
	}
	else if([keyPath isEqualToString:StatisticsLastPlayedDateKey]) {
		displayName		= NSLocalizedStringFromTable(@"Last Played", @"AudioStream", @"");
		attributeType	= NSDateAttributeType;
	}
	else if([keyPath isEqualToString:StatisticsLastSkippedDateKey]) {
		displayName		= NSLocalizedStringFromTable(@"Last Skipped", @"AudioStream", @"");
		attributeType	= NSDateAttributeType;
	}
	else if([keyPath isEqualToString:StatisticsPlayCountKey]) {
		displayName		= NSLocalizedStringFromTable(@"Play Count", @"AudioStream", @"");
		attributeType	= NSInteger32AttributeType;
	}
	else if([keyPath isEqualToString:StatisticsSkipCountKey]) {
		displayName		= NSLocalizedStringFromTable(@"Skip Count", @"AudioStream", @"");
		attributeType	= NSInteger32AttributeType;
	}
	else if([keyPath isEqualToString:StatisticsRatingKey]) {
		displayName		= NSLocalizedStringFromTable(@"Rating", @"AudioStream", @"");
		attributeType	= NSInteger32AttributeType;
	}
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
		keyPath,									@"keyPath",
		displayName,								@"displayName",
		[NSNumber numberWithInt:attributeType],		@"attributeType",
		nil];
}

- (void) unbindSearchTerm
{
	id bindingTarget = [[self view] viewWithTag:SearchTermControlTag];
	
	switch([self attributeType]) {
		case NSUndefinedAttributeType:		;													break;
			
		case NSInteger16AttributeType:		[bindingTarget unbind:@"value"];					break;
		case NSInteger32AttributeType:		[bindingTarget unbind:@"value"];					break;
		case NSInteger64AttributeType:		[bindingTarget unbind:@"value"];					break;
			
		case NSDecimalAttributeType:		[bindingTarget unbind:@"value"];					break;
		case NSDoubleAttributeType:			[bindingTarget unbind:@"value"];					break;
		case NSFloatAttributeType:			[bindingTarget unbind:@"value"];					break;
			
		case NSStringAttributeType:			[bindingTarget unbind:@"value"];					break;
			
		case NSBooleanAttributeType:		[bindingTarget unbind:@"selectedTag"];				break;
			
		case NSDateAttributeType:			[bindingTarget unbind:@"value"];					break;
			
		case NSBinaryDataAttributeType:		;													break;
			
		default:							;													break;
	}
}

- (void) bindSearchTerm
{
	id				bindingTarget	= [[self view] viewWithTag:SearchTermControlTag];
	NSDictionary	*options		= [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil];
	
	switch([self attributeType]) {
		case NSUndefinedAttributeType:		;																							break;
			
		case NSInteger16AttributeType:		[bindingTarget bind:@"value" toObject:self withKeyPath:@"searchTerm" options:options];		break;
		case NSInteger32AttributeType:		[bindingTarget bind:@"value" toObject:self withKeyPath:@"searchTerm" options:options];		break;
		case NSInteger64AttributeType:		[bindingTarget bind:@"value" toObject:self withKeyPath:@"searchTerm" options:options];		break;
			
		case NSDecimalAttributeType:		[bindingTarget bind:@"value" toObject:self withKeyPath:@"searchTerm" options:options];		break;
		case NSDoubleAttributeType:			[bindingTarget bind:@"value" toObject:self withKeyPath:@"searchTerm" options:options];		break;
		case NSFloatAttributeType:			[bindingTarget bind:@"value" toObject:self withKeyPath:@"searchTerm" options:options];		break;
			
		case NSStringAttributeType:			[bindingTarget bind:@"value" toObject:self withKeyPath:@"searchTerm" options:options];		break;
			
		case NSBooleanAttributeType:		[bindingTarget bind:@"selectedTag" toObject:self withKeyPath:@"searchTerm" options:nil];	break;
			
		case NSDateAttributeType:			[bindingTarget bind:@"value" toObject:self withKeyPath:@"searchTerm" options:options];		break;
			
		case NSBinaryDataAttributeType:		;																							break;
			
		default:							;																							break;
	}
}

@end
