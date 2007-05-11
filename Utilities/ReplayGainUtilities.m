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

#import "ReplayGainUtilities.h"
#import "AudioStream.h"
#import "AudioStreamDecoder.h"

#include "replaygain_analysis.h"

#define LOCAL_MAX(a, b)			((a) > (b) ? (a) : (b))
#define BUFFER_LENGTH			4096

void 
calculateReplayGain(NSArray *streams, BOOL calculateAlbumGain, NSModalSession modalSession)
{
	NSCParameterAssert(nil != streams);
	
	NSEnumerator			*enumerator		= [streams objectEnumerator];
	AudioStream				*stream			= nil;
	AudioStreamDecoder		*decoder		= nil;
	AudioBufferList			bufferList;
	Float64					sampleRate		= 0;
	float					scale			= (1L << (16 - 1));
	float					albumPeak		= 0;
	
	
	// Allocate RG buffers (only two are needed because the RG analysis code only works on mono or stereo)
	float *leftSamples = (float *)calloc(BUFFER_LENGTH, sizeof(float));
	NSCAssert(NULL != leftSamples, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));

	float *rightSamples = (float *)calloc(BUFFER_LENGTH, sizeof(float));
	NSCAssert(NULL != rightSamples, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	
	// Allocate the AudioBufferList for the decoder
	float *buffer = (float *)calloc(BUFFER_LENGTH, sizeof(float));
	NSCAssert(NULL != buffer, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	
	bufferList.mNumberBuffers		= 1;
	bufferList.mBuffers[0].mData	= buffer;

#if DEBUG
	clock_t album_start = clock();
#endif
	
	while((stream = [enumerator nextObject])) {

#if DEBUG
		clock_t track_start = clock();
#endif
		
		decoder = [AudioStreamDecoder streamDecoderForStream:stream error:nil];
		
		// Skip this stream if any errors occur
		if(nil == decoder || NO == [decoder startDecoding:nil]) {
			continue;
		}
		
		// Also skip this stream if it is no mono or stereo
		if(1 != [decoder pcmFormat].mChannelsPerFrame && 2 != [decoder pcmFormat].mChannelsPerFrame) {
			continue;
		}

		// Init RG analysis for the first stream to be analyzed
		if(0 == sampleRate) {
			sampleRate = [decoder pcmFormat].mSampleRate;
			
			int result = InitGainAnalysis((long)sampleRate);
			if(INIT_GAIN_ANALYSIS_OK != result) {
				[decoder stopDecoding:nil];
				goto cleanup;
			}
		}
		
		// If the sample rate changed, adjust accordingly
		if([decoder pcmFormat].mSampleRate != sampleRate) {
			sampleRate = [decoder pcmFormat].mSampleRate;

			int result = ResetSampleFrequency((long)sampleRate);
			if(INIT_GAIN_ANALYSIS_OK != result) {
				[decoder stopDecoding:nil];
				goto cleanup;
			}
			
		}
		
		AudioStreamBasicDescription		asbd			= [decoder pcmFormat];
		float							trackPeak		= 0;

		// Process the file
		for(;;) {
			// Reset read parameters
			bufferList.mBuffers[0].mDataByteSize = BUFFER_LENGTH * sizeof(float);
			
			UInt32 framesRead = [decoder readAudio:&bufferList frameCount:(bufferList.mBuffers[0].mDataByteSize / asbd.mBytesPerFrame)];
			
			if(0 == framesRead && [decoder atEndOfStream]) {
				break;
			}
			
			// For mono files just pass the data through
			if(1 == asbd.mChannelsPerFrame) {
				
				// De-normalize float to 16-bit integer range
				unsigned i;
				for(i = 0; i < framesRead; ++i) {
					leftSamples[i] = buffer[i] * scale;
					trackPeak = LOCAL_MAX(trackPeak, fabsf(buffer[i]));
				}
				
				int result = AnalyzeSamples(leftSamples, NULL, framesRead, 1);
				if(GAIN_ANALYSIS_OK != result) {
					[decoder stopDecoding:nil];
					goto cleanup;
				}
			}
			// Otherwise, de-interleave and de-normalize the stereo
			else if(2 == asbd.mChannelsPerFrame) {
				unsigned i;
				for(i = 0; i < framesRead; ++i) {
					leftSamples[i]		= buffer[2 * i] * scale;
					trackPeak			= LOCAL_MAX(trackPeak, fabsf(buffer[2 * i]));
					
					rightSamples[i]		= buffer[(2 * i) + 1] * scale;
					trackPeak			= LOCAL_MAX(trackPeak, fabsf(buffer[2 * i]));
				}
				
				int result = AnalyzeSamples(leftSamples, rightSamples, framesRead, 2);
				if(GAIN_ANALYSIS_OK != result) {
					[decoder stopDecoding:nil];
					goto cleanup;
				}
			}
			
			// Allow user cancellation
			if(NULL != modalSession && NSRunContinuesResponse != [[NSApplication sharedApplication] runModalSession:modalSession]) {
				[decoder stopDecoding:nil];
				goto cleanup;
			}			
		}
		
		// Get the track's gain
		[stream setValue:[NSNumber numberWithFloat:GetTitleGain()] forKey:ReplayGainTrackGainKey];
		[stream setValue:[NSNumber numberWithFloat:ReplayGainReferenceLoudness] forKey:ReplayGainReferenceLoudnessKey];
		[stream setValue:[NSNumber numberWithFloat:trackPeak] forKey:ReplayGainTrackPeakKey];
		
		if(calculateAlbumGain) {
			albumPeak = LOCAL_MAX(albumPeak, trackPeak);
		}
		
		// Stop decoding
		/*BOOL result =*/ [decoder stopDecoding:nil];
		
#if DEBUG
		clock_t track_end = clock();
		NSLog(@"Calculated ReplayGain for %@ in %f seconds", stream, (track_end - track_start) / (double)CLOCKS_PER_SEC);
#endif		
	}
	
	if(calculateAlbumGain) {
		[streams setValue:[NSNumber numberWithFloat:GetAlbumGain()] forKey:ReplayGainAlbumGainKey];
		[streams setValue:[NSNumber numberWithFloat:albumPeak] forKey:ReplayGainAlbumPeakKey];

#if DEBUG
		clock_t album_end = clock();
		NSLog(@"Calculated album ReplayGain in %f seconds", (album_end - album_start) / (double)CLOCKS_PER_SEC);
#endif		
	}

cleanup:
	free(leftSamples);
	free(rightSamples);
	free(buffer);
}
