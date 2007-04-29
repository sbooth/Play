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

#import "MusepackStreamDecoder.h"
#import "AudioStream.h"

@implementation MusepackStreamDecoder

- (NSString *) sourceFormatDescription
{
	return [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@, %u channels, %u Hz", @"Formats", @""), NSLocalizedStringFromTable(@"Musepack", @"Formats", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate];
}

- (BOOL) supportsSeeking
{
	return YES;
}

- (SInt64) performSeekToFrame:(SInt64)frame
{
	mpc_bool_t		result		= mpc_decoder_seek_sample(&_decoder, frame);
	return (result ? frame : -1);
}

- (BOOL) setupDecoder:(NSError **)error
{
	mpc_streaminfo					streaminfo;
	mpc_int32_t						intResult;
	mpc_bool_t						boolResult;
	
	[super setupDecoder:error];

	_file							= fopen([[[[self stream] valueForKey:StreamURLKey] path] fileSystemRepresentation], "r");
	if(NULL == _file) {		
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" could not be found.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:[[[self stream] valueForKey:StreamURLKey] path]]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"File Not Found", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file may have been renamed or deleted, or exist on removable media.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:AudioStreamDecoderErrorDomain 
										 code:AudioStreamDecoderFileFormatNotRecognizedError 
									 userInfo:errorDictionary];
		}
		return NO;
	}
	
	mpc_reader_setup_file_reader(&_reader_file, _file);
	
	// Get input file information
	mpc_streaminfo_init(&streaminfo);
	intResult						= mpc_streaminfo_read(&streaminfo, &_reader_file.reader);
	if(ERROR_CODE_OK != intResult) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" is not a valid Musepack file.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:[[[self stream] valueForKey:StreamURLKey] path]]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Not a Musepack file", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"The file's extension may not match the file's type.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];						
		}
		fclose(_file), _file = NULL;
		return NO;
	}
	
	// Set up the decoder
	mpc_decoder_setup(&_decoder, &_reader_file.reader);
	boolResult = mpc_decoder_initialize(&_decoder, &streaminfo);
	NSAssert(YES == boolResult, NSLocalizedStringFromTable(@"Unable to intialize the Musepack decoder.", @"Errors", @""));
	
	// MPC doesn't have default channel mappings so for now only support mono and stereo
/*	if(1 != streaminfo.channels && 2 != streaminfo.channels) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			NSString				*path				= [[[self stream] valueForKey:StreamURLKey] path];
			
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The format of the file \"%@\" is not supported.", @"Errors", @""), [[NSFileManager defaultManager] displayNameAtPath:path]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Unsupported Musepack format", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"Only mono and stereo is supported for Musepack.", @"Errors", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:AudioStreamDecoderErrorDomain 
										 code:AudioStreamDecoderFileFormatNotSupportedError 
									 userInfo:errorDictionary];
		}		
		
		return NO;
	}*/
	
	[self setTotalFrames:mpc_streaminfo_get_length_samples(&streaminfo)];

	// Setup input format descriptor
	_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
	_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
	
	_pcmFormat.mSampleRate			= streaminfo.sample_freq;
	_pcmFormat.mChannelsPerFrame	= streaminfo.channels;
	_pcmFormat.mBitsPerChannel		= 16;
	
	_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
	_pcmFormat.mFramesPerPacket		= 1;
	_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
	
	// Setup the channel layout
//	_channelLayout.mChannelLayoutTag  = (1 == _pcmFormat.mChannelsPerFrame ? kAudioChannelLayoutTag_Mono : kAudioChannelLayoutTag_Stereo);

	return YES;
}

- (BOOL) cleanupDecoder:(NSError **)error
{
	if(NULL != _file) {
		int result = fclose(_file);
		NSAssert1(EOF != result, @"Unable to close the input file (%s).", strerror(errno));	
		_file = NULL;
	}
	
	[super cleanupDecoder:error];
	
	return YES;
}

- (void) fillPCMBuffer
{
	UInt32				bytesToWrite, bytesAvailableToWrite;
	UInt32				spaceRequired;
	void				*writePointer;
	MPC_SAMPLE_FORMAT	mpcBuffer [MPC_DECODER_BUFFER_LENGTH];
	mpc_uint32_t		framesRead;
	unsigned			sample;
	
	for(;;) {
		bytesToWrite				= RING_BUFFER_WRITE_CHUNK_SIZE;
		bytesAvailableToWrite		= [[self pcmBuffer] lengthAvailableToWriteReturningPointer:&writePointer];
		spaceRequired				= MPC_FRAME_LENGTH * [self pcmFormat].mChannelsPerFrame * ([self pcmFormat].mBitsPerChannel / 8);	
		
		if(bytesAvailableToWrite < bytesToWrite || spaceRequired > bytesAvailableToWrite) {
			break;
		}
				
		// Decode the data
		framesRead		= mpc_decoder_decode(&_decoder, mpcBuffer, 0, 0);
//		NSAssert((mpc_uint32_t)-1 != framesRead, NSLocalizedStringFromTable(@"Musepack decoding error.", @"Errors", @""));
		if((mpc_uint32_t)-1 == framesRead) {
			NSLog(NSLocalizedStringFromTable(@"Musepack decoding error.", @"Errors", @""));
			return;
		}
					
#ifdef MPC_FIXED_POINT
	#error "Fixed point not yet supported"
#else
		int32_t					audioSample			= 0;
		int8_t					*alias8				= NULL;
		int16_t					*alias16			= NULL;
		int32_t					*alias32			= NULL;
		int32_t					clipMin				= -1 << ([self pcmFormat].mBitsPerChannel - 1);
		int32_t					clipMax				= (1 << ([self pcmFormat].mBitsPerChannel - 1)) - 1;
		
		switch([self pcmFormat].mBitsPerChannel) {
			
			case 8:
				
				// No need for byte swapping
				alias8 = writePointer;
				for(sample = 0; sample < framesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
					audioSample		= mpcBuffer[sample] * (1 << 7);
					audioSample		= (audioSample < clipMin ? clipMin : (audioSample > clipMax ? clipMax : audioSample));
					*alias8++		= (int8_t)audioSample;
				}
					
				[[self pcmBuffer] didWriteLength:framesRead * [self pcmFormat].mChannelsPerFrame * sizeof(int8_t)];
				
				break;
				
			case 16:
				
				// Convert to big endian byte order 
				alias16 = writePointer;
				for(sample = 0; sample < framesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
					audioSample		= mpcBuffer[sample] * (1 << 15);
					audioSample		= (audioSample < clipMin ? clipMin : (audioSample > clipMax ? clipMax : audioSample));
					*alias16++		= (int16_t)OSSwapHostToBigInt16(audioSample);
				}
					
				[[self pcmBuffer] didWriteLength:framesRead * [self pcmFormat].mChannelsPerFrame * sizeof(int16_t)];
				
				break;
				
			case 24:
				
				// Convert to big endian byte order 
				alias8 = writePointer;
				for(sample = 0; sample < framesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
					audioSample		= mpcBuffer[sample] * (1 << 23);
					audioSample		= (audioSample < clipMin ? clipMin : (audioSample > clipMax ? clipMax : audioSample));
					audioSample		= OSSwapHostToBigInt32(audioSample);
					*alias8++		= (int8_t)(audioSample >> 16);
					*alias8++		= (int8_t)(audioSample >> 8);
					*alias8++		= (int8_t)audioSample;
				}
					
				[[self pcmBuffer] didWriteLength:framesRead * [self pcmFormat].mChannelsPerFrame * 3 * sizeof(int8_t)];
				
				break;
				
			case 32:
				
				// Convert to big endian byte order 
				alias32 = writePointer;
				for(sample = 0; sample < framesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
					audioSample		= mpcBuffer[sample] * (1 << 31);
					audioSample		= (audioSample < clipMin ? clipMin : (audioSample > clipMax ? clipMax : audioSample));
					*alias32++		= OSSwapHostToBigInt32(audioSample);
				}
					
				[[self pcmBuffer] didWriteLength:framesRead * [self pcmFormat].mChannelsPerFrame * sizeof(int32_t)];
				
				break;
				
			default:
				@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
				break;	
		}
#endif /* MPC_FIXED_POINT */
		
		// EOS?
		if(0 == framesRead) {
			[self setAtEndOfStream:YES];
			break;
		}		
	}
}

@end
