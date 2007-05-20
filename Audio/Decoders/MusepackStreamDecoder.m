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
	_pcmFormat.mFormatFlags			= kAudioFormatFlagsNativeFloatPacked;
	
	_pcmFormat.mSampleRate			= streaminfo.sample_freq;
	_pcmFormat.mChannelsPerFrame	= streaminfo.channels;
	_pcmFormat.mBitsPerChannel		= 32;
	
	_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
	_pcmFormat.mFramesPerPacket		= 1;
	_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
	
	// Setup the channel layout
	switch(streaminfo.channels) {
		case 1:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;				break;
		case 2:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;			break;
	}
	
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
	void				*writePointer;
	MPC_SAMPLE_FORMAT	mpcBuffer [MPC_DECODER_BUFFER_LENGTH];
	
	for(;;) {
		UInt32	bytesToWrite			= RING_BUFFER_WRITE_CHUNK_SIZE;
		UInt32	bytesAvailableToWrite	= [[self pcmBuffer] lengthAvailableToWriteReturningPointer:&writePointer];
		UInt32	spaceRequired			= MPC_FRAME_LENGTH * [self pcmFormat].mChannelsPerFrame * ([self pcmFormat].mBitsPerChannel / 8);	
		
		if(bytesAvailableToWrite < bytesToWrite || spaceRequired > bytesAvailableToWrite) {
			break;
		}
				
		// Decode the data
		mpc_uint32_t framesRead = mpc_decoder_decode(&_decoder, mpcBuffer, 0, 0);
		if((mpc_uint32_t)-1 == framesRead) {
			NSLog(NSLocalizedStringFromTable(@"Musepack decoding error.", @"Errors", @""));
			return;
		}
					
#ifdef MPC_FIXED_POINT
	#error "Fixed point not yet supported"
#else
		float		*floatBuffer	= (float *)writePointer;
		float		audioSample		= 0;
		unsigned	sample			= 0;
		
		for(sample = 0; sample < framesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
			audioSample		= mpcBuffer[sample];
			*floatBuffer++	= (audioSample < -1.0 ? -1.0 : (audioSample > 1.0 ? 1.0 : audioSample));
		}

		[[self pcmBuffer] didWriteLength:framesRead * [self pcmFormat].mChannelsPerFrame * (32 / 8)];
#endif /* MPC_FIXED_POINT */
		
		// EOS?
		if(0 == framesRead) {
			[self setAtEndOfStream:YES];
			break;
		}		
	}
}

@end
