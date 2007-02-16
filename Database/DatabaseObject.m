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

#import "DatabaseObject.h"
#import "CollectionManager.h"

NSString * const	DatabaseObjectDidChangeNotification		= @"org.sbooth.Play.DatabaseObjectDidChangeNotification";
NSString * const	DatabaseObjectKey						= @"org.sbooth.Play.DatabaseObject";
NSString * const	ObjectIDKey								= @"id";

@interface DatabaseObject (Private)
- (void) mySetValue:(id)value forKey:(NSString *)key;
@end

@implementation DatabaseObject

- (void) dealloc
{
	[[[CollectionManager manager] undoManager] removeAllActionsWithTarget:self];

	[_supportedKeys release], _supportedKeys = nil;
	
	[_savedValues release], _savedValues = nil;
	[_changedValues release], _changedValues = nil;
	
	[super dealloc];
}

- (id) valueForKey:(NSString *)key
{
	if([[self supportedKeys] containsObject:key]) {
		id value = [_changedValues valueForKey:key];
		if(nil == value) {
			value = [_savedValues valueForKey:key];
		}
		
		return ([value isEqual:[NSNull null]] ? nil : value);
	}
	else {
		return [super valueForKey:key];
	}
}

- (void) setValue:(id)value forKey:(NSString *)key
{
	NSParameterAssert(nil != key);
	
	if([[self supportedKeys] containsObject:key]) {

		[[[[CollectionManager manager] undoManager] prepareWithInvocationTarget:self] mySetValue:[self valueForKey:key] forKey:key];
		
		// Internally NSNull is used to indicate a value that was specifically set to nil
		if(nil == value) {
			value = [NSNull null];
		}
		
		if([[_savedValues valueForKey:key] isEqual:value]) {
			[_changedValues removeObjectForKey:key];
		}
		else {
			[_changedValues setValue:value forKey:key];			
		}
		
		[[CollectionManager manager] databaseObject:self didChangeForKey:key];
	}
	else {
		[super setValue:value forKey:key];
	}
}

- (unsigned) hash
{
	// Database ID is guaranteed to be unique
	return [[_savedValues valueForKey:ObjectIDKey] unsignedIntValue];
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"[%@]", [self valueForKey:ObjectIDKey]];
}

#pragma mark -

- (void) save
{
	[[CollectionManager manager] saveObject:self];
}

- (void) revert
{
	NSEnumerator	*changedKeys	= [[_changedValues allKeys] objectEnumerator];
	NSString		*key			= nil;


	while((key = [changedKeys nextObject])) {
		
		[[[[CollectionManager manager] undoManager] prepareWithInvocationTarget:self] mySetValue:[_savedValues valueForKey:key] forKey:key];

		[self willChangeValueForKey:key];
		[_changedValues removeObjectForKey:key];
		[self didChangeValueForKey:key];
	}
}

- (void) delete
{
	[[CollectionManager manager] deleteObject:self];
}

#pragma mark -

- (id) init
{
	if((self = [super init])) {
		_savedValues	= [[NSMutableDictionary alloc] init];
		_changedValues	= [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void) initValue:(id)value forKey:(NSString *)key
{
	[self willChangeValueForKey:key];
	[_changedValues removeObjectForKey:key];
	[_savedValues setValue:value forKey:key];
	[self didChangeValueForKey:key];
}

- (void) initValuesForKeysWithDictionary:(NSDictionary *)keyedValues
{
	NSEnumerator	*savedKeys		= [keyedValues keyEnumerator];
	NSString		*key			= nil;
	
	while((key = [savedKeys nextObject])) {
		[self initValue:[keyedValues valueForKey:key] forKey:key];
	}
}

- (BOOL) hasChanges
{
	return 0 != [_changedValues count];
}

- (NSDictionary *) changedValues
{
	return [[_changedValues copy] autorelease];
}

- (NSDictionary *) savedValues
{
	return [[_savedValues copy] autorelease];
}

#pragma mark Callbacks

- (void) didSave
{
	[[NSNotificationCenter defaultCenter] postNotificationName:DatabaseObjectDidChangeNotification 
														object:self 
													  userInfo:[NSDictionary dictionaryWithObject:self forKey:DatabaseObjectKey]];
}

#pragma mark Subclass Methods

- (NSArray *) supportedKeys
{
	@synchronized(self) {
		if(nil == _supportedKeys) {
			_supportedKeys = [[NSArray alloc] initWithObjects:ObjectIDKey, nil];
		}
	}
	return _supportedKeys;
}

@end

@implementation DatabaseObject (Private)

- (void) mySetValue:(id)value forKey:(NSString *)key
{
	[self setValue:value forKey:key];
}

@end
