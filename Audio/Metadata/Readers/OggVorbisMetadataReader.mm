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

#import "OggVorbisMetadataReader.h"
#import "AudioStream.h"
#include <taglib/vorbisfile.h>
#include <taglib/xiphcomment.h>

@implementation OggVorbisMetadataReader

- (BOOL) readMetadata:(NSError **)error
{
	NSMutableDictionary				*metadataDictionary;
	NSString						*path					= [_url path];
	TagLib::Ogg::Vorbis::File		f						([path fileSystemRepresentation], false);
	TagLib::String					s;
	TagLib::Ogg::XiphComment		*xiphComment;

	if(NO == f.isValid()) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Ogg Vorbis file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not an Ogg Vorbis file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error = [NSError errorWithDomain:AudioMetadataReaderErrorDomain 
										 code:AudioMetadataReaderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	metadataDictionary			= [NSMutableDictionary dictionary];
	xiphComment					= f.tag();

	if(NULL != xiphComment) {
		TagLib::Ogg::FieldListMap		fieldList		= xiphComment->fieldListMap();
		NSString						*value			= nil;
		NSNumber						*numberValue	= nil;
		TagLib::String					tag;
		
		tag = "ALBUM";
		if(fieldList.contains(tag)) {
			value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
			[metadataDictionary setValue:value forKey:MetadataAlbumTitleKey];
		}
		
		tag = "ARTIST";
		if(fieldList.contains(tag)) {
			value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
			[metadataDictionary setValue:value forKey:MetadataArtistKey];
		}

		tag = "ALBUMARTIST";
		if(fieldList.contains(tag)) {
			value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
			[metadataDictionary setValue:value forKey:MetadataAlbumArtistKey];
		}
		
		tag = "GENRE";
		if(fieldList.contains(tag)) {
			value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
			[metadataDictionary setValue:value forKey:MetadataGenreKey];
		}
		
		tag = "DATE";
		if(fieldList.contains(tag)) {
			value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
			[metadataDictionary setValue:value forKey:MetadataDateKey];
		}
		
		tag = "DESCRIPTION";
		if(fieldList.contains(tag)) {
			value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
			[metadataDictionary setValue:value forKey:MetadataCommentKey];
		}
		
		tag = "TITLE";
		if(fieldList.contains(tag)) {
			value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
			[metadataDictionary setValue:value forKey:MetadataTitleKey];
		}
		
		tag = "TRACKNUMBER";
		if(fieldList.contains(tag)) {
			numberValue = [NSNumber numberWithInt:[[NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)] intValue]];
			[metadataDictionary setValue:numberValue forKey:MetadataTrackNumberKey];
		}
		
		tag = "COMPOSER";
		if(fieldList.contains(tag)) {
			value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
			[metadataDictionary setValue:value forKey:MetadataComposerKey];
		}
		
		tag = "TRACKTOTAL";
		if(fieldList.contains(tag)) {
			numberValue = [NSNumber numberWithInt:[[NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)] intValue]];
			[metadataDictionary setValue:numberValue forKey:MetadataTrackTotalKey];
		}
		
		tag = "DISCNUMBER";
		if(fieldList.contains(tag)) {
			numberValue = [NSNumber numberWithInt:[[NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)] intValue]];
			[metadataDictionary setValue:numberValue forKey:MetadataDiscNumberKey];
		}
		
		tag = "DISCTOTAL";
		if(fieldList.contains(tag)) {
			numberValue = [NSNumber numberWithInt:[[NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)] intValue]];
			[metadataDictionary setValue:numberValue forKey:MetadataDiscTotalKey];
		}
		
		tag = "COMPILATION";
		if(fieldList.contains(tag)) {
			numberValue = [NSNumber numberWithBool:[[NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)] intValue]];
			[metadataDictionary setValue:numberValue forKey:MetadataCompilationKey];
		}
		
		tag = "ISRC";
		if(fieldList.contains(tag)) {
			value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
			[metadataDictionary setValue:value forKey:MetadataISRCKey];
		}					
		
		tag = "MCN";
		if(fieldList.contains(tag)) {
			value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
			[metadataDictionary setValue:value forKey:MetadataMCNKey];
		}

		tag = "BPM";
		if(fieldList.contains(tag)) {
			numberValue = [NSNumber numberWithInt:[[NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)] intValue]];
			[metadataDictionary setValue:numberValue forKey:MetadataBPMKey];
		}
		
		// Replay Gain
		tag = "REPLAYGAIN_REFERENCE_LOUDNESS";
		if(fieldList.contains(tag)) {
			value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
			
			NSScanner	*scanner		= [NSScanner scannerWithString:value];						
			double		doubleValue		= 0.0;
			
			if([scanner scanDouble:&doubleValue])
				[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainReferenceLoudnessKey];
		}					
		
		tag = "REPLAYGAIN_TRACK_GAIN";
		if(fieldList.contains(tag)) {
			value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
			
			NSScanner	*scanner		= [NSScanner scannerWithString:value];						
			double		doubleValue		= 0.0;
			
			if([scanner scanDouble:&doubleValue])
				[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainTrackGainKey];
		}					
		
		tag = "REPLAYGAIN_TRACK_PEAK";
		if(fieldList.contains(tag)) {
			value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
			[metadataDictionary setValue:[NSNumber numberWithDouble:[value doubleValue]] forKey:ReplayGainTrackPeakKey];
		}					
		
		tag = "REPLAYGAIN_ALBUM_GAIN";
		if(fieldList.contains(tag)) {
			value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
			
			NSScanner	*scanner		= [NSScanner scannerWithString:value];						
			double		doubleValue		= 0.0;
			
			if([scanner scanDouble:&doubleValue])
				[metadataDictionary setValue:[NSNumber numberWithDouble:doubleValue] forKey:ReplayGainAlbumGainKey];
		}					
		
		tag = "REPLAYGAIN_ALBUM_PEAK";
		if(fieldList.contains(tag)) {
			value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
			[metadataDictionary setValue:[NSNumber numberWithDouble:[value doubleValue]] forKey:ReplayGainAlbumPeakKey];
		}

		tag = "MUSICDNS_PUID";
		if(fieldList.contains(tag)) {
			value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
			[metadataDictionary setValue:value forKey:MetadataMusicDNSPUIDKey];
		}					
		
		tag = "MUSICBRAINZ_ID";
		if(fieldList.contains(tag)) {
			value = [NSString stringWithUTF8String:fieldList[tag].toString().toCString(true)];
			[metadataDictionary setValue:value forKey:MetadataMusicBrainzIDKey];
		}							
	}
	
	[self setValue:metadataDictionary forKey:@"metadata"];

	return YES;
}

@end
