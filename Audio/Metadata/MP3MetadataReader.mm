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

#import "MP3MetadataReader.h"
#include <taglib/mpegfile.h>
#include <taglib/id3v2tag.h>
#include <taglib/id3v2frame.h>
#include <taglib/attachedpictureframe.h>

@implementation MP3MetadataReader

- (BOOL) readMetadata:(NSError **)error
{
	NSMutableDictionary						*metadataDictionary;
	NSString								*path				= [_url path];
	TagLib::MPEG::File						f					([path fileSystemRepresentation], false);
	TagLib::ID3v2::AttachedPictureFrame		*picture			= NULL;
	TagLib::String							s;
	TagLib::ID3v2::Tag						*id3v2tag;
	NSString								*trackString, *trackNum, *totalTracks;
	NSString								*discString, *discNum, *totalDiscs;
	NSRange									range;
	
	if(NO == f.isValid()) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid MP3 file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not an MP3 file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioMetadataReaderErrorDomain 
														  code:AudioMetadataReaderFileFormatNotRecognizedError 
													  userInfo:errorDictionary];
		}
	
		return NO;
	}
	
	metadataDictionary			= [NSMutableDictionary dictionary];

	// Album title
	s = f.tag()->album();
	if(false == s.isNull()) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:@"albumTitle"];
	}
	
	// Artist
	s = f.tag()->artist();
	if(false == s.isNull()) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:@"artist"];
	}
	
	// Genre
	s = f.tag()->genre();
	if(false == s.isNull()) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:@"genre"];
	}
	
	// Year
	if(0 != f.tag()->year()) {
//			[result setAlbumYear:f.tag()->year()];
	}
	
	// Comment
	s = f.tag()->comment();
	if(false == s.isNull()) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:@"comment"];
	}
	
	// Track title
	s = f.tag()->title();
	if(false == s.isNull()) {
		[metadataDictionary setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:@"title"];
	}
	
	// Track number
	if(0 != f.tag()->track()) {
		[metadataDictionary setValue:[NSNumber numberWithInt:f.tag()->track()] forKey:@"trackNumber"];
	}
			
	id3v2tag = f.ID3v2Tag();
	
	if(NULL != id3v2tag) {
		
		// Extract composer if present
		TagLib::ID3v2::FrameList frameList = id3v2tag->frameListMap()["TCOM"];
		if(NO == frameList.isEmpty()) {
			[metadataDictionary setValue:[NSString stringWithUTF8String:frameList.front()->toString().toCString(true)] forKey:@"composer"];
		}
		
		// Extract total tracks if present
		frameList = id3v2tag->frameListMap()["TRCK"];
		if(NO == frameList.isEmpty()) {
			// Split the tracks at '/'
			trackString		= [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
			range			= [trackString rangeOfString:@"/" options:NSLiteralSearch];

			if(NSNotFound != range.location && 0 != range.length) {
				trackNum		= [trackString substringToIndex:range.location];
				totalTracks		= [trackString substringFromIndex:range.location + 1];
				
				[metadataDictionary setValue:[NSNumber numberWithInt:[trackNum intValue]] forKey:@"trackNumber"];
				[metadataDictionary setValue:[NSNumber numberWithInt:[totalTracks intValue]] forKey:@"trackTotal"];
			}
			else if(0 != [trackString length]) {
				[metadataDictionary setValue:[NSNumber numberWithInt:[trackString intValue]] forKey:@"trackNumber"];
			}
		}
		
		// Extract disc number and total discs
		frameList = id3v2tag->frameListMap()["TPOS"];
		if(NO == frameList.isEmpty()) {
			// Split the tracks at '/'
			discString		= [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
			range			= [discString rangeOfString:@"/" options:NSLiteralSearch];
			
			if(NSNotFound != range.location && 0 != range.length) {
				discNum			= [discString substringToIndex:range.location];
				totalDiscs		= [discString substringFromIndex:range.location + 1];
				
				[metadataDictionary setValue:[NSNumber numberWithInt:[discNum intValue]] forKey:@"discNumber"];
				[metadataDictionary setValue:[NSNumber numberWithInt:[totalDiscs intValue]] forKey:@"discTotal"];
			}
			else if(0 != [discString length]) {
				[metadataDictionary setValue:[NSNumber numberWithInt:[discString intValue]] forKey:@"discNumber"];
			}
		}
		
		// Extract album art if present
		frameList = id3v2tag->frameListMap()["APIC"];
		if(NO == frameList.isEmpty() && NULL != (picture = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(frameList.front()))) {
			TagLib::ByteVector bv = picture->picture();
//				[result setAlbumArt:[[[NSImage alloc] initWithData:[NSData dataWithBytes:bv.data() length:bv.size()]] autorelease]];
		}
		
		// Extract compilation if present (iTunes TCMP tag)
		frameList = id3v2tag->frameListMap()["TCMP"];
		if(NO == frameList.isEmpty()) {
			// Is it safe to assume this will only be 0 or 1?  (Probably not, it never is)
			NSString *value = [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
			[metadataDictionary setValue:[NSNumber numberWithBool:[value intValue]] forKey:@"partOfCompilation"];
		}			
	}
	
	[self setValue:metadataDictionary forKey:@"metadata"];
	
	return YES;
}

@end
