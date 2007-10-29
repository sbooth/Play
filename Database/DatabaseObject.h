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

// ========================================
// KVC key names for persistent properties
// ========================================
extern NSString * const		ObjectIDKey;

@class CollectionManager;

// ========================================
// KVC-compliant object whose persistent properties are stored in a database
// An instance of this class typically represents a single row in a table
// ========================================
@interface DatabaseObject : NSObject
{
	@protected
	NSArray					*_supportedKeys;
	
	@private
	NSMutableDictionary		*_savedValues;
	NSMutableDictionary		*_changedValues;
}

// ========================================
// Same as setValue:forKey: (used for NSInvocation/NSUndoManager)
- (void) mySetValue:(id)value forKey:(NSString *)key;

// ========================================
// Actions
- (void) save;
- (void) revert;
- (void) delete;

// ========================================
// Call these with the values retrieved from the database
- (void) initValue:(id)value forKey:(NSString *)key;
- (void) initValuesForKeysWithDictionary:(NSDictionary *)keyedValues;

// ========================================
// Change manaagement
- (BOOL) hasChanges;

- (id) changedValueForKey:(NSString *)key;
- (id) savedValueForKey:(NSString *)key;

- (NSDictionary *) changedValues;
- (NSDictionary *) savedValues;

- (void) synchronizeSavedValuesWithChangedValues;

// ========================================
// Returns a list of KVC keys for this object's persistent properties
- (NSArray *) supportedKeys;

@end
