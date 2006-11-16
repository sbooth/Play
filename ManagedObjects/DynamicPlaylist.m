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

#import "DynamicPlaylist.h"


@implementation DynamicPlaylist 

- (NSData *) predicateData 
{
	NSData * tmpValue;

	[self willAccessValueForKey: @"predicateData"];
	tmpValue = [self primitiveValueForKey: @"predicateData"];
	[self didAccessValueForKey: @"predicateData"];

	return tmpValue;
}

- (void) setPredicateData:(NSData *)value 
{
	[self willChangeValueForKey: @"predicateData"];
	[self setPrimitiveValue: value forKey: @"predicateData"];
	[self didChangeValueForKey: @"predicateData"];
}



- (void) commonAwake
{
	_streams	= nil;
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(refresh:) 
												 name:NSManagedObjectContextObjectsDidChangeNotification 
											   object:[self managedObjectContext]];	
}

- (void) awakeFromInsert
{
	[super awakeFromInsert];
	[self commonAwake];
	[self setPredicate: [NSPredicate predicateWithValue:YES]];
}

- (void) awakeFromFetch
{
	[super awakeFromFetch];
	[self commonAwake];
}

- (void) didTurnIntoFault
{	
	[[NSNotificationCenter defaultCenter] removeObserver: self 
													name:NSManagedObjectContextObjectsDidChangeNotification 
												  object:[self managedObjectContext]];

	[_streams release],			_streams = nil;
	[_fetchRequest release],	_fetchRequest = nil;
	[_predicate release],		_predicate = nil;

	[super didTurnIntoFault];
}

- (void) refresh
{
	[self willChangeValueForKey:@"streams"];
	[_streams release],			_streams = nil;    
	[self didChangeValueForKey:@"streams"];
}

- (void) refresh:(NSNotification *)notification
{
    // Performance and Infinite loop avoidance:  Only refresh if the 
    // updated/deleted/inserted objects include Recipes (the entity of the 
    // [self fetchRequest]) We don't want to re-fetch recipes if unrelated 
    // objects (for example, other smart groups) change.
	
	NSEnumerator *enumerator;
	id object;
	BOOL refresh = NO;
	
	NSEntityDescription *entity = [[self fetchRequest] entity];
	NSSet *updated = [[notification userInfo] objectForKey:NSUpdatedObjectsKey];
	NSSet *inserted = [[notification userInfo] objectForKey:NSInsertedObjectsKey];
	NSSet *deleted = [[notification userInfo] objectForKey:NSDeletedObjectsKey];
	
	enumerator = [updated objectEnumerator];	
	while ((refresh == NO) && (object = [enumerator nextObject])) {
		if ([object entity] == entity) {
			refresh = YES;	
		}
	}
	
	enumerator = [inserted objectEnumerator];	
	while ((refresh == NO) && (object = [enumerator nextObject])) {
		if ([object entity] == entity) {
			refresh = YES;	
		}
	}
	
	enumerator = [deleted objectEnumerator];	
	while ((refresh == NO) && (object = [enumerator nextObject])) {
		if ([object entity] == entity) {
			refresh = YES;	
		}
	}
	
    if ( (refresh == NO) && (([updated count] == 0) && ([inserted count] == 0) && ([deleted count]==0))) {
        refresh = YES;
    }
    
	// OPTIMIZATION TIP:  We could collect all of the Recipe objects from the 
    // inserted and updated NSSets and add them to an array. Filter the array 
    // using [self predicate]. Only if the filtered array is non-empty would we 
    // need to update our recipes set (we could simply add the objects to the 
    // set)
	
	// OPTIMIZATION TIP: We could remove the objects of the deleted set 
    // directly from our recipes set ([recipes minusSet:deleted]).
	
    if (refresh) {
		[self refresh];
    }
}


- (NSFetchRequest *) fetchRequest 
{
	if(nil == _fetchRequest) {
		
		_fetchRequest = [[NSFetchRequest alloc] init];

		[_fetchRequest setEntity:[NSEntityDescription entityForName:@"AudioStream" inManagedObjectContext:[self managedObjectContext]]];
		[_fetchRequest setPredicate:[self predicate]];
	}

	return _fetchRequest;
}

- (NSPredicate *) predicate
{
	NSData	*predicateData;
	
	if(nil == _predicate) {
		
		predicateData	= [self valueForKey:@"predicateData"];
		if(nil !=  predicateData) {
			_predicate	= [(NSPredicate *)[NSKeyedUnarchiver unarchiveObjectWithData: predicateData] retain];
		}
	}

	return _predicate;
}

- (void) setPredicate:(NSPredicate *)newPredicate
{
	if(_predicate != newPredicate) {
		
		[_predicate autorelease];
		
		if(nil ==  newPredicate) {
			newPredicate	= [NSPredicate predicateWithValue:YES];
		}
		
		_predicate			= [newPredicate retain];

		NSData	*predicateData	= [NSKeyedArchiver archivedDataWithRootObject:_predicate];
		[self setValue: predicateData forKey: @"predicateData"];
		
		[[self fetchRequest] setPredicate:_predicate];
		[self refresh];
	}
}

- (NSSet *) streams
{
	if(nil ==  _streams)  {
		NSError		*error		= nil;
		NSArray		*results	= nil;

		@try {
			results = [[self managedObjectContext] executeFetchRequest:[self fetchRequest] error:&error];
		}
		
		// A bad predicate will throw an exception
		@catch(NSException *e) {
			NSLog(@"Caught an exception fetching streams for DynamicPlaylist: %@", e);
		}

		if(nil == results && nil != error) {
			NSLog(@"Error fetching streams for DynamicPlaylist: %@", error);
		}
		
		// use an empty set in the case where something went awry
		_streams = (nil != error || nil == results) ? [[NSSet alloc] init] : [[NSSet alloc] initWithArray:results];
	}

	return _streams;
}

- (void) setStreams:(NSSet *)newStreams
{
	// Not allowed
}

- (NSImage *) image
{
	return [NSImage imageNamed:@"DynamicPlaylist.png"];
}

@end
