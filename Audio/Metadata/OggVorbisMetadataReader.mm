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

#import "OggVorbisMetadataReader.h"
#include <taglib/vorbisfile.h>
#include <taglib/xiphcomment.h>

@implementation OggVorbisMetadataReader

- (BOOL) readMetadata:(NSError **)error
{
	NSMutableDictionary				*metadataDictionary;
	TagLib::Ogg::Vorbis::File		f						([[_url path] fileSystemRepresentation], false);
	TagLib::String					s;
	TagLib::Ogg::XiphComment		*xiphComment;
	BOOL							result;

	if(f.isValid()) {
		
		metadataDictionary			= [NSMutableDictionary dictionary];
		result						= YES;
		xiphComment					= f.tag();

		if(NULL != xiphComment) {
			TagLib::Ogg::FieldListMap		fieldList	= xiphComment->fieldListMap();
			NSString						*value		= nil;
			TagLib::String					tag;
			
			tag = "ALBUM";
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[metadataDictionary setValue:value forKey:@"albumTitle"];
			}
			
			tag = "ARTIST";
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[metadataDictionary setValue:value forKey:@"artist"];
			}
			
			tag = "GENRE";
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[metadataDictionary setValue:value forKey:@"genre"];
			}
			
			tag = "DATE";
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
//				[metadataDictionary setValue:value forKey:@"date"];
			}
			
			tag = "DESCRIPTION";
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
//				[metadataDictionary setValue:value forKey:@"comment"];
			}
			
			tag = "TITLE";
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[metadataDictionary setValue:value forKey:@"title"];
			}
			
			tag = "TRACKNUMBER";
			if(fieldList.contains(tag)) {
				value = [NSNumber numberWithInt:[[NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)] intValue]];
				[metadataDictionary setValue:value forKey:@"trackNumber"];
			}
			
			tag = "COMPOSER";
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[metadataDictionary setValue:value forKey:@"composer"];
			}
			
			tag = "TRACKTOTAL";
			if(fieldList.contains(tag)) {
				value = [NSNumber numberWithInt:[[NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)] intValue]];
				[metadataDictionary setValue:value forKey:@"trackTotal"];
			}
			
			tag = "DISCNUMBER";
			if(fieldList.contains(tag)) {
				value = [NSNumber numberWithInt:[[NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)] intValue]];
				[metadataDictionary setValue:value forKey:@"discNumber"];
			}
			
			tag = "DISCTOTAL";
			if(fieldList.contains(tag)) {
				value = [NSNumber numberWithInt:[[NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)] intValue]];
				[metadataDictionary setValue:value forKey:@"discTotal"];
			}
			
			tag = "COMPILATION";
			if(fieldList.contains(tag)) {
				value = [NSNumber numberWithBool:[[NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)] intValue]];
				[metadataDictionary setValue:value forKey:@"partOfCompilation"];
			}
			
			tag = "ISRC";
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[metadataDictionary setValue:value forKey:@"isrc"];
			}					
			
			tag = "MCN";
			if(fieldList.contains(tag)) {
				value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
				[metadataDictionary setValue:value forKey:@"mcn"];
			}					
		}		
		
		[self setValue:metadataDictionary forKey:@"metadata"];
	}
	else {
		result = NO;
	}

	return result;
}

@end
