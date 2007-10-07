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

#import "WatchFolder.h"
#import "CollectionManager.h"
#import "WatchFolderManager.h"
#import "AudioStreamManager.h"
#import "AudioLibrary.h"

NSString * const	WatchFolderURLKey							= @"url";
NSString * const	WatchFolderNameKey							= @"name";
NSString * const	WatchFolderStreamsKey						= @"streams";

@implementation WatchFolder

+ (void) initialize
{
	[self exposeBinding:WatchFolderURLKey];
	[self exposeBinding:WatchFolderNameKey];
	[self exposeBinding:WatchFolderStreamsKey];
}

+ (id) insertWatchFolderWithInitialValues:(NSDictionary *)keyedValues
{
	WatchFolder *folder = [[WatchFolder alloc] init];
	
	// Call init: methods here to avoid sending change notifications
	[folder initValuesForKeysWithDictionary:keyedValues];
	
	if(NO == [[[CollectionManager manager] watchFolderManager] insertWatchFolder:folder])
		[folder release], folder = nil;
	
	return [folder autorelease];
}

- (id) init
{
	if((self = [super init]))
		_streams = [[NSMutableArray alloc] init];
	return self;
}

- (void) dealloc
{
	[_streams release], _streams = nil;
	
	[super dealloc];
}

#pragma mark Stream Management

- (NSArray *) streams
{
	return [[_streams retain] autorelease];
}

- (AudioStream *) streamAtIndex:(unsigned)index
{
	return [self objectInStreamsAtIndex:index];
}

#pragma mark KVC Accessors

- (unsigned) countOfStreams
{
	return [_streams count];
}

- (AudioStream *) objectInStreamsAtIndex:(unsigned)index
{
	return [_streams objectAtIndex:index];
}

- (void) getStreams:(id *)buffer range:(NSRange)range
{
	return [_streams getObjects:buffer range:range];
}

- (void) save
{
	[[[CollectionManager manager] watchFolderManager] saveWatchFolder:self];
}

- (void) delete
{
	[[[CollectionManager manager] watchFolderManager] deleteWatchFolder:self];
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"[%@] %@", [self valueForKey:ObjectIDKey], [self valueForKey:WatchFolderNameKey]];
}

- (NSString *) debugDescription
{
	return [NSString stringWithFormat:@"<%@, %x> [%@] %@", [self class], self, [self valueForKey:ObjectIDKey], [self valueForKey:WatchFolderNameKey]];
}

#pragma mark Reimplementations

- (NSArray *) supportedKeys
{
	if(nil == _supportedKeys) {
		_supportedKeys	= [[NSArray alloc] initWithObjects:
			ObjectIDKey, 
			WatchFolderURLKey, 

			WatchFolderNameKey, 
			
			nil];
	}	
	return _supportedKeys;
}

@end

@implementation WatchFolder (WatchFolderNodeMethods)

- (void) loadStreams
{
	[self willChangeValueForKey:WatchFolderStreamsKey];
	[_streams removeAllObjects];
	[_streams addObjectsFromArray:[[[CollectionManager manager] streamManager] streamsForWatchFolder:self]];
	[self didChangeValueForKey:WatchFolderStreamsKey];
}

@end

@implementation WatchFolder (ScriptingAdditions)

- (void) handleEnqueueScriptCommand:(NSScriptCommand *)command
{
	[self loadStreams];
	[[AudioLibrary library] addStreamsToPlayQueue:[self streams]];
}

- (NSScriptObjectSpecifier *) objectSpecifier
{
	id							libraryDescription	= [NSClassDescription classDescriptionForClass:[AudioLibrary class]];
	NSScriptObjectSpecifier		*librarySpecifier	= [[AudioLibrary library] objectSpecifier];
	NSScriptObjectSpecifier		*selfSpecifier		= [[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:libraryDescription
																								  containerSpecifier:librarySpecifier 
																												 key:@"watch folders" 
																											uniqueID:[self valueForKey:ObjectIDKey]];
	
	return [selfSpecifier autorelease];
}

@end
