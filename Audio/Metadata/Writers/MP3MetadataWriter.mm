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

#import "MP3MetadataWriter.h"
#import "Genres.h"
#import "UtilityFunctions.h"

#include <taglib/mpegfile.h>
#include <taglib/tag.h>
#include <taglib/tstring.h>
#include <taglib/tbytevector.h>
#include <taglib/textidentificationframe.h>
#include <taglib/attachedpictureframe.h>
#include <taglib/id3v2tag.h>

@implementation MP3MetadataWriter

- (BOOL) writeMetadata:(id)metadata error:(NSError **)error
{
	NSString						*path				= [_url path];
	TagLib::MPEG::File				f					([path fileSystemRepresentation], false);
	TagLib::ID3v2::TextIdentificationFrame		*frame					= NULL;
	bool							result;
	
	if(NO == f.isValid()) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid MP3 file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not an MP3 file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
														  code:AudioMetadataWriterFileFormatNotRecognizedError 
													  userInfo:errorDictionary];
		}
		
		return NO;
	}

	// Use UTF-8 as the default encoding
	(TagLib::ID3v2::FrameFactory::instance())->setDefaultTextEncoding(TagLib::String::UTF8);

	// Album title
	NSString *album = [metadata valueForKey:@"albumTitle"];
	if(nil != album) {
		f.tag()->setAlbum(TagLib::String([album UTF8String], TagLib::String::UTF8));
	}
	
	// Artist
	NSString *artist = [metadata valueForKey:@"artist"];
	if(nil != artist) {
		f.tag()->setArtist(TagLib::String([artist UTF8String], TagLib::String::UTF8));
	}
	
	// Composer
	NSString *composer = [metadata valueForKey:@"composer"];
	if(nil != composer) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TCOM", TagLib::String::Latin1);
		NSAssert(NULL != frame, @"Unable to allocate memory.");
		
		frame->setText(TagLib::String([composer UTF8String], TagLib::String::UTF8));
		f.ID3v2Tag()->addFrame(frame);
	}
	
	// Genre
	NSString *genre = [metadata valueForKey:@"genre"];
	if(nil != genre) {
		//f.tag()->setGenre(TagLib::String([genre UTF8String], TagLib::String::UTF8));
		
 		// There is a bug in iTunes that will show numeric genres for ID3v2.4 genre tags
		unsigned index = [[Genres unsortedGenres] indexOfObject:genre];
		
		frame = new TagLib::ID3v2::TextIdentificationFrame("TCON", TagLib::String::Latin1);
		NSAssert(NULL != frame, @"Unable to allocate memory.");
		
		// Only use numbers for the original ID3v1 genre list
		if(NSNotFound == index) {
			frame->setText(TagLib::String([genre UTF8String], TagLib::String::UTF8));
		}
		else {
			frame->setText(TagLib::String([[NSString stringWithFormat:@"(%u)", index] UTF8String], TagLib::String::UTF8));
		}
		
		f.ID3v2Tag()->addFrame(frame);	
	}
	
	// Date
	NSString *date = [metadata valueForKey:@"date"];
	if(nil != date) {
		f.tag()->setYear([date intValue]);
	}
	
	// Comment
	NSString *comment			= [metadata valueForKey:@"comment"];
	if(nil != comment) {
		f.tag()->setComment(TagLib::String([comment UTF8String], TagLib::String::UTF8));
	}
	
	// Track title
	NSString *title = [metadata valueForKey:@"title"];
	if(nil != title) {
		f.tag()->setTitle(TagLib::String([title UTF8String], TagLib::String::UTF8));
	}
	
	// Track number and total tracks
	NSNumber *trackNumber	= [metadata valueForKey:@"trackNumber"];
	NSNumber *trackTotal		= [metadata valueForKey:@"trackTotal"];
	if(nil != trackNumber && nil != trackTotal) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TRCK", TagLib::String::Latin1);
		NSAssert(NULL != frame, @"Unable to allocate memory.");
		
		frame->setText(TagLib::String([[NSString stringWithFormat:@"%@/%@", trackNumber, trackTotal] UTF8String], TagLib::String::UTF8));
		f.ID3v2Tag()->addFrame(frame);
	}
	else if(nil != trackTotal) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TRCK", TagLib::String::Latin1);
		NSAssert(NULL != frame, @"Unable to allocate memory.");
		
		frame->setText(TagLib::String([[NSString stringWithFormat:@"/%@", trackTotal] UTF8String], TagLib::String::UTF8));
		f.ID3v2Tag()->addFrame(frame);
	}
	else if(nil != trackNumber) {
		f.tag()->setTrack([trackNumber unsignedIntValue]);
	}
		
	// Compilation
	// iTunes uses the TCMP frame for this, which isn't in the standard, but we'll use it for compatibility
	NSNumber *compilation = [metadata valueForKey:@"partOfCompilation"];
	if(nil != compilation) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TCMP", TagLib::String::Latin1);
		NSAssert(NULL != frame, @"Unable to allocate memory.");
		
		frame->setText(TagLib::String([[compilation stringValue] UTF8String], TagLib::String::UTF8));
		f.ID3v2Tag()->addFrame(frame);
	}
	
	// Disc number and total discs
	NSNumber *discNumber	= [metadata valueForKey:@"discNumber"];
	NSNumber *discTotal		= [metadata valueForKey:@"discTotal"];
	if(nil != discNumber && nil != discTotal) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TPOS", TagLib::String::Latin1);
		NSAssert(NULL != frame, @"Unable to allocate memory.");
		
		frame->setText(TagLib::String([[NSString stringWithFormat:@"%@/%@", discNumber, discTotal] UTF8String], TagLib::String::UTF8));
		f.ID3v2Tag()->addFrame(frame);
	}
	else if(nil != discNumber) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TPOS", TagLib::String::Latin1);
		NSAssert(NULL != frame, @"Unable to allocate memory.");
		
		frame->setText(TagLib::String([[NSString stringWithFormat:@"%@", discNumber] UTF8String], TagLib::String::UTF8));
		f.ID3v2Tag()->addFrame(frame);
	}
	else if(nil != discTotal) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TPOS", TagLib::String::Latin1);
		NSAssert(NULL != frame, @"Unable to allocate memory.");
		
		frame->setText(TagLib::String([[NSString stringWithFormat:@"/%@", discTotal] UTF8String], TagLib::String::UTF8));
		f.ID3v2Tag()->addFrame(frame);
	}
		
	// Album art
	NSImage *albumArt = [metadata valueForKey:@"albumArt"];
	if(nil != albumArt) {
		NSData										*data;
		TagLib::ID3v2::AttachedPictureFrame			*pictureFrame;

		data			= getPNGDataForImage(albumArt); 
		pictureFrame	= new TagLib::ID3v2::AttachedPictureFrame();
		NSAssert(NULL != pictureFrame, @"Unable to allocate memory.");
		
		pictureFrame->setMimeType(TagLib::String("image/png", TagLib::String::Latin1));
		pictureFrame->setPicture(TagLib::ByteVector((const char *)[data bytes], [data length]));
		f.ID3v2Tag()->addFrame(pictureFrame);
	}
	
	result = f.save();
	if(NO == result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [_url path];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid Ogg (Vorbis) file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not an Ogg (Vorbis) file" forKey:NSLocalizedFailureReasonErrorKey];
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
