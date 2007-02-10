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

#import "WavPackMetadataWriter.h"
#import "AudioStream.h"
#include <wavpack/wavpack.h>

@implementation WavPackMetadataWriter

- (BOOL) writeMetadata:(id)metadata error:(NSError **)error
{
	NSString						*path				= [_url path];
    WavpackContext					*wpc				= NULL;
	char							errorBuf [80];
	int								result;
	
	wpc		= WavpackOpenFileInput([path fileSystemRepresentation], errorBuf, OPEN_EDIT_TAGS, 0);

	if(NULL == wpc) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid WavPack file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not a WavPack file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
														  code:AudioMetadataWriterFileFormatNotRecognizedError 
													  userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	// Album title
	NSString *album = [metadata valueForKey:@"albumTitle"];
	WavpackDeleteTagItem(wpc, "ALBUM");
	if(nil != album) {
		WavpackAppendTagItem(wpc, "ALBUM", [album UTF8String], strlen([album UTF8String]));
	}
	
	// Artist
	NSString *artist = [metadata valueForKey:@"artist"];
	WavpackDeleteTagItem(wpc, "ARTIST");
	if(nil != artist) {
		WavpackAppendTagItem(wpc, "ARTIST", [artist UTF8String], strlen([artist UTF8String]));
	}
	
	// Composer
	NSString *composer = [metadata valueForKey:@"composer"];
	WavpackDeleteTagItem(wpc, "COMPOSER");
	if(nil != composer) {
		WavpackAppendTagItem(wpc, "COMPOSER", [composer UTF8String], strlen([composer UTF8String]));
	}
	
	// Genre
	NSString *genre = [metadata valueForKey:@"genre"];
	WavpackDeleteTagItem(wpc, "GENRE");
	if(nil != genre) {
		WavpackAppendTagItem(wpc, "GENRE", [genre UTF8String], strlen([genre UTF8String]));
	}
	
	// Date
	NSString *year = [metadata valueForKey:@"date"];
	WavpackDeleteTagItem(wpc, "YEAR");
	if(nil != year) {
		WavpackAppendTagItem(wpc, "YEAR", [year UTF8String], strlen([year UTF8String]));
	}
	
	// Comment
	NSString *comment			= [metadata valueForKey:@"comment"];
	WavpackDeleteTagItem(wpc, "COMMENT");
	if(nil != comment) {
		WavpackAppendTagItem(wpc, "COMMENT", [comment UTF8String], strlen([comment UTF8String]));
	}
	
	// Track title
	NSString *title = [metadata valueForKey:@"title"];
	WavpackDeleteTagItem(wpc, "TITLE");
	if(nil != title) {
		WavpackAppendTagItem(wpc, "TITLE", [title UTF8String], strlen([title UTF8String]));
	}
	
	// Track number
	NSNumber *trackNumber	= [metadata valueForKey:@"trackNumber"];
	WavpackDeleteTagItem(wpc, "TRACK");
	if(nil != trackNumber) {
		WavpackAppendTagItem(wpc, "TRACK", [[trackNumber stringValue] UTF8String], strlen([[trackNumber stringValue] UTF8String]));
	}
	
	// Track total
	NSNumber *trackTotal		= [metadata valueForKey:@"trackTotal"];
	WavpackDeleteTagItem(wpc, "TRACKTOTAL");
	if(nil != trackTotal) {
		WavpackAppendTagItem(wpc, "TRACKTOTAL", [[trackTotal stringValue] UTF8String], strlen([[trackTotal stringValue] UTF8String]));
	}
	
	// Disc number
	NSNumber *discNumber	= [metadata valueForKey:@"discNumber"];
	WavpackDeleteTagItem(wpc, "DISCNUMBER");
	if(nil != discNumber) {
		WavpackAppendTagItem(wpc, "DISCNUMBER", [[discNumber stringValue] UTF8String], strlen([[discNumber stringValue] UTF8String]));
	}
	
	// Discs in set
	NSNumber *discTotal	= [metadata valueForKey:@"discTotal"];
	WavpackDeleteTagItem(wpc, "DISCTOTAL");
	if(nil != discTotal) {
		WavpackAppendTagItem(wpc, "DISCTOTAL", [[discTotal stringValue] UTF8String], strlen([[discTotal stringValue] UTF8String]));
	}
	
	// Compilation
	NSNumber *compilation	= [metadata valueForKey:@"compilation"];
	WavpackDeleteTagItem(wpc, "COMPILATION");
	if(nil != compilation) {
		WavpackAppendTagItem(wpc, "COMPILATION", [[compilation stringValue] UTF8String], strlen([[compilation stringValue] UTF8String]));
	}
	
	// ISRC
	NSString *isrc = [metadata valueForKey:@"isrc"];
	WavpackDeleteTagItem(wpc, "ISRC");
	if(nil != isrc) {
		WavpackAppendTagItem(wpc, "ISRC", [isrc UTF8String], strlen([isrc UTF8String]));
	}
	
	// MCN
	NSString *mcn = [metadata valueForKey:@"mcn"];
	WavpackDeleteTagItem(wpc, "MCN");
	if(nil != mcn) {
		WavpackAppendTagItem(wpc, "MCN", [mcn UTF8String], strlen([mcn UTF8String]));
	}
		
	result	= WavpackWriteTag(wpc);

	if(NO == result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [_url path];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid WavPack file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not a WavPack file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
														  code:AudioMetadataWriterInputOutputError 
													  userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	wpc		= WavpackCloseFile(wpc);
	if(NULL != wpc) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [_url path];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid WavPack file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not a WavPack file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
														  code:AudioMetadataWriterInputOutputError 
													  userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	return YES;
}

@end
