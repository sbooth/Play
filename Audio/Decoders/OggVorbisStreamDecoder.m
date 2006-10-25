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

#import "OggVorbisStreamDecoder.h"

@implementation OggVorbisStreamDecoder

- (NSString *)		sourceFormatDescription			{ return [NSString stringWithFormat:@"%@, %u channels, %u Hz", NSLocalizedStringFromTable(@"Ogg (Vorbis)", @"General", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate]; }

- (SInt64) seekToFrame:(SInt64)frame
{
	int							result;
	
	result						= ov_pcm_seek(&_vf, frame); 
	
	if(0 != result) {
		return -1;
	}
	
	[[self pcmBuffer] reset]; 
	[self setCurrentFrame:frame];	
	
	return frame;	
}

- (BOOL) readProperties:(NSError **)error
{
	NSMutableDictionary				*propertiesDictionary;
	NSString						*path;
	OggVorbis_File					vf;
	vorbis_info						*ovInfo;
	FILE							*file;
	int								result;
	ogg_int64_t						totalFrames;
	long							bitrate;
	
	path							= [[self valueForKey:@"url"] path];
	file							= fopen([path fileSystemRepresentation], "r");

	if(NULL == file) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"Unable to open the file \"%@\".", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Unable to open" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file may have been moved or you may not have read permission." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioStreamDecoderErrorDomain 
														  code:AudioStreamDecoderInputOutputError 
													  userInfo:errorDictionary];
		}
		
		return NO;
	}
	
	result							= ov_test(file, &vf, NULL, 0);
	
	if(0 != result) {
		if(nil != error) {
			NSMutableDictionary		*errorDictionary	= [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:[NSString stringWithFormat:@"The file \"%@\" is not a valid Ogg (Vorbis) file.", [path lastPathComponent]] forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:@"Not an Ogg (Vorbis) file" forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:@"The file's extension may not match the file's type." forKey:NSLocalizedRecoverySuggestionErrorKey];						
			
			*error					= [NSError errorWithDomain:AudioStreamDecoderErrorDomain 
														  code:AudioStreamDecoderFileFormatNotRecognizedError 
													  userInfo:errorDictionary];
		}
		
		result			= fclose(file);
		NSAssert1(EOF != result, @"Unable to close the input file (%s).", strerror(errno));	
		
		return NO;
	}
	
	result							= ov_test_open(&vf);
	NSAssert(0 == result, NSLocalizedStringFromTable(@"Unable to open the input file.", @"Exceptions", @""));
	
	// Get input file information
	ovInfo							= ov_info(&vf, -1);
	
	NSAssert(NULL != ovInfo, @"Unable to get information on Ogg Vorbis stream.");

	totalFrames						= ov_pcm_total(&vf, -1);
	bitrate							= ov_bitrate(&vf, -1);
	
	propertiesDictionary			= [NSMutableDictionary dictionary];
	
	[propertiesDictionary setValue:[NSString stringWithFormat:@"Ogg (Vorbis), %u channels, %u Hz", ovInfo->channels, ovInfo->rate] forKey:@"formatName"];
	[propertiesDictionary setValue:[NSNumber numberWithLongLong:totalFrames] forKey:@"totalFrames"];
	[propertiesDictionary setValue:[NSNumber numberWithLong:bitrate] forKey:@"averageBitrate"];
//	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:16] forKey:@"bitsPerChannel"];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:ovInfo->channels] forKey:@"channelsPerFrame"];
	[propertiesDictionary setValue:[NSNumber numberWithUnsignedInt:ovInfo->rate] forKey:@"sampleRate"];				
	
	[self setValue:propertiesDictionary forKey:@"properties"];
	
	result							= ov_clear(&vf);
	NSAssert(0 == result, NSLocalizedStringFromTable(@"Unable to close the input file.", @"Exceptions", @""));
	
	return YES;
}

- (void) setupDecoder
{
	vorbis_info						*ovInfo;
	FILE							*file;
	int								result;
	
	file							= fopen([[[self valueForKey:@"url"] path] fileSystemRepresentation], "r");
	NSAssert1(NULL != file, @"Unable to open the input file (%s).", strerror(errno));	
	
	result							= ov_test(file, &_vf, NULL, 0);
	NSAssert(0 == result, NSLocalizedStringFromTable(@"The file does not appear to be a valid Ogg Vorbis file.", @"Exceptions", @""));
	
	result							= ov_test_open(&_vf);
	NSAssert(0 == result, NSLocalizedStringFromTable(@"Unable to open the input file.", @"Exceptions", @""));
	
	// Get input file information
	ovInfo							= ov_info(&_vf, -1);
	
	NSAssert(NULL != ovInfo, @"Unable to get information on Ogg Vorbis stream.");
	
	[self setTotalFrames:ov_pcm_total(&_vf, -1)];

	// Setup input format descriptor
	_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
	_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
	
	_pcmFormat.mSampleRate			= ovInfo->rate;
	_pcmFormat.mChannelsPerFrame	= ovInfo->channels;
	_pcmFormat.mBitsPerChannel		= 16;
	
	_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
	_pcmFormat.mFramesPerPacket		= 1;
	_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
}

- (void) cleanupDecoder
{
	int							result;
	
	result						= ov_clear(&_vf); 
	
	if(0 != result) {
		NSLog(@"ov_clear failed");
	}
}

- (void) fillPCMBuffer
{
	CircularBuffer		*buffer;
	long				bytesRead;
	long				totalBytes;
	void				*rawBuffer;
	unsigned			availableSpace;
	int					currentSection;
	
	buffer				= [self pcmBuffer];
	rawBuffer			= [buffer exposeBufferForWriting];
	availableSpace		= [buffer freeSpaceAvailable];
	totalBytes			= 0;
	currentSection		= 0;
	
	for(;;) {
		bytesRead		= ov_read(&_vf, rawBuffer + totalBytes, availableSpace - totalBytes, YES, sizeof(int16_t), YES, &currentSection);

		NSAssert(0 <= bytesRead, @"Ogg Vorbis decode error.");
		
		totalBytes += bytesRead;

		if(0 == bytesRead || totalBytes >= availableSpace) {
			break;
		}
	}

	[buffer wroteBytes:totalBytes];
}

@end
