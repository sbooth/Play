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

#import "SQLiteUtilityFunctions.h"
#import "DatabaseObject.h"

// ========================================
// Bind a parameter in an SQL statement to a KVC object value
void
bindParameter(sqlite3_stmt		*statement, 
			  int				parameterIndex,
			  id				kvcObject, 
			  NSString			*key,
			  eObjectType		objectType)
{
	NSCParameterAssert(NULL != statement);
	NSCParameterAssert(0 < parameterIndex);
	NSCParameterAssert(nil != kvcObject);
	NSCParameterAssert(nil != key);
	
	int		result		= SQLITE_OK;
	id		value		= [kvcObject valueForKey:key];
	
	if(nil == value)
		result = sqlite3_bind_null(statement, parameterIndex);
	else {
		switch(objectType) {
			case eObjectTypeURL:	
				result = sqlite3_bind_text(statement, parameterIndex, [[value absoluteString] UTF8String], -1, SQLITE_TRANSIENT);	
				break;
			case eObjectTypeString:	
				result = sqlite3_bind_text(statement, parameterIndex, [value UTF8String], -1, SQLITE_TRANSIENT);	
				break;
			case eObjectTypeDate:	
				result = sqlite3_bind_double(statement, parameterIndex, [value timeIntervalSinceReferenceDate]);	
				break;
			case eObjectTypeBool:	
				result = sqlite3_bind_int(statement, parameterIndex, [value boolValue]);	
				break;
			case eObjectTypeUnsignedShort:
				result = sqlite3_bind_int(statement, parameterIndex, [value unsignedShortValue]);	
				break;
			case eObjectTypeShort:
				result = sqlite3_bind_int(statement, parameterIndex, [value shortValue]);	
				break;
			case eObjectTypeUnsignedInt:	
				result = sqlite3_bind_int(statement, parameterIndex, [value unsignedIntValue]);	
				break;
			case eObjectTypeInt:	
				result = sqlite3_bind_int(statement, parameterIndex, [value intValue]);	
				break;
			case eObjectTypeUnsignedLong:
				result = sqlite3_bind_int(statement, parameterIndex, [value unsignedLongValue]);
				break;
			case eObjectTypeLong:
				result = sqlite3_bind_int(statement, parameterIndex, [value longValue]);
				break;
			case eObjectTypeUnsignedLongLong:
				result = sqlite3_bind_int64(statement, parameterIndex, [value unsignedLongLongValue]);
				break;
			case eObjectTypeLongLong:
				result = sqlite3_bind_int64(statement, parameterIndex, [value longLongValue]);	
				break;
			case eObjectTypeFloat:	
				result = sqlite3_bind_double(statement, parameterIndex, [value floatValue]);
				break;
			case eObjectTypeDouble:	
				result = sqlite3_bind_double(statement, parameterIndex, [value doubleValue]);	
				break;
			case eObjectTypePredicate:	
				result = sqlite3_bind_text(statement, parameterIndex, [[value predicateFormat] UTF8String], -1, SQLITE_TRANSIENT);	
				break;
			default:
				result = SQLITE_ERROR;
				break;
		}
	}
	
	NSCAssert1(SQLITE_OK == result, @"Unable to bind parameter %i to sql statement.", parameterIndex/*, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]*/);
}

// ========================================
// Bind a named parameter in an SQL statement to a KVC object value
void
bindNamedParameter(sqlite3_stmt		*statement, 
				   const char		*parameterName,
				   id				kvcObject, 
				   NSString			*key,
				   eObjectType		objectType)
{
	NSCParameterAssert(NULL != statement);
	NSCParameterAssert(NULL != parameterName);
	NSCParameterAssert(nil != kvcObject);
	NSCParameterAssert(nil != key);
	
	int		result			= SQLITE_OK;
	id		value			= [kvcObject valueForKey:key];
	int		parameterIndex	= sqlite3_bind_parameter_index(statement, parameterName);
	
	NSCAssert1(0 < parameterIndex, @"Invalid parameter name \"%@\"", parameterName);
	
	if(nil == value)
		result = sqlite3_bind_null(statement, parameterIndex);
	else {
		switch(objectType) {
			case eObjectTypeURL:	
				result = sqlite3_bind_text(statement, parameterIndex, [[value absoluteString] UTF8String], -1, SQLITE_TRANSIENT);	
				break;
			case eObjectTypeString:	
				result = sqlite3_bind_text(statement, parameterIndex, [value UTF8String], -1, SQLITE_TRANSIENT);	
				break;
			case eObjectTypeDate:	
				result = sqlite3_bind_double(statement, parameterIndex, [value timeIntervalSinceReferenceDate]);	
				break;
			case eObjectTypeBool:	
				result = sqlite3_bind_int(statement, parameterIndex, [value boolValue]);	
				break;
			case eObjectTypeUnsignedShort:	
				result = sqlite3_bind_int(statement, parameterIndex, [value unsignedShortValue]);	
				break;
			case eObjectTypeShort:	
				result = sqlite3_bind_int(statement, parameterIndex, [value shortValue]);
				break;
			case eObjectTypeUnsignedInt:	
				result = sqlite3_bind_int(statement, parameterIndex, [value unsignedIntValue]);	
				break;
			case eObjectTypeInt:	
				result = sqlite3_bind_int(statement, parameterIndex, [value intValue]);	
				break;
			case eObjectTypeUnsignedLong:
				result = sqlite3_bind_int(statement, parameterIndex, [value unsignedLongValue]);	
				break;
			case eObjectTypeLong:
				result = sqlite3_bind_int(statement, parameterIndex, [value longValue]);	
				break;
			case eObjectTypeUnsignedLongLong:
				result = sqlite3_bind_int64(statement, parameterIndex, [value unsignedLongLongValue]);	
				break;
			case eObjectTypeLongLong:
				result = sqlite3_bind_int64(statement, parameterIndex, [value longLongValue]);
				break;
			case eObjectTypeFloat:	
				result = sqlite3_bind_double(statement, parameterIndex, [value floatValue]);
				break;
			case eObjectTypeDouble:	
				result = sqlite3_bind_double(statement, parameterIndex, [value doubleValue]);	
				break;
			case eObjectTypePredicate:	
				result = sqlite3_bind_text(statement, parameterIndex, [[value predicateFormat] UTF8String], -1, SQLITE_TRANSIENT);	
				break;
			default:
				result = SQLITE_ERROR;
				break;
		}
	}
	
	NSCAssert1(SQLITE_OK == result, @"Unable to bind parameter \"%s\" to sql statement.", parameterName/*, [NSString stringWithUTF8String:sqlite3_errmsg(_db)]*/);
}

// ========================================
// Extract a column entry in a table to DatabaseObject
void
getColumnValue(sqlite3_stmt		*statement, 
			   int				columnIndex,
			   DatabaseObject	*object, 
			   NSString			*key,
			   eObjectType		desiredObjectType)
{
	NSCParameterAssert(NULL != statement);
	NSCParameterAssert(0 <= columnIndex);
	NSCParameterAssert(nil != object);
	NSCParameterAssert(nil != key);
	
	// Handle database nulls as NSNull
	if(SQLITE_NULL == sqlite3_column_type(statement, columnIndex)) {
		[object initValue:[NSNull null] forKey:key];
		return;
	}

	switch(desiredObjectType) {
		case eObjectTypeURL:	
			[object initValue:[NSURL URLWithString:[NSString stringWithCString:(const char *)sqlite3_column_text(statement, columnIndex) encoding:NSUTF8StringEncoding]] forKey:key];
			break;
		case eObjectTypeString:	
			[object initValue:[NSString stringWithCString:(const char *)sqlite3_column_text(statement, columnIndex) encoding:NSUTF8StringEncoding] forKey:key];
			break;
		case eObjectTypeDate:
			[object initValue:[NSDate dateWithTimeIntervalSinceReferenceDate:sqlite3_column_double(statement, columnIndex)] forKey:key];
			break;
		case eObjectTypeBool:
			[object initValue:[NSNumber numberWithBool:sqlite3_column_int(statement, columnIndex)] forKey:key];
			break;
		case eObjectTypeUnsignedShort:
			[object initValue:[NSNumber numberWithUnsignedShort:sqlite3_column_int(statement, columnIndex)] forKey:key];
			break;
		case eObjectTypeShort:	
			[object initValue:[NSNumber numberWithShort:sqlite3_column_int(statement, columnIndex)] forKey:key];
			break;
		case eObjectTypeUnsignedInt:
			[object initValue:[NSNumber numberWithUnsignedInt:sqlite3_column_int(statement, columnIndex)] forKey:key];
			break;
		case eObjectTypeInt:	
			[object initValue:[NSNumber numberWithInt:sqlite3_column_int(statement, columnIndex)] forKey:key];
			break;
		case eObjectTypeUnsignedLong:	
			[object initValue:[NSNumber numberWithUnsignedLong:sqlite3_column_int(statement, columnIndex)] forKey:key];
			break;
		case eObjectTypeLong:	
			[object initValue:[NSNumber numberWithLong:sqlite3_column_int(statement, columnIndex)] forKey:key];
			break;
		case eObjectTypeUnsignedLongLong:	
			[object initValue:[NSNumber numberWithUnsignedLongLong:sqlite3_column_int64(statement, columnIndex)] forKey:key];
			break;
		case eObjectTypeLongLong:	
			[object initValue:[NSNumber numberWithLongLong:sqlite3_column_int64(statement, columnIndex)] forKey:key];
			break;
		case eObjectTypeFloat:	
			[object initValue:[NSNumber numberWithFloat:sqlite3_column_double(statement, columnIndex)] forKey:key];
			break;
		case eObjectTypeDouble:	
			[object initValue:[NSNumber numberWithDouble:sqlite3_column_double(statement, columnIndex)] forKey:key];
			break;
		case eObjectTypePredicate:	
			[object initValue:[NSPredicate predicateWithFormat:[NSString stringWithCString:(const char *)sqlite3_column_text(statement, columnIndex) encoding:NSUTF8StringEncoding]] forKey:key];
			break;
		default:
			break;
	}
}
