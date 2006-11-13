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



/** 
Called from awakeFromInsert and awakeFromFetch. Here we register for the 
notification for changes to the managed object context, in order to be able 
to refresh the smart group when the object graph changes.
*/

- (void)commonAwake {

    _streams = nil;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh:) 
												 name:NSManagedObjectContextObjectsDidChangeNotification object:[self managedObjectContext]];        
	
//    [self willAccessValueForKey:@"priority"];
  //  [self setValue:[NSNumber numberWithInt:2] forKeyPath:@"priority"];
 //   [self didAccessValueForKey:@"priority"];
}


/** 
Overridden awakeFromInsertion method, used to call the commonAwake 
implementation (to register for the notification of changes to the 
				predicate.)  We also ensure the predicate is something valid here.
*/

- (void)awakeFromInsert  {
	
    // awake from insert
    [super awakeFromInsert];
    [self commonAwake];
    
    // create an initial predicate
    [self setPredicate: [NSPredicate predicateWithValue: YES]];
}


/** 
Overridden awakeFromFetch method, used to call the commonAwake 
implementation (to register for the notification of changes to the 
				predicate.)
*/


- (void)awakeFromFetch  {
	
    [super awakeFromFetch];
    [self commonAwake];
}


/** 
Overridden didTurnIntoFault method.  In addition to releasing the array of 
recipes, the fetch request, and the predicate, we need to unregister for the 
notifications from the managed object context before dealloc-ing.
*/

- (void)didTurnIntoFault {
	
    [[NSNotificationCenter defaultCenter] removeObserver: self 
													name:NSManagedObjectContextObjectsDidChangeNotification object:[self managedObjectContext]];
	
    [_streams release],			_streams = nil;
    [_fetchRequest release],	_fetchRequest = nil;
    [_predicate release],		_predicate = nil;
    
    [super didTurnIntoFault];
}


/**
Method to refresh the content of the smart group.  Here we simply note the
 contents of the "recipes" array is going to change, and then release the
 array.  A new one will be lazily created as necessary.
 */

- (void)refresh {
	
//	[self willChangeValueForKey:@"summaryString"];
	[self willChangeValueForKey:@"streams"];
	[_streams release], _streams = nil;    
	[self didChangeValueForKey:@"streams"];
//	[self didChangeValueForKey:@"summaryString"];
}


/**
Method to refresh the SmartGroup object.  This method is invoked either when 
 the predicate changes OR when object change notifications are received from 
 the context.  Since a change to a predicate is immediately pushed into the 
 fetch request, all we need do here is clear the array of recipes so it will 
 be re-created on the next access.
 */

- (void)refresh:(NSNotification *)notification {

    // Performance and Infinite loop avoidance:  Only refresh if the 
    // updated/deleted/inserted objects include Recipes (the entity of the 
    // [self fetchRequest]) We don't want to re-fetch recipes if unrelated 
    // objects (for example, other smart groups) change.
	
	NSEnumerator *enumerator;
	id object;
	BOOL refresh = NO;
	
	NSEntityDescription *entity = [[self fetchRequest] entity];
//	NSLog(@"myEntity=%@",[entity name]);
	NSSet *updated = [[notification userInfo] objectForKey:NSUpdatedObjectsKey];
	NSSet *inserted = [[notification userInfo] objectForKey:NSInsertedObjectsKey];
	NSSet *deleted = [[notification userInfo] objectForKey:NSDeletedObjectsKey];
	
	enumerator = [updated objectEnumerator];	
	while ((refresh == NO) && (object = [enumerator nextObject])) {
//		NSLog(@"updated:%@",object);
		if ([object entity] == entity) {
			refresh = YES;	
		}
	}
	
	enumerator = [inserted objectEnumerator];	
	while ((refresh == NO) && (object = [enumerator nextObject])) {
//		NSLog(@"inserted:%@",object);
		if ([object entity] == entity) {
			refresh = YES;	
		}
	}
	
	enumerator = [deleted objectEnumerator];	
	while ((refresh == NO) && (object = [enumerator nextObject])) {
//		NSLog(@"deleted:%@",object);
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


/**
Accessor for the fetch request for the SmartGroup.  The fetch
 request is used to fetch all of the matching objects for the predicate for 
 the SmartGroup.  The fetch request is only created once per object (since 
																	 the entity will not change), though the predicate for the request can 
 change as needed.
 */

- (NSFetchRequest *)fetchRequest  {
    if ( _fetchRequest == nil ) {
		
        // create the fetch request for the recipes
        _fetchRequest = [[NSFetchRequest alloc] init];
        [_fetchRequest setEntity: [NSEntityDescription entityForName:@"AudioStream" inManagedObjectContext:[self managedObjectContext]]];
		
        // set the affected stores
//        id store = [[self objectID] persistentStore];
  //      if (store != nil) {
    //        [_fetchRequest setAffectedStores:[NSArray arrayWithObject:store]];
    //    }
		
        // set the predicate
        [_fetchRequest setPredicate: [self predicate]];
    }
    
    return _fetchRequest;
}


/** 
Accessor for the predicate for the SmartGroup instance.  The value of the 
instance variable comes from decoding the NSData for the "predicateData" 
attribute (where the predicate is archived.)
*/

- (NSPredicate *)predicate {

    NSData *predicateData;
    if ( _predicate == nil ) {
		
        predicateData = [self valueForKey: @"predicateData"];
        if ( predicateData != nil ) {
            _predicate = [(NSPredicate *)[NSKeyedUnarchiver unarchiveObjectWithData: predicateData] retain];
        }
    }
    
    return _predicate;
}


/**
Mutator method for the predicate for the SmartGroup instance.  When a new 
 predicate is set for the SmartGroup, we must first store the new value in 
 the instance variable, then encode it into a data representation (to set 
																   into the model), and then update the fetch request for the smart group with 
 the new predicate.
 */

- (void)setPredicate: (NSPredicate *)newPredicate {
	
    if ( _predicate != newPredicate )  {
		
        // release the old
        [_predicate autorelease];
		
        // ensure we have a predicate
        if ( newPredicate == nil ) {
            newPredicate = [NSPredicate predicateWithValue: YES];
        }
        
        // retain the new predicate and update the data
        _predicate = [newPredicate retain];
		NSData *predicateData = [NSKeyedArchiver archivedDataWithRootObject:_predicate];
        [self setValue: predicateData forKey: @"predicateData"];
		
        // update the fetch request
        [[self fetchRequest] setPredicate: _predicate];
		[self refresh];
    }
}

/** 
Accesor for the array of recipes for the SmartGroup.  This implementation 
returns the objects matching the specified predicate using the cached fetch 
request.  An empty set (not nil) is returned if there are no objects to be 
found OR if an error was encountered with the fetch.
*/

- (NSSet *)streams {
	
    if ( _streams == nil )  {
        // variables
        NSError *error = nil;
        NSArray *results = nil;

        // in case the predicate is bad
        @try {  results = [[self managedObjectContext] executeFetchRequest:[self fetchRequest] error:&error];  }
        @catch ( NSException *e ) {  NSLog(@"Caught an exception: %@", e); /* no-op */ }

		if(nil == results) {
			NSLog(@"Error fetching streams for DynamicPlaylist: %@", error);
		}
		
        // use an empty set in the case where something went awry
        _streams = ( error != nil || results == nil) ? [[NSSet alloc] init] : [[NSSet alloc] initWithArray:results];
    }
	
    return _streams;
}


/** 
Recipes for smart groups aren't really settable. Ensure that nothing tries 
to mutate recipes by KVC.
*/

- (void)setStreams:(NSSet *)newStreams  {
    // noop   
}

- (NSImage *) image
{
	return [NSImage imageNamed:@"DynamicPlaylist.png"];
}

@end
