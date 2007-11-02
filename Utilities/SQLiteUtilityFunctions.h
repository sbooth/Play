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

#import <Cocoa/Cocoa.h>
#include "sqlite3.h"

#ifdef __cplusplus
extern "C" {
#endif

	@class DatabaseObject;
	
	enum _eObjectType {
		eObjectTypeURL,
		eObjectTypeString,
		eObjectTypeDate,
		eObjectTypeBool,
		eObjectTypeUnsignedShort,
		eObjectTypeShort,
		eObjectTypeUnsignedInt,
		eObjectTypeInt,
		eObjectTypeUnsignedLong,
		eObjectTypeLong,
		eObjectTypeUnsignedLongLong,
		eObjectTypeLongLong,
		eObjectTypeFloat,
		eObjectTypeDouble,
		eObjectTypePredicate
	};
	typedef enum _eObjectType eObjectType;

	// ========================================
	// Bind a parameter in an SQL statement to a KVC object value
	void
	bindParameter(sqlite3_stmt		*statement, 
				  int				parameterIndex,
				  id				kvcObject, 
				  NSString			*key,
				  eObjectType		objectType);

	// ========================================
	// Bind a named parameter in an SQL statement to a KVC object value
	void
	bindNamedParameter(sqlite3_stmt		*statement, 
					   const char		*parameterName,
					   id				kvcObject, 
					   NSString			*key,
					   eObjectType		objectType);

	// ========================================
	// Extract a column entry in a table to DatabaseObject
	void
	getColumnValue(sqlite3_stmt		*statement, 
				   int				columnIndex,
				   DatabaseObject	*object, 
				   NSString			*key,
				   eObjectType		desiredObjectType);

#ifdef __cplusplus
}
#endif
