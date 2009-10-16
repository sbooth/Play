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

#import "OggVorbisDecoder.h"
#import "AudioStream.h"

@implementation OggVorbisDecoder

- (id) initWithURL:(NSURL *)url error:(NSError **)error
{
	NSParameterAssert(nil != url);
	
	if((self = [super initWithURL:url error:error])) {
		FILE *file = fopen([[[self URL] path] fileSystemRepresentation], "r");
		NSAssert1(NULL != file, @"Unable to open the input file (%s).", strerror(errno));	
		
		int result = ov_test(file, &_vf, NULL, 0);
		NSAssert(0 == result, NSLocalizedStringFromTable(@"The file does not appear to be a valid Ogg Vorbis file.", @"Errors", @""));
		
		result = ov_test_open(&_vf);
		NSAssert(0 == result, NSLocalizedStringFromTable(@"Unable to open the input file.", @"Errors", @""));
		
		vorbis_info *ovInfo = ov_info(&_vf, -1);
		NSAssert(NULL != ovInfo, @"Unable to get information on Ogg Vorbis stream.");
		
		_format.mSampleRate			= ovInfo->rate;
		_format.mChannelsPerFrame	= ovInfo->channels;
		
		switch(ovInfo->channels) {
			// Default channel layouts from Vorbis I specification section 4.3.9
			case 1:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;				break;
			case 2:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;			break;
				// FIXME: Is this the right tag for 3 channels?
			case 3:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_MPEG_3_0_A;		break;
			case 4:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Quadraphonic;		break;
			case 5:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_MPEG_5_0_C;		break;
			case 6:		_channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_MPEG_5_1_C;		break;
		}
	}
	return self;
}

- (void) dealloc
{
	int result = ov_clear(&_vf); 
	if(0 != result)
		NSLog(@"ov_clear failed");
	
	[super dealloc];
}

- (SInt64)			totalFrames						{ return ov_pcm_total(&_vf, -1); }
- (SInt64)			currentFrame					{ return ov_pcm_tell(&_vf); }

- (BOOL)			supportsSeeking					{ return YES; }

- (SInt64) seekToFrame:(SInt64)frame
{
	NSParameterAssert(0 <= frame && frame < [self totalFrames]);
	
	int result = ov_pcm_seek(&_vf, frame);
	if(result)
		return -1;
	
	return [self currentFrame];
}

- (UInt32) readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount
{
	NSParameterAssert(NULL != bufferList);
	NSParameterAssert(bufferList->mNumberBuffers == _format.mChannelsPerFrame);
	NSParameterAssert(0 < frameCount);
	
	int16_t		*buffer			= calloc(frameCount * _format.mChannelsPerFrame, sizeof(int16_t));
	unsigned	bufferSize		= frameCount * _format.mChannelsPerFrame * sizeof(int16_t);
	
	if(NULL == buffer) {
		NSLog(@"Unable to allocate memory");
		return 0;
	}
	
	int			currentSection	= 0;	
	long		currentBytes	= 0;
	long		bytesRead		= 0;
	char		*readPtr		= (char *)buffer;
	
	for(;;) {
#if __BIG_ENDIAN__
		currentBytes = ov_read(&_vf, readPtr + bytesRead, bufferSize - bytesRead, YES, sizeof(int16_t), YES, &currentSection);
#else
		currentBytes = ov_read(&_vf, readPtr + bytesRead, bufferSize - bytesRead, NO, sizeof(int16_t), YES, &currentSection);
#endif
		
		if(0 > currentBytes) {
			NSLog(@"Ogg Vorbis decode error");
			free(buffer);
			return 0;
		}
		
		bytesRead += currentBytes;
		
		if(0 == currentBytes || 0 == bufferSize - bytesRead)
			break;
	}
	
	unsigned	framesRead		= (bytesRead / sizeof(int16_t)) / _format.mChannelsPerFrame;
	float		scaleFactor		= (1L << (16 - 1));
	int16_t		rawSample		= 0;
	unsigned	channel, sample;
	
	// Deinterleave the 16-bit samples and convert to float
	for(channel = 0; channel < _format.mChannelsPerFrame; ++channel) {
		float *floatBuffer = bufferList->mBuffers[channel].mData;
		
		for(sample = channel; sample < framesRead * _format.mChannelsPerFrame; sample += _format.mChannelsPerFrame) {
			rawSample = buffer[sample];
			*floatBuffer++ = (float)(rawSample / scaleFactor);
		}
		
		bufferList->mBuffers[channel].mNumberChannels	= 1;
		bufferList->mBuffers[channel].mDataByteSize		= framesRead * sizeof(float);
	}
	
	free(buffer);
	
	return framesRead;
}

- (NSString *) sourceFormatDescription
{
	return [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@, %u channels, %u Hz", @"Formats", @""), NSLocalizedStringFromTable(@"Ogg Vorbis", @"Formats", @""), [self format].mChannelsPerFrame, (unsigned)[self format].mSampleRate];
}

@end
