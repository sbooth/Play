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

#import "SecondsFormatter.h"

#include <math.h>

@implementation SecondsFormatter

- (NSString *) stringForObjectValue:(id)object
{
	NSString		*result			= nil;
	unsigned		days			= 0;
	unsigned		hours			= 0;
	
	if(nil == object || NO == [object isKindOfClass:[NSNumber class]])
		return nil;
	
	float floatValue = [object floatValue];
	if(isnan(floatValue) || isinf(floatValue))
		return nil;
	
	unsigned value			= (unsigned)floatValue;
	unsigned seconds		= value % 60;
	unsigned minutes		= value / 60;
	
	while(60 <= minutes) {
		minutes -= 60;
		++hours;
	}
	
	while(24 <= hours) {
		hours -= 24;
		++days;
	}

	if(0 < days)
		result = [NSString stringWithFormat:@"%u:%.2u:%.2u:%.2u", days, hours, minutes, seconds];
	else if(0 < hours)
		result = [NSString stringWithFormat:@"%u:%.2u:%.2u", hours, minutes, seconds];
	else if(0 < minutes)
		result = [NSString stringWithFormat:@"%u:%.2u", minutes, seconds];
	else
		result = [NSString stringWithFormat:@"0:%.2u", seconds];
	
	return [[result retain] autorelease];
}

- (BOOL) getObjectValue:(id *)object forString:(NSString *)string errorDescription:(NSString  **)error
{
	NSScanner		*scanner		= nil;
	BOOL			result			= NO;
	int				value			= 0;
	unsigned		seconds;

	scanner		= [NSScanner scannerWithString:string];
	
	while(NO == [scanner isAtEnd]) {
		
		// Grab a value
		if([scanner scanInt:&value]) {
			seconds		*= 60;
			seconds		+= value;
			result		= YES;
		}
		
		// Grab the separator, if present
		[scanner scanString:@":" intoString:NULL];
	}
	
	if(result && NULL != object)
		*object = [NSNumber numberWithUnsignedInt:seconds];
	else if(NULL != error)
		*error = @"Couldn't convert value to seconds";
	
	return result;
}

- (NSAttributedString *) attributedStringForObjectValue:(id)object withDefaultAttributes:(NSDictionary *)attributes
{
	NSString *stringValue = [self stringForObjectValue:object];
	if(nil == stringValue)
		return nil;
	
	NSAttributedString *result = [[NSAttributedString alloc] initWithString:stringValue attributes:attributes];
	return [result autorelease];
}

@end
