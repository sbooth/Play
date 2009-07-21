/*
 *  $Id$
 *
 *  Copyright (C) 2006 - 2009 Stephen F. Booth <me@sbooth.org>
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

#import "AIFFMetadataWriter.h"
#import "AudioStream.h"
#import "Genres.h"
#import "UtilityFunctions.h"

#include <taglib/aifffile.h>
#include <taglib/textidentificationframe.h>
#include <taglib/unsynchronizedlyricsframe.h>
#include <taglib/uniquefileidentifierframe.h>
#include <taglib/attachedpictureframe.h>
#include <taglib/relativevolumeframe.h>

@implementation AIFFMetadataWriter

- (BOOL) writeMetadata:(id)metadata error:(NSError **)error
{
	NSString *path = [_url path];
	TagLib::RIFF::AIFF::File f([path fileSystemRepresentation], false);
	TagLib::ID3v2::TextIdentificationFrame *frame = NULL;
	bool result;
	
	if(NO == f.isValid()) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid AIFF file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not an AIFF file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
										 code:AudioMetadataWriterFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}

	// Use UTF-8 as the default encoding
	(TagLib::ID3v2::FrameFactory::instance())->setDefaultTextEncoding(TagLib::String::UTF8);

	// Album title
	NSString *album = [metadata valueForKey:MetadataAlbumTitleKey];
	f.tag()->setAlbum(nil == album ? TagLib::String::null : TagLib::String([album UTF8String], TagLib::String::UTF8));
	
	// Artist
	NSString *artist = [metadata valueForKey:MetadataArtistKey];
	f.tag()->setArtist(nil == artist ? TagLib::String::null : TagLib::String([artist UTF8String], TagLib::String::UTF8));
	
	// Composer
	f.tag()->removeFrames("TCOM");
	NSString *composer = [metadata valueForKey:MetadataComposerKey];
	if(nil != composer) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TCOM", TagLib::String::Latin1);
		NSAssert(NULL != frame, @"Unable to allocate memory.");
		
		frame->setText(TagLib::String([composer UTF8String], TagLib::String::UTF8));
		f.tag()->addFrame(frame);
	}
	
	// Genre
	f.tag()->removeFrames("TCON");
	NSString *genre = [metadata valueForKey:MetadataGenreKey];
	if(nil != genre) {
		//f.tag()->setGenre(TagLib::String([genre UTF8String], TagLib::String::UTF8));
		
 		// There is a bug in iTunes that will show numeric genres for ID3v2.4 genre tags
		unsigned index = [[Genres unsortedGenres] indexOfObject:genre];
		
		frame = new TagLib::ID3v2::TextIdentificationFrame("TCON", TagLib::String::Latin1);
		NSAssert(NULL != frame, @"Unable to allocate memory.");
		
		// Only use numbers for the original ID3v1 genre list
		if(NSNotFound == index)
			frame->setText(TagLib::String([genre UTF8String], TagLib::String::UTF8));
		else
			frame->setText(TagLib::String([[NSString stringWithFormat:@"(%u)", index] UTF8String], TagLib::String::UTF8));
		
		f.tag()->addFrame(frame);	
	}
	
	// Date
	NSString *date = [metadata valueForKey:MetadataDateKey];
	f.tag()->setYear(nil == date ? 0 : [date intValue]);
	
	// Comment
	NSString *comment = [metadata valueForKey:MetadataCommentKey];
	f.tag()->setComment(nil == comment ? TagLib::String::null : TagLib::String([comment UTF8String], TagLib::String::UTF8));
	
	// Album artist
	f.tag()->removeFrames("TPE2");
	NSString *albumArtist = [metadata valueForKey:MetadataAlbumArtistKey];
	if(nil != albumArtist) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TPE2", TagLib::String::Latin1);
		NSAssert(NULL != frame, @"Unable to allocate memory.");
		
		frame->setText(TagLib::String([albumArtist UTF8String], TagLib::String::UTF8));
		f.tag()->addFrame(frame);
	}
	
	// Track title
	NSString *title = [metadata valueForKey:MetadataTitleKey];
	f.tag()->setTitle(nil == title ? TagLib::String::null : TagLib::String([title UTF8String], TagLib::String::UTF8));
	
	// BPM
	f.tag()->removeFrames("TBPM");
	NSNumber *bpm = [metadata valueForKey:MetadataBPMKey];
	if(nil != bpm) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TBPM", TagLib::String::Latin1);
		NSAssert(NULL != frame, @"Unable to allocate memory.");
		
		frame->setText(TagLib::String([[bpm stringValue] UTF8String], TagLib::String::UTF8));
		f.tag()->addFrame(frame);
	}
	
	// Track number and total tracks
	f.tag()->removeFrames("TRCK");
	NSNumber *trackNumber	= [metadata valueForKey:MetadataTrackNumberKey];
	NSNumber *trackTotal	= [metadata valueForKey:MetadataTrackTotalKey];
	if(nil != trackNumber && nil != trackTotal) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TRCK", TagLib::String::Latin1);
		NSAssert(NULL != frame, @"Unable to allocate memory.");
		
		frame->setText(TagLib::String([[NSString stringWithFormat:@"%@/%@", trackNumber, trackTotal] UTF8String], TagLib::String::UTF8));
		f.tag()->addFrame(frame);
	}
	else if(nil != trackTotal) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TRCK", TagLib::String::Latin1);
		NSAssert(NULL != frame, @"Unable to allocate memory.");
		
		frame->setText(TagLib::String([[NSString stringWithFormat:@"/%@", trackTotal] UTF8String], TagLib::String::UTF8));
		f.tag()->addFrame(frame);
	}
	else if(nil != trackNumber)
		f.tag()->setTrack([trackNumber unsignedIntValue]);
	
	// Compilation
	// iTunes uses the TCMP frame for this, which isn't in the standard, but we'll use it for compatibility
	f.tag()->removeFrames("TCMP");
	NSNumber *compilation = [metadata valueForKey:MetadataCompilationKey];
	if(nil != compilation) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TCMP", TagLib::String::Latin1);
		NSAssert(NULL != frame, @"Unable to allocate memory.");
		
		frame->setText(TagLib::String([[compilation stringValue] UTF8String], TagLib::String::UTF8));
		f.tag()->addFrame(frame);
	}
	
	// Disc number and total discs
	f.tag()->removeFrames("TPOS");
	NSNumber *discNumber	= [metadata valueForKey:MetadataDiscNumberKey];
	NSNumber *discTotal		= [metadata valueForKey:MetadataDiscTotalKey];
	if(nil != discNumber && nil != discTotal) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TPOS", TagLib::String::Latin1);
		NSAssert(NULL != frame, @"Unable to allocate memory.");
		
		frame->setText(TagLib::String([[NSString stringWithFormat:@"%@/%@", discNumber, discTotal] UTF8String], TagLib::String::UTF8));
		f.tag()->addFrame(frame);
	}
	else if(nil != discNumber) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TPOS", TagLib::String::Latin1);
		NSAssert(NULL != frame, @"Unable to allocate memory.");
		
		frame->setText(TagLib::String([[NSString stringWithFormat:@"%@", discNumber] UTF8String], TagLib::String::UTF8));
		f.tag()->addFrame(frame);
	}
	else if(nil != discTotal) {
		frame = new TagLib::ID3v2::TextIdentificationFrame("TPOS", TagLib::String::Latin1);
		NSAssert(NULL != frame, @"Unable to allocate memory.");
		
		frame->setText(TagLib::String([[NSString stringWithFormat:@"/%@", discTotal] UTF8String], TagLib::String::UTF8));
		f.tag()->addFrame(frame);
	}
	
	// ReplayGain
	NSNumber *trackGain = [metadata valueForKey:ReplayGainTrackGainKey];
	NSNumber *trackPeak = [metadata valueForKey:ReplayGainTrackPeakKey];
	NSNumber *albumGain = [metadata valueForKey:ReplayGainAlbumGainKey];
	NSNumber *albumPeak = [metadata valueForKey:ReplayGainAlbumPeakKey];
	
	// Write TXXX frames
	TagLib::ID3v2::UserTextIdentificationFrame *trackGainFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.tag(), "replaygain_track_gain");
	TagLib::ID3v2::UserTextIdentificationFrame *trackPeakFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.tag(), "replaygain_track_peak");
	TagLib::ID3v2::UserTextIdentificationFrame *albumGainFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.tag(), "replaygain_album_gain");
	TagLib::ID3v2::UserTextIdentificationFrame *albumPeakFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.tag(), "replaygain_album_peak");
	
	if(NULL != trackGainFrame)
		f.tag()->removeFrame(trackGainFrame);
	
	if(NULL != trackPeakFrame)
		f.tag()->removeFrame(trackPeakFrame);
	
	if(NULL != albumGainFrame)
		f.tag()->removeFrame(albumGainFrame);
	
	if(NULL != albumPeakFrame)
		f.tag()->removeFrame(albumPeakFrame);
	
	if(nil != trackGain) {
		TagLib::ID3v2::UserTextIdentificationFrame *userTextFrame = new TagLib::ID3v2::UserTextIdentificationFrame();
		NSAssert(NULL != userTextFrame, @"Unable to allocate memory.");
		
		userTextFrame->setDescription(TagLib::String("replaygain_track_gain", TagLib::String::Latin1));
		userTextFrame->setText(TagLib::String([[NSString stringWithFormat:@"%+2.2f dB", [trackGain doubleValue]] UTF8String], TagLib::String::UTF8));
		
		f.tag()->addFrame(userTextFrame);
	}
	
	if(nil != trackPeak) {
		TagLib::ID3v2::UserTextIdentificationFrame *userTextFrame = new TagLib::ID3v2::UserTextIdentificationFrame();
		NSAssert(NULL != userTextFrame, @"Unable to allocate memory.");
		
		userTextFrame->setDescription(TagLib::String("replaygain_track_peak", TagLib::String::Latin1));
		userTextFrame->setText(TagLib::String([[NSString stringWithFormat:@"%1.8f dB", [trackPeak doubleValue]] UTF8String], TagLib::String::UTF8));
		
		f.tag()->addFrame(userTextFrame);
	}
	
	if(nil != albumGain) {
		TagLib::ID3v2::UserTextIdentificationFrame *userTextFrame = new TagLib::ID3v2::UserTextIdentificationFrame();
		NSAssert(NULL != userTextFrame, @"Unable to allocate memory.");
		
		userTextFrame->setDescription(TagLib::String("replaygain_album_gain", TagLib::String::Latin1));
		userTextFrame->setText(TagLib::String([[NSString stringWithFormat:@"%+2.2f dB", [albumGain doubleValue]] UTF8String], TagLib::String::UTF8));
		
		f.tag()->addFrame(userTextFrame);
	}
	
	if(nil != albumPeak) {
		TagLib::ID3v2::UserTextIdentificationFrame *userTextFrame = new TagLib::ID3v2::UserTextIdentificationFrame();
		NSAssert(NULL != userTextFrame, @"Unable to allocate memory.");
		
		userTextFrame->setDescription(TagLib::String("replaygain_album_peak", TagLib::String::Latin1));
		userTextFrame->setText(TagLib::String([[NSString stringWithFormat:@"%1.8f dB", [albumPeak doubleValue]] UTF8String], TagLib::String::UTF8));
		
		f.tag()->addFrame(userTextFrame);
	}
	
	// Also write the RVA2 frames
	f.tag()->removeFrames("RVA2");
	if(nil != trackGain) {
		TagLib::ID3v2::RelativeVolumeFrame *relativeVolume = new TagLib::ID3v2::RelativeVolumeFrame();
		NSAssert(NULL != relativeVolume, @"Unable to allocate memory.");
		
		relativeVolume->setIdentification(TagLib::String("track", TagLib::String::Latin1));
		relativeVolume->setVolumeAdjustment([trackGain doubleValue], TagLib::ID3v2::RelativeVolumeFrame::MasterVolume);
		
		f.tag()->addFrame(relativeVolume);
	}
	
	if(nil != albumGain) {
		TagLib::ID3v2::RelativeVolumeFrame *relativeVolume = new TagLib::ID3v2::RelativeVolumeFrame();
		NSAssert(NULL != relativeVolume, @"Unable to allocate memory.");
		
		relativeVolume->setIdentification(TagLib::String("album", TagLib::String::Latin1));
		relativeVolume->setVolumeAdjustment([albumGain doubleValue], TagLib::ID3v2::RelativeVolumeFrame::MasterVolume);
		
		f.tag()->addFrame(relativeVolume);
	}
	
	// Album art
	/*	NSImage *albumArt = [metadata valueForKey:@"albumArt"];
	 if(nil != albumArt) {
	 NSData										*data;
	 TagLib::ID3v2::AttachedPictureFrame			*pictureFrame;
	 
	 data			= getPNGDataForImage(albumArt); 
	 pictureFrame	= new TagLib::ID3v2::AttachedPictureFrame();
	 NSAssert(NULL != pictureFrame, @"Unable to allocate memory.");
	 
	 pictureFrame->setMimeType(TagLib::String("image/png", TagLib::String::Latin1));
	 pictureFrame->setPicture(TagLib::ByteVector((const char *)[data bytes], [data length]));
	 f.tag()->addFrame(pictureFrame);
	 }*/
	
	result = f.save();
	if(NO == result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [_url path];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid MPEG file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Unable to write metadata", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataWriterErrorDomain 
										 code:AudioMetadataWriterFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	return YES;
}

@end
