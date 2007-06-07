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

#import "AudioStream.h"
#import "CollectionManager.h"
#import "AudioStreamManager.h"
#import "AudioMetadataReader.h"
#import "AudioMetadataWriter.h"

NSString * const	StreamURLKey							= @"url";

NSString * const	StatisticsDateAddedKey					= @"dateAdded";
NSString * const	StatisticsFirstPlayedDateKey			= @"firstPlayed";
NSString * const	StatisticsLastPlayedDateKey				= @"lastPlayed";
NSString * const	StatisticsLastSkippedDateKey			= @"lastSkipped";
NSString * const	StatisticsPlayCountKey					= @"playCount";
NSString * const	StatisticsSkipCountKey					= @"skipCount";
NSString * const	StatisticsRatingKey						= @"rating";

NSString * const	MetadataTitleKey						= @"title";
NSString * const	MetadataAlbumTitleKey					= @"albumTitle";
NSString * const	MetadataArtistKey						= @"artist";
NSString * const	MetadataAlbumArtistKey					= @"albumArtist";
NSString * const	MetadataGenreKey						= @"genre";
NSString * const	MetadataComposerKey						= @"composer";
NSString * const	MetadataDateKey							= @"date";
NSString * const	MetadataCompilationKey					= @"compilation";
NSString * const	MetadataTrackNumberKey					= @"trackNumber";
NSString * const	MetadataTrackTotalKey					= @"trackTotal";
NSString * const	MetadataDiscNumberKey					= @"discNumber";
NSString * const	MetadataDiscTotalKey					= @"discTotal";
NSString * const	MetadataCommentKey						= @"comment";
NSString * const	MetadataISRCKey							= @"isrc";
NSString * const	MetadataMCNKey							= @"mcn";
NSString * const	MetadataBPMKey							= @"bpm";

NSString * const	ReplayGainReferenceLoudnessKey			= @"referenceLoudness";
NSString * const	ReplayGainTrackGainKey					= @"trackGain";
NSString * const	ReplayGainTrackPeakKey					= @"trackPeak";
NSString * const	ReplayGainAlbumGainKey					= @"albumGain";
NSString * const	ReplayGainAlbumPeakKey					= @"albumPeak";

NSString * const	PropertiesFileTypeKey					= @"fileType";
NSString * const	PropertiesDataFormatKey					= @"dataFormat";
NSString * const	PropertiesFormatDescriptionKey			= @"formatDescription";
NSString * const	PropertiesBitsPerChannelKey				= @"bitsPerChannel";
NSString * const	PropertiesChannelsPerFrameKey			= @"channelsPerFrame";
NSString * const	PropertiesSampleRateKey					= @"sampleRate";
NSString * const	PropertiesTotalFramesKey				= @"totalFrames";
NSString * const	PropertiesDurationKey					= @"duration";
NSString * const	PropertiesBitrateKey					= @"bitrate";

@implementation AudioStream

+ (void) initialize
{
	[self setKeys:[NSArray arrayWithObjects:MetadataTrackNumberKey, MetadataTrackTotalKey, nil] triggerChangeNotificationsForDependentKey:@"trackString"];
	[self setKeys:[NSArray arrayWithObjects:MetadataDiscNumberKey, MetadataDiscTotalKey, nil] triggerChangeNotificationsForDependentKey:@"discString"];
}

+ (id) insertStreamForURL:(NSURL *)URL withInitialValues:(NSDictionary *)keyedValues
{
	NSParameterAssert(nil != URL);
	
	AudioStream *stream = [[AudioStream alloc] init];
	
	// Call init: methods here to avoid sending change notifications
	[stream initValue:URL forKey:StreamURLKey];
	[stream initValue:[NSDate date] forKey:StatisticsDateAddedKey];
	[stream initValuesForKeysWithDictionary:keyedValues];
	
	if(NO == [[[CollectionManager manager] streamManager] insertStream:stream])
		[stream release], stream = nil;

	return [stream autorelease];
}

- (IBAction) resetPlayCount:(id)sender
{
	[self setValue:nil forKey:StatisticsPlayCountKey];
	[self setValue:nil forKey:StatisticsLastPlayedDateKey];
}

- (IBAction) resetSkipCount:(id)sender
{
	[self setValue:nil forKey:StatisticsSkipCountKey];
	[self setValue:nil forKey:StatisticsLastSkippedDateKey];
}

- (IBAction) clearMetadata:(id)sender
{
	[self setValue:nil forKey:MetadataTitleKey];
	[self setValue:nil forKey:MetadataAlbumTitleKey];
	[self setValue:nil forKey:MetadataArtistKey];
	[self setValue:nil forKey:MetadataAlbumArtistKey];
	[self setValue:nil forKey:MetadataGenreKey];
	[self setValue:nil forKey:MetadataComposerKey];
	[self setValue:nil forKey:MetadataDateKey];
	[self setValue:nil forKey:MetadataCompilationKey];
	[self setValue:nil forKey:MetadataTrackNumberKey];
	[self setValue:nil forKey:MetadataTrackTotalKey];
	[self setValue:nil forKey:MetadataDiscNumberKey];
	[self setValue:nil forKey:MetadataDiscTotalKey];
	[self setValue:nil forKey:MetadataCommentKey];
	[self setValue:nil forKey:MetadataISRCKey];
	[self setValue:nil forKey:MetadataMCNKey];
	[self setValue:nil forKey:MetadataBPMKey];
}

- (IBAction) clearReplayGain:(id)sender
{
	[self setValue:nil forKey:ReplayGainReferenceLoudnessKey];
	[self setValue:nil forKey:ReplayGainTrackGainKey];
	[self setValue:nil forKey:ReplayGainTrackPeakKey];
	[self setValue:nil forKey:ReplayGainAlbumGainKey];
	[self setValue:nil forKey:ReplayGainAlbumPeakKey];
}

- (IBAction) rescanMetadata:(id)sender
{
	NSError					*error				= nil;
	AudioMetadataReader		*metadataReader		= [AudioMetadataReader metadataReaderForURL:[self valueForKey:StreamURLKey] error:&error];

	if(nil == metadataReader) {
/*		if(nil != error) {
			[[AudioLibrary library] presentError:error];
		}*/
		return;
	}
	
	BOOL result = [metadataReader readMetadata:&error];
	if(NO == result) {
/*		if(nil != error) {
			[[AudioLibrary library] presentError:error];
		}*/
		return;
	}
	
	// Empty old metadata
	[self clearMetadata:sender];

	NSDictionary	*metadata		= [metadataReader valueForKey:@"metadata"];
	NSEnumerator	*enumerator		= [metadata keyEnumerator];
	NSString		*key;
	id				value;
	
	while((key = [enumerator nextObject])) {
		value = [metadata valueForKey:key];
		[self setValue:value forKey:key];
	}
}

- (IBAction) saveMetadata:(id)sender
{
	NSError					*error				= nil;
	AudioMetadataWriter		*metadataWriter		= [AudioMetadataWriter metadataWriterForURL:[self valueForKey:StreamURLKey] error:&error];
	
	if(nil == metadataWriter) {
		/*		if(nil != error) {
		[[AudioLibrary library] presentError:error];
		}*/
		return;
	}
	
	BOOL result = [metadataWriter writeMetadata:self error:&error];
	if(NO == result) {
		/*		if(nil != error) {
		[[AudioLibrary library] presentError:error];
		}*/
		return;
	}	
}

- (NSString *) trackString
{
	NSNumber	*trackNumber	= [self valueForKey:MetadataTrackNumberKey];
	NSNumber	*trackTotal		= [self valueForKey:MetadataTrackTotalKey];
	
	if(nil != trackNumber && nil != trackTotal)
		return [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@/%@", @"AudioStream", @""), trackNumber, trackTotal];
	else if(nil != trackNumber)
		return [trackNumber stringValue];
	else if(nil != trackTotal)
		return [NSString stringWithFormat:NSLocalizedStringFromTable(@"/%@", @"AudioStream", @""), trackTotal];

	return nil;
}

- (NSString *) discString
{
	NSNumber	*discNumber		= [self valueForKey:MetadataDiscNumberKey];
	NSNumber	*discTotal		= [self valueForKey:MetadataDiscTotalKey];
	
	if(nil != discNumber && nil != discTotal)
		return [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@/%@", @"AudioStream", @""), discNumber, discTotal];
	else if(nil != discNumber)
		return [discNumber stringValue];
	else if(nil != discTotal)
		return [NSString stringWithFormat:NSLocalizedStringFromTable(@"/%@", @"AudioStream", @""), discTotal];
	
	return nil;
}

- (NSString *) filename
{
	return [[NSFileManager defaultManager] displayNameAtPath:[[self valueForKey:StreamURLKey] path]];
}

- (NSString *) pathname
{
	return [[self valueForKey:StreamURLKey] path];
}

- (BOOL) isPlaying							{ return _playing; }
- (void) setPlaying:(BOOL)playing			{ _playing = playing; }

- (void) save
{
	[[[CollectionManager manager] streamManager] saveStream:self];
}

- (void) delete
{
	[[[CollectionManager manager] streamManager] deleteStream:self];
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"[%@] %@", 
		[self valueForKey:ObjectIDKey], 
		[self filename]];
}

- (NSString *) debugDescription
{
	return [NSString stringWithFormat:@"<%@: %x> [%@] %@",
		[self class], 
		self, 
		[self valueForKey:ObjectIDKey], 
		[self filename]];
}

#pragma mark Reimplementations

- (NSArray *) supportedKeys
{
	if(nil == _supportedKeys) {
		_supportedKeys	= [[NSArray alloc] initWithObjects:
			ObjectIDKey, 
			StreamURLKey,
			
			StatisticsDateAddedKey,
			StatisticsFirstPlayedDateKey,
			StatisticsLastPlayedDateKey,
			StatisticsLastSkippedDateKey,
			StatisticsPlayCountKey,
			StatisticsSkipCountKey,
			StatisticsRatingKey,
			
			MetadataTitleKey,
			MetadataAlbumTitleKey,
			MetadataArtistKey,
			MetadataAlbumArtistKey,
			MetadataGenreKey,
			MetadataComposerKey,
			MetadataDateKey,
			MetadataCompilationKey,
			MetadataTrackNumberKey,
			MetadataTrackTotalKey,
			MetadataDiscNumberKey,
			MetadataDiscTotalKey,
			MetadataCommentKey,
			MetadataISRCKey,
			MetadataMCNKey,
			MetadataBPMKey,

			ReplayGainReferenceLoudnessKey,
			ReplayGainTrackGainKey,
			ReplayGainTrackPeakKey,
			ReplayGainAlbumGainKey,
			ReplayGainAlbumPeakKey,
			
			PropertiesFileTypeKey,
			PropertiesDataFormatKey,
			PropertiesFormatDescriptionKey,
			PropertiesBitsPerChannelKey,
			PropertiesChannelsPerFrameKey,
			PropertiesSampleRateKey,
			PropertiesTotalFramesKey,
			PropertiesDurationKey,
			PropertiesBitrateKey,
			
			nil];
	}	
	return _supportedKeys;
}

@end
