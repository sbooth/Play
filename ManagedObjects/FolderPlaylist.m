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
}

- (NSSet *) streams
{
	return nil;
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
