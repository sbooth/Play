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

#import <CoreData/CoreData.h>
#import "Playlist.h"

@interface DynamicPlaylist :  Playlist  
{
	@private

	NSFetchRequest	*_fetchRequest;       
	NSPredicate		*_predicate;          

	NSSet			*_streams;
}

- (NSData *)	predicateData;
- (void)		setPredicateData:(NSData *)value;

	// Accessor for the predicate used by the SmartGroup to return matching Recipes
- (NSPredicate *)	predicate;

	// Mutator for the predicate used by the SmartGroup to return matching Recipes
- (void)			setPredicate:(NSPredicate *)predicate;

	// Accessor for the array of recipes for the SmartGroup
- (NSSet *)			streams;

	// Accessor for the fetch request for the SmartGroup
- (NSFetchRequest *)	fetchRequest;

	// Triggers the smart group to refresh its recipes. 
- (void)			refresh;

@end
