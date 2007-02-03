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

#import "MonkeysAudioMetadataWriter.h"
#include <mac/All.h>
#include <mac/MACLib.h>
#include <mac/APETag.h>
#include <mac/CharacterHelper.h>

static void setField(CAPETag		*f, 
					 const char		*name, 
					 NSString		*value)
{
	str_utf16		*fieldName		= NULL;

	fieldName		= GetUTF16FromANSI(name);
	NSCAssert(NULL != fieldName, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	
	f->RemoveField(fieldName);
	
	if(nil != value) {
		f->SetFieldString(fieldName, [value UTF8String], TRUE);
	}
	
	free(fieldName);
}

@implementation MonkeysAudioMetadataWriter

- (BOOL) writeMetadata:(id)metadata error:(NSError **)error
{
	NSString				*path				= [_url path];
	str_utf16				*chars				= NULL;
	CAPETag					*f					= NULL;
	int						result;
	
	chars = GetUTF16FromANSI([path fileSystemRepresentation]);
	NSAssert(NULL != chars, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	
	f = new CAPETag(chars);
	NSAssert(NULL != f, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	
	if(NULL == f) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid Monkey's Audio file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not a Monkey's Audio file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
														  code:AudioMetadataWriterFileFormatNotRecognizedError 
													  userInfo:errorDictionary];
		}
		
		free(chars);
		
		return NO;
	}
	
	// Album title
	NSString *album = [metadata valueForKey:@"albumTitle"];
	setField(f, "ALBUM", album);
	
	// Artist
	NSString *artist = [metadata valueForKey:@"artist"];
	setField(f, "ARTIST", artist);
	
	// Composer
	NSString *composer = [metadata valueForKey:@"composer"];
	setField(f, "COMPOSER", composer);
	
	// Genre
	NSString *genre = [metadata valueForKey:@"genre"];
	setField(f, "GENRE", genre);
	
	// Date
	NSString *year = [metadata valueForKey:@"date"];
	setField(f, "YEAR", year);
	
	// Comment
	NSString *comment			= [metadata valueForKey:@"comment"];
	setField(f, "COMMENT", comment);
	
	// Track title
	NSString *title = [metadata valueForKey:@"title"];
	setField(f, "TITLE", title);
	
	// Track number
	NSNumber *trackNumber	= [metadata valueForKey:@"trackNumber"];
	setField(f, "TRACK", [trackNumber stringValue]);
	
	// Track total
	NSNumber *trackTotal		= [metadata valueForKey:@"trackTotal"];
	setField(f, "TRACKTOTAL", [trackTotal stringValue]);
	
	// Disc number
	NSNumber *discNumber	= [metadata valueForKey:@"discNumber"];
	setField(f, "DISCNUMBER", [discNumber stringValue]);
	
	// Discs in set
	NSNumber *discTotal	= [metadata valueForKey:@"discTotal"];
	setField(f, "DISCTOTAL", [discTotal stringValue]);
	
	// Compilation
	NSNumber *compilation	= [metadata valueForKey:@"compilation"];
	setField(f, "COMPILATION", [compilation stringValue]);
	
	// ISRC
	NSString *isrc = [metadata valueForKey:@"isrc"];
	setField(f, "ISRC", isrc);
	
	// MCN
	NSString *mcn = [metadata valueForKey:@"mcn"];
	setField(f, "MCN", mcn);
	
	result = f->Save();
	if(ERROR_SUCCESS != result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [_url path];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid Monkey's Audio file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not a Monkey's Audio file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
														  code:AudioMetadataWriterInputOutputError 
													  userInfo:errorDictionary];
		}

		delete f;
		free(chars);
		
		return NO;
	}

	delete f;
	free(chars);
	
	return YES;
}

@end
