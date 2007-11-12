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

#import "OggFLACPropertiesReader.h"
#import "AudioStream.h"
#include <FLAC/stream_decoder.h>
#include <FLAC/metadata.h>

static FLAC__StreamDecoderWriteStatus 
writeCallback(const FLAC__StreamDecoder *decoder, const FLAC__Frame *frame, const FLAC__int32 * const buffer[], void *client_data)
{
	return FLAC__STREAM_DECODER_WRITE_STATUS_ABORT;
}

static void
metadataCallback(const FLAC__StreamDecoder *decoder, const FLAC__StreamMetadata *metadata, void *client_data)
{
	OggFLACPropertiesReader	*source				= (OggFLACPropertiesReader *)client_data;
	//	const FLAC__StreamMetadata_CueSheet		*cueSheet			= NULL;
	//	FLAC__StreamMetadata_CueSheet_Track		*currentTrack		= NULL;
	//	FLAC__StreamMetadata_CueSheet_Index		*currentIndex		= NULL;
	//	unsigned								i, j;
	
	switch(metadata->type) {
		case FLAC__METADATA_TYPE_STREAMINFO:
			[source setValue:[NSNumber numberWithUnsignedInt:metadata->data.stream_info.sample_rate] forKeyPath:@"localProperties.sampleRate"];
			[source setValue:[NSNumber numberWithUnsignedInt:metadata->data.stream_info.bits_per_sample] forKeyPath:@"localProperties.bitsPerChannel"];
			[source setValue:[NSNumber numberWithUnsignedInt:metadata->data.stream_info.channels] forKeyPath:@"localProperties.channelsPerFrame"];
			
			[source setValue:[NSNumber numberWithLongLong:metadata->data.stream_info.total_samples] forKeyPath:@"localProperties.totalFrames"];
			break;
			
			/*
			 case FLAC__METADATA_TYPE_CUESHEET:
				 cueSheet = &(metadata->data.cue_sheet);
				 
				 for(i = 0; i < cueSheet->num_tracks; ++i) {
					 currentTrack = &(cueSheet->tracks[i]);
					 
					 FLAC__uint64 offset = currentTrack->offset;
					 
					 for(j = 0; j < currentTrack->num_indices; ++j) {
						 currentIndex = &(currentTrack->indices[j]);					
					 }
				 }
					 break;
				 */
		default:
			break;
	}
}

static void
errorCallback(const FLAC__StreamDecoder *decoder, FLAC__StreamDecoderErrorStatus status, void *client_data)
{}

@implementation OggFLACPropertiesReader

- (id) init
{
	if((self = [super init])) {
		_localProperties = [[NSMutableDictionary alloc] init];
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_localProperties release],		_localProperties = nil;
	
	[super dealloc];
}

- (BOOL) readProperties:(NSError **)error
{
	NSString						*path				= [_url path];
	FLAC__StreamDecoder				*flac;
	FLAC__bool						result;
	FLAC__StreamDecoderInitStatus	status;
	
	// Create FLAC decoder
	flac		= FLAC__stream_decoder_new();
	NSAssert(NULL != flac, @"Unable to create the Ogg FLAC decoder.");
	
	// Initialize decoder
	status		= FLAC__stream_decoder_init_ogg_file(flac, 
													 [path fileSystemRepresentation],
													 writeCallback, 
													 metadataCallback, 
													 errorCallback,
													 self);
	NSAssert1(FLAC__STREAM_DECODER_INIT_STATUS_OK == status, @"FLAC__stream_decoder_init_file failed: %s", FLAC__stream_decoder_get_resolved_state_string(flac));
	
	/*
	 // Process cue sheets
	 result = OggFLAC__file_decoder_set_metadata_respond(flac, FLAC__METADATA_TYPE_CUESHEET);
	 NSAssert(YES == result, @"%s", OggFLAC__FileDecoderStateString[OggFLAC__file_decoder_get_state(flac)]);
	 */
				
	// Process metadata
	result = FLAC__stream_decoder_process_until_end_of_metadata(flac);
	NSAssert1(YES == result, @"FLAC__file_decoder_process_until_end_of_metadata failed: %s", FLAC__stream_decoder_get_resolved_state_string(flac));
	
	[_localProperties setValue:NSLocalizedStringFromTable(@"Ogg", @"Formats", @"") forKey:PropertiesFileTypeKey];
	[_localProperties setValue:NSLocalizedStringFromTable(@"FLAC", @"Formats", @"") forKey:PropertiesDataFormatKey];
	[_localProperties setValue:NSLocalizedStringFromTable(@"Ogg FLAC", @"Formats", @"") forKey:PropertiesFormatDescriptionKey];

	result = FLAC__stream_decoder_finish(flac);
	NSAssert1(YES == result, @"FLAC__stream_decoder_finish failed: %s", FLAC__stream_decoder_get_resolved_state_string(flac));
	
	FLAC__stream_decoder_delete(flac);
	
	[self setValue:_localProperties forKey:@"properties"];
	
	return YES;
}

@end
