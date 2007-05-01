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
#import "AudioStream.h"
#include <mac/All.h>
#include <mac/MACLib.h>
#include <mac/APETag.h>
#include <mac/CharacterHelper.h>

static void setField(CAPETag		*f, 
					 const char		*name, 
					 NSString		*value)
{
	str_utf16 *fieldName = GetUTF16FromANSI(name);
	NSCAssert(NULL != fieldName, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	
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
	NSAssert(NULL != chars, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	
	f = new CAPETag(chars);
	NSAssert(NULL != f, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	
	if(NULL == f) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Monkey's Audio file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a Monkey's Audio file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
										 code:AudioMetadataWriterFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		free(chars);
		
		return NO;
	}
	
	// Album title
	NSString *album = [metadata valueForKey:MetadataAlbumTitleKey];
	setField(f, "ALBUM", album);
	
	// Artist
	NSString *artist = [metadata valueForKey:MetadataArtistKey];
	setField(f, "ARTIST", artist);
	
	// Composer
	NSString *composer = [metadata valueForKey:MetadataComposerKey];
	setField(f, "COMPOSER", composer);
	
	// Genre
	NSString *genre = [metadata valueForKey:MetadataGenreKey];
	setField(f, "GENRE", genre);

	// Genre
	NSNumber *bpm = [metadata valueForKey:MetadataBPMKey];
	setField(f, "BPM", [bpm stringValue]);
	
	// Date
	NSString *year = [metadata valueForKey:MetadataDateKey];
	setField(f, "YEAR", year);
	
	// Comment
	NSString *comment = [metadata valueForKey:MetadataCommentKey];
	setField(f, "COMMENT", comment);
	
	// Track title
	NSString *title = [metadata valueForKey:MetadataTitleKey];
	setField(f, "TITLE", title);
	
	// Track number
	NSNumber *trackNumber = [metadata valueForKey:MetadataTrackNumberKey];
	setField(f, "TRACK", [trackNumber stringValue]);
	
	// Track total
	NSNumber *trackTotal = [metadata valueForKey:MetadataTrackTotalKey];
	setField(f, "TRACKTOTAL", [trackTotal stringValue]);
	
	// Disc number
	NSNumber *discNumber = [metadata valueForKey:MetadataDiscNumberKey];
	setField(f, "DISCNUMBER", [discNumber stringValue]);
	
	// Discs in set
	NSNumber *discTotal	= [metadata valueForKey:MetadataDiscTotalKey];
	setField(f, "DISCTOTAL", [discTotal stringValue]);
	
	// Compilation
	NSNumber *compilation = [metadata valueForKey:MetadataCompilationKey];
	setField(f, "COMPILATION", [compilation stringValue]);
	
	// ISRC
	NSString *isrc = [metadata valueForKey:MetadataISRCKey];
	setField(f, "ISRC", isrc);
	
	// MCN
	NSString *mcn = [metadata valueForKey:MetadataMCNKey];
	setField(f, "MCN", mcn);
	
	result = f->Save();
	if(ERROR_SUCCESS != result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [_url path];
						
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Monkey's Audio file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a Monkey's Audio file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
										 code:AudioMetadataWriterFileFormatNotRecognizedError 
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
