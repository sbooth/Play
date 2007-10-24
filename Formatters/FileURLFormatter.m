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

#import "FileURLFormatter.h"

@implementation FileURLFormatter

- (NSString *) stringForObjectValue:(id)object
{
	if(nil == object || NO == [object isKindOfClass:[NSURL class]])
		return nil;

	return [[object path] stringByAbbreviatingWithTildeInPath];
}

- (BOOL) getObjectValue:(id *)object forString:(NSString *)string errorDescription:(NSString  **)error
{
	*object = (nil == string ? nil : [[NSURL URLWithString:[string stringByExpandingTildeInPath]] absoluteString]);
	return YES;
}

- (NSAttributedString *) attributedStringForObjectValue:(id)object withDefaultAttributes:(NSDictionary *)attributes
{
	NSString *result = [[NSAttributedString alloc] initWithString:[self stringForObjectValue:object] attributes:attributes];
	return [result autorelease];
}

@end
