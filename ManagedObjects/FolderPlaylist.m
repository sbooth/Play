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

#import "FolderPlaylist.h"
#import "AudioStream.h"

@implementation FolderPlaylist 

- (NSString *)url 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey: @"url"];
    tmpValue = [self primitiveValueForKey: @"url"];
    [self didAccessValueForKey: @"url"];
    
    return tmpValue;
}

- (void)setUrl:(NSString *)value 
{
    [self willChangeValueForKey: @"url"];
    [self setPrimitiveValue: value forKey: @"url"];
    [self didChangeValueForKey: @"url"];
	
	[self refresh];
}

- (void)commonAwake {
	
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh:) 
												 name:NSManagedObjectContextObjectsDidChangeNotification object:[self managedObjectContext]];        
	
	//    [self willAccessValueForKey:@"priority"];
	//  [self setValue:[NSNumber numberWithInt:2] forKeyPath:@"priority"];
	//   [self didAccessValueForKey:@"priority"];
}

- (void) awakeFromInsert
{
	[super awakeFromInsert];
	[self commonAwake];
}

- (void) awakeFromFetch
{
	[super awakeFromFetch];
	[self commonAwake];
}

- (void)didTurnIntoFault {
	
    [[NSNotificationCenter defaultCenter] removeObserver: self 
													name:NSManagedObjectContextObjectsDidChangeNotification object:[self managedObjectContext]];
	
    [_streams release],				_streams = nil;
    [_fetchRequest release],		_fetchRequest = nil;
    
    [super didTurnIntoFault];
}

- (void)refresh {
	
	//	[self willChangeValueForKey:@"summaryString"];
	[self willChangeValueForKey:@"streams"];
	[_streams release], _streams = nil;    
	[self didChangeValueForKey:@"streams"];
	//	[self didChangeValueForKey:@"summaryString"];
}

- (void)refresh:(NSNotification *)notification {
	
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

- (NSFetchRequest *)fetchRequest  {
    if ( _fetchRequest == nil ) {
		
        // create the fetch request for the recipes
        _fetchRequest = [[NSFetchRequest alloc] init];
        [_fetchRequest setEntity: [NSEntityDescription entityForName:@"AudioStream" inManagedObjectContext:[self managedObjectContext]]];
		
        // set the affected stores
//        id store = [[self objectID] persistentStore];
//        if (store != nil) {
 //           [_fetchRequest setAffectedStores:[NSArray arrayWithObject:store]];
  //      }
		
        // set the predicate
//        [_fetchRequest setPredicate: [self predicate]];
    }
    
    return _fetchRequest;
}

- (NSSet *) streams
{	
    if ( _streams == nil )  {
        // variables
        NSError *error = nil;
        NSArray *results = nil;
		
        // in case the predicate is bad
        @try {
			NSURL *url = [NSURL fileURLWithPath:[self url]];
//			[[self fetchRequest] setPredicate:[NSPredicate predicateWithFormat:@"url BEGINSWITH %@", [url absoluteString]]];
			[[self fetchRequest] setPredicate:[NSPredicate predicateWithFormat:@"url IN %@", [self URLStringArray]]];
//			NSLog(@"FolderPlaylist fetchRequest: %@", [self fetchRequest]);
			results = [[self managedObjectContext] executeFetchRequest:[self fetchRequest] error:&error];
		}
        @catch ( NSException *e ) {  NSLog(@"Caught an exception: %@", e); /* no-op */ }
		
		if(nil == results) {
			NSLog(@"Error fetching streams for FolderPlaylist: %@", error);
		}
		
        // use an empty set in the case where something went awry
        _streams = ( error != nil || results == nil) ? [[NSSet alloc] init] : [[NSSet alloc] initWithArray:results];
    }
	
    return _streams;
}

- (NSArray *) URLStringArray
{
	NSFileManager				*manager;
	NSArray						*allowedTypes;
	NSURL						*URL;
	NSMutableArray				*URLs;
	NSString					*path;
	NSDirectoryEnumerator		*directoryEnumerator;
	NSString					*filename;
	BOOL						result, isDir;
	
	URLs						= [NSMutableArray array];
	URL							= [NSURL URLWithString:[self url]];
	manager						= [NSFileManager defaultManager];
	allowedTypes				= getAudioExtensions();
	path						= [URL path];
		
	result						= [manager fileExistsAtPath:path isDirectory:&isDir];
	
	if(NO == result || NO == isDir) {
		NSLog(@"Unable to locate folder \"%@\" for playlist.", path);
		return [NSArray array];
	}
		
	directoryEnumerator		= [manager enumeratorAtPath:path];
		
	while((filename = [directoryEnumerator nextObject])) {
		if([allowedTypes containsObject:[filename pathExtension]]) {
			[URLs addObject:[[NSURL fileURLWithPath:[path stringByAppendingPathComponent:filename]] absoluteString]];
		}
	}

	return URLs;
}

- (void) setStreams:(NSSet *)newStreams
{
    // No-op   
}

- (NSImage *) image
{
	NSImage		*result;
	NSImage		*resizedImage;
	NSSize		iconSize = { 16.0, 16.0 };
	
	result		= [NSImage imageNamed:@"FolderPlaylist"];
	
	if(nil != result) {
		resizedImage = [[NSImage alloc] initWithSize:iconSize];
		[resizedImage lockFocus];
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
		[result drawInRect:NSMakeRect(0, 0, iconSize.width, iconSize.height) fromRect:NSMakeRect(0, 0, [result size].width, [result size].height) operation:NSCompositeCopy fraction:1.0];
		[resizedImage unlockFocus];
		result = [resizedImage autorelease];
	}
	
	return result;
}

@end
