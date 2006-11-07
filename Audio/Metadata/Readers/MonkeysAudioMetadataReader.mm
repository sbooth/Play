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

#import "MonkeysAudioMetadataReader.h"
#include <mac/All.h>
#include <mac/MACLib.h>
#include <mac/APETag.h>
#include <mac/CharacterHelper.h>

@implementation MonkeysAudioMetadataReader

- (BOOL) readMetadata:(NSError **)error
{
	NSMutableDictionary				*metadataDictionary;
	NSString						*path;
	str_utf16						*chars					= NULL;
	str_utf16						*tagName				= NULL;
	CAPETag							*f						= NULL;
	CAPETagField					*tag					= NULL;		
	
	path							= [[self valueForKey:@"url"] path];

	chars = GetUTF16FromANSI([path fileSystemRepresentation]);
	NSAssert(NULL != chars, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	
	f = new CAPETag(chars);
	NSAssert(NULL != f, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

	metadataDictionary			= [NSMutableDictionary dictionary];

	// Album title
	tagName		= GetUTF16FromANSI("ALBUM");
	NSAssert(NULL != tagName, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	tag			= f->GetTagField(tagName);
	if(NULL != tag && tag->GetIsUTF8Text()) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:tag->GetFieldValue()] forKey:@"albumTitle"];
	}
	free(tagName);
	
	// Artist
	tagName		= GetUTF16FromANSI("ARTIST");
	NSAssert(NULL != tagName, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	tag			= f->GetTagField(tagName);
	if(NULL != tag && tag->GetIsUTF8Text()) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:tag->GetFieldValue()] forKey:@"artist"];
	}
	free(tagName);
	
	// Composer
	tagName		= GetUTF16FromANSI("COMPOSER");
	NSAssert(NULL != tagName, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	tag			= f->GetTagField(tagName);
	if(NULL != tag && tag->GetIsUTF8Text()) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:tag->GetFieldValue()] forKey:@"composer"];
	}
	free(tagName);
	
	// Genre
	tagName		= GetUTF16FromANSI("GENRE");
	NSAssert(NULL != tagName, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	tag			= f->GetTagField(tagName);
	if(NULL != tag && tag->GetIsUTF8Text()) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:tag->GetFieldValue()] forKey:@"genre"];
	}
	free(tagName);
	
	// Year
	tagName		= GetUTF16FromANSI("YEAR");
	NSAssert(NULL != tagName, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	tag			= f->GetTagField(tagName);
	if(NULL != tag && tag->GetIsUTF8Text()) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:tag->GetFieldValue()] forKey:@"date"];
	}
	free(tagName);
	
	// Comment
	tagName		= GetUTF16FromANSI("COMMENT");
	NSAssert(NULL != tagName, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	tag			= f->GetTagField(tagName);
	if(NULL != tag && tag->GetIsUTF8Text()) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:tag->GetFieldValue()] forKey:@"comment"];
	}
	free(tagName);
	
	// Track title
	tagName		= GetUTF16FromANSI("TITLE");
	NSAssert(NULL != tagName, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	tag			= f->GetTagField(tagName);
	if(NULL != tag && tag->GetIsUTF8Text()) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:tag->GetFieldValue()] forKey:@"title"];
	}
	free(tagName);
	
	// Track number
	tagName		= GetUTF16FromANSI("TRACK");
	NSAssert(NULL != tagName, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	tag			= f->GetTagField(tagName);
	if(NULL != tag && tag->GetIsUTF8Text()) {
		[metadataDictionary setValue:[NSNumber numberWithInt:[[NSString stringWithUTF8String:tag->GetFieldValue()] intValue]] forKey:@"trackNumber"];
	}
	free(tagName);
	
	// Track total
	tagName		= GetUTF16FromANSI("TRACKTOTAL");
	NSAssert(NULL != tagName, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	tag			= f->GetTagField(tagName);
	if(NULL != tag && tag->GetIsUTF8Text()) {
		[metadataDictionary setValue:[NSNumber numberWithInt:[[NSString stringWithUTF8String:tag->GetFieldValue()] intValue]] forKey:@"trackTotal"];
	}
	free(tagName);
	
	// Disc number
	tagName		= GetUTF16FromANSI("DISCNUMBER");
	NSAssert(NULL != tagName, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	tag			= f->GetTagField(tagName);
	if(NULL != tag && tag->GetIsUTF8Text()) {
		[metadataDictionary setValue:[NSNumber numberWithInt:[[NSString stringWithUTF8String:tag->GetFieldValue()] intValue]] forKey:@"discNumber"];
	}
	free(tagName);
	
	// Discs in set
	tagName		= GetUTF16FromANSI("DISCTOTAL");
	NSAssert(NULL != tagName, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	tag			= f->GetTagField(tagName);
	if(NULL != tag && tag->GetIsUTF8Text()) {
		[metadataDictionary setValue:[NSNumber numberWithInt:[[NSString stringWithUTF8String:tag->GetFieldValue()] intValue]] forKey:@"discTotal"];
	}
	free(tagName);
	
	// Compilation
	tagName		= GetUTF16FromANSI("COMPILATION");
	NSAssert(NULL != tagName, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	tag			= f->GetTagField(tagName);
	if(NULL != tag && tag->GetIsUTF8Text()) {
		[metadataDictionary setValue:[NSNumber numberWithBool:(BOOL)[[NSString stringWithUTF8String:tag->GetFieldValue()] intValue]] forKey:@"partOfCompilation"];
	}
	free(tagName);
	
	// ISRC
	tagName		= GetUTF16FromANSI("ISRC");
	NSAssert(NULL != tagName, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	tag			= f->GetTagField(tagName);
	if(NULL != tag && tag->GetIsUTF8Text()) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:tag->GetFieldValue()] forKey:@"isrc"];
	}
	free(tagName);
	
	// MCN
	tagName		= GetUTF16FromANSI("MCN");
	NSAssert(NULL != tagName, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	tag			= f->GetTagField(tagName);
	if(NULL != tag && tag->GetIsUTF8Text()) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:tag->GetFieldValue()] forKey:@"mcn"];
	}
	free(tagName);
	
	delete f;
	free(chars);
	
	[self setValue:metadataDictionary forKey:@"metadata"];
	
	return YES;
}

@end