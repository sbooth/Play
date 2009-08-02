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

#import "WAVEMetadataReader.h"

#import "AudioStream.h"
#include <taglib/wavfile.h>
#include <taglib/id3v2tag.h>
#include <taglib/id3v2frame.h>
#include <taglib/attachedpictureframe.h>
#include <taglib/relativevolumeframe.h>
#include <taglib/textidentificationframe.h>

@implementation WAVEMetadataReader

- (BOOL) readMetadata:(NSError **)error
{
	NSMutableDictionary						*metadataDictionary;
	NSString								*path				= [_url path];
	TagLib::RIFF::WAV::File					f					([path fileSystemRepresentation], false);
	TagLib::String							s;
	NSString								*trackString, *trackNum, *totalTracks;
	NSString								*discString, *discNum, *totalDiscs;
	NSRange									range;
	BOOL									foundReplayGain		= NO;
	
	if(NO == f.isValid()) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid WAVE file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a WAVE file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataReaderErrorDomain 
										 code:AudioMetadataReaderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	metadataDictionary = [NSMutableDictionary dictionary];
	
	// Album title
	s = f.tag()->album();
	if(false == s.isNull())
		[metadataDictionary setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:MetadataAlbumTitleKey];
	
	// Artist
	s = f.tag()->artist();
	if(false == s.isNull())
		[metadataDictionary setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:MetadataArtistKey];
	
	// Genre
	s = f.tag()->genre();
	if(false == s.isNull())
		[metadataDictionary setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:MetadataGenreKey];
	
	// Year
	if(0 != f.tag()->year())
		[metadataDictionary setValue:[[NSNumber numberWithInt:f.tag()->year()] stringValue] forKey:MetadataDateKey];
	
	// Comment
	s = f.tag()->comment();
	if(false == s.isNull())
		[metadataDictionary setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:MetadataCommentKey];
	
	// Track title
	s = f.tag()->title();
	if(false == s.isNull())
		[metadataDictionary setValue:[NSString stringWithUTF8String:s.toCString(true)] forKey:MetadataTitleKey];
	
	// Track number
	if(0 != f.tag()->track())
		[metadataDictionary setValue:[NSNumber numberWithInt:f.tag()->track()] forKey:MetadataTrackNumberKey];
	
	// Extract composer if present
	TagLib::ID3v2::FrameList frameList = f.tag()->frameListMap()["TCOM"];
	if(NO == frameList.isEmpty())
		[metadataDictionary setValue:[NSString stringWithUTF8String:frameList.front()->toString().toCString(true)] forKey:MetadataComposerKey];
	
	// Extract album artist
	frameList = f.tag()->frameListMap()["TPE2"];
	if(NO == frameList.isEmpty())
		[metadataDictionary setValue:[NSString stringWithUTF8String:frameList.front()->toString().toCString(true)] forKey:MetadataAlbumArtistKey];
	
	// BPM
	frameList = f.tag()->frameListMap()["TBPM"];
	if(NO == frameList.isEmpty()) {
		NSString *bpmString = [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
		[metadataDictionary setValue:[NSNumber numberWithInt:[bpmString intValue]] forKey:MetadataBPMKey];
	}
	
	// Extract total tracks if present
	frameList = f.tag()->frameListMap()["TRCK"];
	if(NO == frameList.isEmpty()) {
		// Split the tracks at '/'
		trackString		= [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
		range			= [trackString rangeOfString:@"/" options:NSLiteralSearch];
		
		if(NSNotFound != range.location && 0 != range.length) {
			trackNum		= [trackString substringToIndex:range.location];
			totalTracks		= [trackString substringFromIndex:range.location + 1];
			
			[metadataDictionary setValue:[NSNumber numberWithInt:[trackNum intValue]] forKey:MetadataTrackNumberKey];
			[metadataDictionary setValue:[NSNumber numberWithInt:[totalTracks intValue]] forKey:MetadataTrackTotalKey];
		}
		else if(0 != [trackString length])
			[metadataDictionary setValue:[NSNumber numberWithInt:[trackString intValue]] forKey:MetadataTrackNumberKey];
	}
	
	// Extract disc number and total discs
	frameList = f.tag()->frameListMap()["TPOS"];
	if(NO == frameList.isEmpty()) {
		// Split the tracks at '/'
		discString		= [NSString stringWithUTF8String:frameList.front()->toString().toCString(true)];
		range			= [discString rangeOfString:@"/" options:NSLiteralSearch];
		
		if(NSNotFound != range.location && 0 != range.length) {
			discNum			= [discString substringToIndex:range.location];
			totalDiscs		= [discString substringFromIndex:range.location + 1];
			
			[metadataDictionary setValue:[NSNumber numberWithInt:[discNum intValue]] forKey:MetadataDiscNumberKey];
			[metadataDictionary setValue:[NSNumber numberWithInt:[totalDiscs intValue]] forKey:MetadataDiscTotalKey];
		}
		else if(0 != [discString length])
			[metadataDictionary setValue:[NSNumber numberWithInt:[discString intValue]] forKey:MetadataDiscNumberKey];
	}
	
	// Extract album art if present
	/*		TagLib::ID3v2::AttachedPictureFrame *picture = NULL;
	 frameList = f.tag()->frameListMap()["APIC"];
	 if(NO == frameList.isEmpty() && NULL != (picture = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(frameList.front()))) {
	 TagLib::ByteVector	bv		= picture->picture();
	 NSImage				*image	= [[NSImage alloc] initWithData:[NSData dataWithBytes:bv.data() length:bv.size()]];
	 if(nil != image) {
	 [metadataDictionary setValue:[image TIFFRepresentation] forKey:@"albumArt"];
	 [image release];
	 }
	 }*/
	
	// Extract compilation if present (iTunes TCMP tag)
	frameList = f.tag()->frameListMap()["TCMP"];
	if(NO == frameList.isEmpty())
		// It seems that the presence of this frame indicates a compilation
		[metadataDictionary setValue:[NSNumber numberWithBool:YES] forKey:MetadataCompilationKey];
	
	// ReplayGain
	// Preference is TXXX frames, RVA2 frame, then LAME header
	TagLib::ID3v2::UserTextIdentificationFrame *trackGainFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.tag(), "REPLAYGAIN_TRACK_GAIN");
	TagLib::ID3v2::UserTextIdentificationFrame *trackPeakFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.tag(), "REPLAYGAIN_TRACK_PEAK");
	TagLib::ID3v2::UserTextIdentificationFrame *albumGainFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.tag(), "REPLAYGAIN_ALBUM_GAIN");
	TagLib::ID3v2::UserTextIdentificationFrame *albumPeakFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.tag(), "REPLAYGAIN_ALBUM_PEAK");
	
	if(NULL == trackGainFrame)
		trackGainFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.tag(), "replaygain_track_gain");
	if(NULL != trackGainFrame) {
		NSString	*value			= [NSString stringWithUTF8String:trackGainFrame->fieldList().back().toCString(true)];
		NSScanner	*scanner		= [NSScanner scannerWithString:value];
		double		doubleValue		= 0.0;
		
		if([scanner scanDouble:&doubleValue]) {
			[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainTrackGainKey];
			[metadataDictionary setValue:[NSNumber numberWithDouble:89.0] forKey:ReplayGainReferenceLoudnessKey];
			foundReplayGain = YES;
		}
	}
	
	if(NULL == trackPeakFrame)
		trackPeakFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.tag(), "replaygain_track_peak");
	if(NULL != trackPeakFrame) {
		NSString *value = [NSString stringWithUTF8String:trackPeakFrame->fieldList().back().toCString(true)];
		[metadataDictionary setValue:[NSNumber numberWithDouble:[value doubleValue]] forKey:ReplayGainTrackPeakKey];
	}
	
	if(NULL == albumGainFrame)
		albumGainFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.tag(), "replaygain_album_gain");
	if(NULL != albumGainFrame) {
		NSString	*value			= [NSString stringWithUTF8String:albumGainFrame->fieldList().back().toCString(true)];
		NSScanner	*scanner		= [NSScanner scannerWithString:value];
		double		doubleValue		= 0.0;
		
		if([scanner scanDouble:&doubleValue]) {
			[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainAlbumGainKey];
			[metadataDictionary setValue:[NSNumber numberWithDouble:89.0] forKey:ReplayGainReferenceLoudnessKey];
			foundReplayGain = YES;
		}
	}
	
	if(NULL == albumPeakFrame)
		albumPeakFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(f.tag(), "replaygain_album_peak");
	if(NULL != albumPeakFrame) {
		NSString *value = [NSString stringWithUTF8String:albumPeakFrame->fieldList().back().toCString(true)];
		[metadataDictionary setValue:[NSNumber numberWithDouble:[value doubleValue]] forKey:ReplayGainAlbumPeakKey];
	}
	
	// If nothing found check for RVA2 frame
	if(NO == foundReplayGain) {
		frameList = f.tag()->frameListMap()["RVA2"];
		
		TagLib::ID3v2::FrameList::Iterator frameIterator;
		for(frameIterator = frameList.begin(); frameIterator != frameList.end(); ++frameIterator) {
			TagLib::ID3v2::RelativeVolumeFrame *relativeVolume = dynamic_cast<TagLib::ID3v2::RelativeVolumeFrame *>(*frameIterator);
			if(NULL == relativeVolume)
				continue;
			
			if(TagLib::String("track", TagLib::String::Latin1) == relativeVolume->identification()) {
				// Attempt to use the master volume if present
				TagLib::List<TagLib::ID3v2::RelativeVolumeFrame::ChannelType>	channels		= relativeVolume->channels();
				TagLib::ID3v2::RelativeVolumeFrame::ChannelType					channelType		= TagLib::ID3v2::RelativeVolumeFrame::MasterVolume;
				
				// Fall back on whatever else exists in the frame
				if(NO == channels.contains(TagLib::ID3v2::RelativeVolumeFrame::MasterVolume))
					channelType = channels.front();
				
				float volumeAdjustment = relativeVolume->volumeAdjustment(channelType);
				
				if(0 != volumeAdjustment) {
					[metadataDictionary setValue:[NSNumber numberWithFloat:volumeAdjustment] forKey:ReplayGainTrackGainKey];
					foundReplayGain = YES;
				}
			}
			else if(TagLib::String("album", TagLib::String::Latin1) == relativeVolume->identification()) {
				// Attempt to use the master volume if present
				TagLib::List<TagLib::ID3v2::RelativeVolumeFrame::ChannelType>	channels		= relativeVolume->channels();
				TagLib::ID3v2::RelativeVolumeFrame::ChannelType					channelType		= TagLib::ID3v2::RelativeVolumeFrame::MasterVolume;
				
				// Fall back on whatever else exists in the frame
				if(NO == channels.contains(TagLib::ID3v2::RelativeVolumeFrame::MasterVolume))
					channelType = channels.front();
				
				float volumeAdjustment = relativeVolume->volumeAdjustment(channelType);
				
				if(0 != volumeAdjustment) {
					[metadataDictionary setValue:[NSNumber numberWithFloat:volumeAdjustment] forKey:ReplayGainAlbumGainKey];
					foundReplayGain = YES;
				}
			}
			// Fall back to track gain if identification is not specified
			else {
				// Attempt to use the master volume if present
				TagLib::List<TagLib::ID3v2::RelativeVolumeFrame::ChannelType>	channels		= relativeVolume->channels();
				TagLib::ID3v2::RelativeVolumeFrame::ChannelType					channelType		= TagLib::ID3v2::RelativeVolumeFrame::MasterVolume;
				
				// Fall back on whatever else exists in the frame
				if(NO == channels.contains(TagLib::ID3v2::RelativeVolumeFrame::MasterVolume))
					channelType = channels.front();
				
				float volumeAdjustment = relativeVolume->volumeAdjustment(channelType);
				
				if(0 != volumeAdjustment) {
					[metadataDictionary setValue:[NSNumber numberWithFloat:volumeAdjustment] forKey:ReplayGainTrackGainKey];
					foundReplayGain = YES;
				}
			}
		}			
	}
	
	[self setValue:metadataDictionary forKey:@"metadata"];
	
	return YES;
}

@end
