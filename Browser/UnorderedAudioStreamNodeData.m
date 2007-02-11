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

#import "UnorderedAudioStreamNodeData.h"

@implementation UnorderedAudioStreamNodeData

+ (void) initialize
{
	[self exposeBinding:@"streams"];
}

- (id) init
{
	if((self = [super init])) {
		[self setIsSelectable:YES];
		return self;
	}	
	return nil;
}

- (void) refreshData {}

- (id) initWithName:(NSString *)name
{
	NSParameterAssert(nil != name);
	
	if((self = [super initWithName:name])) {
		[self setIsSelectable:YES];
		return self;
	}	
	return nil;
}

// ========================================
// KVC Accessors
- (unsigned)		countOfStreams											{ return 0; }
- (AudioStream *)	objectInStreamsAtIndex:(unsigned int)index				{ return nil; }
- (void)			getUnorderedStreams:(id *)buffer range:(NSRange)aRange	{}

// ========================================
// KVC Mutators
- (void) insertObject:(AudioStream *)stream inStreamsAtIndex:(unsigned int)index	{}
- (void) removeObjectFromStreamsAtIndex:(unsigned int)index							{}

@end
