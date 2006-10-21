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

#import "FLACStreamDecoder.h"
#include <FLAC/metadata.h>

@interface FLACStreamDecoder (Private)

- (void)	setSampleRate:(Float64)sampleRate;
- (void)	setBitsPerChannel:(UInt32)bitsPerChannel;
- (void)	setChannelsPerFrame:(UInt32)channelsPerFrame;

@end

static FLAC__StreamDecoderWriteStatus 
writeCallback(const FLAC__FileDecoder *decoder, const FLAC__Frame *frame, const FLAC__int32 * const buffer[], void *client_data)
{
	FLACStreamDecoder	*streamDecoder			= (FLACStreamDecoder *)client_data;
	
	unsigned			spaceRequired			= 0;
	
	int8_t				*alias8					= NULL;
	int16_t				*alias16				= NULL;
	int32_t				*alias32				= NULL;
	
	unsigned			sample, channel;
	int32_t				audioSample;
	
	// Calculate the number of audio data points contained in the frame (should be one for each channel)
	spaceRequired		= frame->header.blocksize * frame->header.channels * (frame->header.bits_per_sample / 8);
	
	// Increase buffer size as required
	if([[streamDecoder pcmBuffer] freeSpaceAvailable] < spaceRequired) {
		[[streamDecoder pcmBuffer] increaseSize:spaceRequired];
	}
	
	switch(frame->header.bits_per_sample) {
		
		case 8:
			
			// Interleave the audio (no need for byte swapping)
			alias8 = [[streamDecoder pcmBuffer] exposeBufferForWriting];
			for(sample = 0; sample < frame->header.blocksize; ++sample) {
				for(channel = 0; channel < frame->header.channels; ++channel) {
					*alias8++ = (int8_t)buffer[channel][sample];
				}
			}
				
			[[streamDecoder pcmBuffer] wroteBytes:spaceRequired];
			
			break;
			
		case 16:
			
			// Interleave the audio, converting to big endian byte order 
			alias16 = [[streamDecoder pcmBuffer] exposeBufferForWriting];
			for(sample = 0; sample < frame->header.blocksize; ++sample) {
				for(channel = 0; channel < frame->header.channels; ++channel) {
					*alias16++ = (int16_t)OSSwapHostToBigInt16((int16_t)buffer[channel][sample]);
				}
			}
				
			[[streamDecoder pcmBuffer] wroteBytes:spaceRequired];
			
			break;
			
		case 24:				
			
			// Interleave the audio
			alias8 = [[streamDecoder pcmBuffer] exposeBufferForWriting];
			for(sample = 0; sample < frame->header.blocksize; ++sample) {
				for(channel = 0; channel < frame->header.channels; ++channel) {
					audioSample	= OSSwapHostToBigInt32(buffer[channel][sample]);
					*alias8++	= (int8_t)(audioSample >> 16);
					*alias8++	= (int8_t)(audioSample >> 8);
					*alias8++	= (int8_t)audioSample;
				}
			}
				
			[[streamDecoder pcmBuffer] wroteBytes:spaceRequired];
			
			break;
			
		case 32:
			
			// Interleave the audio, converting to big endian byte order 
			alias32 = [[streamDecoder pcmBuffer] exposeBufferForWriting];
			for(sample = 0; sample < frame->header.blocksize; ++sample) {
				for(channel = 0; channel < frame->header.channels; ++channel) {
					*alias32++ = OSSwapHostToBigInt32(buffer[channel][sample]);
				}
			}
				
			[[streamDecoder pcmBuffer] wroteBytes:spaceRequired];
			
			break;
			
		default:
			@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
			break;				
	}
	
	// Always return continue; an exception will be thrown if this isn't the case
	return FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE;
}

static void
metadataCallback(const FLAC__FileDecoder *decoder, const FLAC__StreamMetadata *metadata, void *client_data)
{
	FLACStreamDecoder	*source					= (FLACStreamDecoder *)client_data;
	//	const FLAC__StreamMetadata_CueSheet		*cueSheet			= NULL;
	//	FLAC__StreamMetadata_CueSheet_Track		*currentTrack		= NULL;
	//	FLAC__StreamMetadata_CueSheet_Index		*currentIndex		= NULL;
	//	unsigned								i, j;
	
	switch(metadata->type) {
		case FLAC__METADATA_TYPE_STREAMINFO:
			[source setSampleRate:metadata->data.stream_info.sample_rate];			
			[source setBitsPerChannel:metadata->data.stream_info.bits_per_sample];
			[source setChannelsPerFrame:metadata->data.stream_info.channels];

			[source setTotalFrames:metadata->data.stream_info.total_samples];
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
	}
}

static void
errorCallback(const FLAC__FileDecoder *decoder, FLAC__StreamDecoderErrorStatus status, void *client_data)
{
	//	FLACDecoder		*source		= (FLACDecoder *)client_data;
	
	//	@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__StreamDecoderErrorStatusString[status] encoding:NSASCIIStringEncoding] userInfo:nil];
}

@implementation FLACStreamDecoder

- (NSString *)		sourceFormatDescription			{ return [NSString stringWithFormat:@"%@, %u channels, %u Hz", NSLocalizedStringFromTable(@"FLAC", @"General", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate]; }

- (SInt64) seekToFrame:(SInt64)frame
{
	FLAC__bool					result;
	
	result						= FLAC__file_decoder_seek_absolute(_flac, frame);
	
	if(NO == result) {
		return -1;
	}
	
	[[self pcmBuffer] reset];
	[self setCurrentFrame:frame];	
	
	return frame;
}

- (BOOL) readMetadata:(NSError **)error
{
	NSString						*path				= [_url path];
	FLAC__Metadata_Chain			*chain				= NULL;
	FLAC__Metadata_Iterator			*iterator			= NULL;
	FLAC__StreamMetadata			*block				= NULL;
	unsigned						i;
	NSMutableDictionary				*metadataDictionary;
	NSString						*commentString, *key, *value;
	NSRange							range;
				
	chain							= FLAC__metadata_chain_new();
	
	NSAssert(NULL != chain, @"Unable to allocate memory.");
	
	if(NO == FLAC__metadata_chain_read(chain, [path fileSystemRepresentation])) {
		
		if(nil != error) {
			NSMutableDictionary		*errorDictionary;
			
			errorDictionary			= [NSMutableDictionary dictionary];
			
			switch(FLAC__metadata_chain_status(chain)) {
				case FLAC__METADATA_CHAIN_STATUS_NOT_A_FLAC_FILE:
					[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid FLAC file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
					[errorDictionary setObject:@"Not a FLAC file" forKey:NSLocalizedFailureReasonErrorKey];
					[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
					break;
					
				case FLAC__METADATA_CHAIN_STATUS_READ_ERROR:
					[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid FLAC file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
					[errorDictionary setObject:@"Not a FLAC file" forKey:NSLocalizedFailureReasonErrorKey];
					[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
					break;
					
				case FLAC__METADATA_CHAIN_STATUS_SEEK_ERROR:
					[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid FLAC file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
					[errorDictionary setObject:@"Not a FLAC file" forKey:NSLocalizedFailureReasonErrorKey];
					[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
					break;
					
				case FLAC__METADATA_CHAIN_STATUS_BAD_METADATA:
					[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid FLAC file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
					[errorDictionary setObject:@"Not a FLAC file" forKey:NSLocalizedFailureReasonErrorKey];
					[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
					break;
					
				case FLAC__METADATA_CHAIN_STATUS_ERROR_OPENING_FILE:
					[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid FLAC file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
					[errorDictionary setObject:@"Not a FLAC file" forKey:NSLocalizedFailureReasonErrorKey];
					[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
					break;
					
				default:
					[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid FLAC file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
					[errorDictionary setObject:@"Not a FLAC file" forKey:NSLocalizedFailureReasonErrorKey];
					[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
					break;
			}
			
			*error					= [NSError errorWithDomain:AudioStreamDecoderErrorDomain 
														  code:AudioStreamDecoderFileFormatNotRecognizedError 
													  userInfo:errorDictionary];
		}
		
		FLAC__metadata_chain_delete(chain);
		
		return NO;
	}
	
	iterator					= FLAC__metadata_iterator_new();
	
	NSAssert(NULL != iterator, @"Unable to allocate memory.");
	
	FLAC__metadata_iterator_init(iterator, chain);
	
	do {
		block					= FLAC__metadata_iterator_get_block(iterator);
		
		if(NULL == block) {
			break;
		}
		
		switch(block->type) {					
			case FLAC__METADATA_TYPE_VORBIS_COMMENT:				
				metadataDictionary			= [NSMutableDictionary dictionary];
				
				for(i = 0; i < block->data.vorbis_comment.num_comments; ++i) {
					
					// Split the comment at '='
					commentString	= [NSString stringWithUTF8String:(const char *)block->data.vorbis_comment.comments[i].entry];
					range			= [commentString rangeOfString:@"=" options:NSLiteralSearch];
					
					// Sanity check (comments should be well-formed)
					if(NSNotFound != range.location && 0 != range.length) {
						key				= [[commentString substringToIndex:range.location] uppercaseString];
						value			= [commentString substringFromIndex:range.location + 1];
						
						if(NSOrderedSame == [key caseInsensitiveCompare:@"ALBUM"]) {
							[metadataDictionary setValue:value forKey:@"albumTitle"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"ARTIST"]) {
							[metadataDictionary setValue:value forKey:@"artist"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"COMPOSER"]) {
							[metadataDictionary setValue:value forKey:@"composer"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"GENRE"]) {
							[metadataDictionary setValue:value forKey:@"genre"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"DATE"]) {
							[metadataDictionary setValue:value forKey:@"data"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"DESCRIPTION"]) {
							[metadataDictionary setValue:value forKey:@"comment"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"TITLE"]) {
							[metadataDictionary setValue:value forKey:@"title"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"TRACKNUMBER"]) {
							[metadataDictionary setValue:[NSNumber numberWithUnsignedInt:(UInt32)[value intValue]] forKey:@"trackNumber"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"TRACKTOTAL"]) {
							[metadataDictionary setValue:[NSNumber numberWithUnsignedInt:(UInt32)[value intValue]] forKey:@"trackTotal"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"COMPILATION"]) {
							[metadataDictionary setValue:[NSNumber numberWithBool:(BOOL)[value intValue]] forKey:@"partOfCompilation"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"DISCNUMBER"]) {
							[metadataDictionary setValue:[NSNumber numberWithUnsignedInt:(UInt32)[value intValue]] forKey:@"discNumber"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"DISCTOTAL"]) {
							[metadataDictionary setValue:[NSNumber numberWithUnsignedInt:(UInt32)[value intValue]] forKey:@"discTotal"];
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"ISRC"]) {
							[metadataDictionary setValue:value forKey:@"isrc"];;
						}
						else if(NSOrderedSame == [key caseInsensitiveCompare:@"MCN"]) {
							[metadataDictionary setValue:value forKey:@"mcn"];
						}
					}
					
					[self setValue:metadataDictionary forKey:@"metadata"];
				}
				break;
				
			case FLAC__METADATA_TYPE_STREAMINFO:					break;
			case FLAC__METADATA_TYPE_PADDING:						break;
			case FLAC__METADATA_TYPE_APPLICATION:					break;
			case FLAC__METADATA_TYPE_SEEKTABLE:						break;
			case FLAC__METADATA_TYPE_CUESHEET:						break;
			case FLAC__METADATA_TYPE_UNDEFINED:						break;
			default:												break;
		}
	} while(FLAC__metadata_iterator_next(iterator));
	
	FLAC__metadata_iterator_delete(iterator);
	FLAC__metadata_chain_delete(chain);
	
	return YES;
}

- (void) setupDecoder
{
	FLAC__bool					result;
	FLAC__FileDecoderState		state;	
	
	// Create FLAC decoder
	_flac		= FLAC__file_decoder_new();
	NSAssert(NULL != _flac, NSLocalizedStringFromTable(@"Unable to create the FLAC decoder.", @"Exceptions", @""));
	
	result		= FLAC__file_decoder_set_filename(_flac, [[[self valueForKey:@"url"] path] fileSystemRepresentation]);
	NSAssert1(YES == result, @"FLAC__file_decoder_set_filename failed: %s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
	
	/*
	 // Process cue sheets
	 result = FLAC__file_decoder_set_metadata_respond(flac, FLAC__METADATA_TYPE_CUESHEET);
	 NSAssert(YES == result, @"%s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
	 */
				
	// Setup callbacks
	result		= FLAC__file_decoder_set_write_callback(_flac, writeCallback);
	NSAssert1(YES == result, @"FLAC__file_decoder_set_write_callback failed: %s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
	
	result		= FLAC__file_decoder_set_metadata_callback(_flac, metadataCallback);
	NSAssert1(YES == result, @"FLAC__file_decoder_set_metadata_callback failed: %s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
	
	result		= FLAC__file_decoder_set_error_callback(_flac, errorCallback);
	NSAssert1(YES == result, @"FLAC__file_decoder_set_error_callback failed: %s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
	
	result		= FLAC__file_decoder_set_client_data(_flac, self);
	NSAssert1(YES == result, @"FLAC__file_decoder_set_client_data failed: %s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
	
	// Initialize decoder
	state = FLAC__file_decoder_init(_flac);
	NSAssert1(FLAC__FILE_DECODER_OK == state, @"FLAC__file_decoder_init failed: %s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
	
	// Process metadata
	result = FLAC__file_decoder_process_until_end_of_metadata(_flac);
	NSAssert1(YES == result, @"FLAC__file_decoder_process_until_end_of_metadata failed: %s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
	
	// Setup input format descriptor
	_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
	_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
		
	_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
	_pcmFormat.mFramesPerPacket		= 1;
	_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
	
	// We only handle a subset of the legal bitsPerChannel for FLAC
	NSAssert(8 == _pcmFormat.mBitsPerChannel || 16 == _pcmFormat.mBitsPerChannel || 24 == _pcmFormat.mBitsPerChannel || 32 == _pcmFormat.mBitsPerChannel, @"Sample size not supported");	
}

- (void) cleanupDecoder
{
	FLAC__bool					result;
	
	result = FLAC__file_decoder_finish(_flac);
	NSAssert1(YES == result, @"FLAC__file_decoder_finish failed: %s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
	
	FLAC__file_decoder_delete(_flac);		_flac = NULL;
}

- (void) fillPCMBuffer
{
	CircularBuffer				*buffer				= [self pcmBuffer];
	
	FLAC__bool					result;
	
	unsigned					blockSize;
	unsigned					channels;
	unsigned					bitsPerSample;
	unsigned					blockByteSize;
	
	
	for(;;) {
		// EOF?
		if(FLAC__FILE_DECODER_END_OF_FILE == FLAC__file_decoder_get_state(_flac)) {
			break;
		}
		
		// A problem I've run into is calculating how many times to call process_single, since
		// there is no good way to know in advance the bytes which will be required to hold a FLAC frame.
		// I'll handle it here by checking to see if there is enough space for the block
		// that was just read.  For files with varying block sizes, channels or sample depths
		// this could blow up!
		// It's not feasible to use the maximum possible values, because
		// maxBlocksize(65535) * maxBitsPerSample(32) * maxChannels(8) = 16,776,960 (No 16 MB buffers here!)
		blockSize			= FLAC__file_decoder_get_blocksize(_flac);
		channels			= FLAC__file_decoder_get_channels(_flac);
		bitsPerSample		= FLAC__file_decoder_get_bits_per_sample(_flac); 
		
		blockByteSize		= blockSize * channels * (bitsPerSample / 8);
		
		//Ensure sufficient space remains in the buffer
		if([buffer freeSpaceAvailable] >= blockByteSize) {
			result	= FLAC__file_decoder_process_single(_flac);
			NSAssert1(YES == result, @"FLAC__file_decoder_process_single failed: %s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
		}
		else {
			break;
		}
	}
}

@end

@implementation FLACStreamDecoder (Private)

- (void)	setSampleRate:(Float64)sampleRate				{ _pcmFormat.mSampleRate = sampleRate; }
- (void)	setBitsPerChannel:(UInt32)bitsPerChannel		{ _pcmFormat.mBitsPerChannel = bitsPerChannel; }
- (void)	setChannelsPerFrame:(UInt32)channelsPerFrame	{ _pcmFormat.mChannelsPerFrame = channelsPerFrame; }

@end
