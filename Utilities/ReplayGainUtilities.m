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
#import "AudioDecoderMethods.h"

#include "replaygain_analysis.h"

#define LOCAL_MAX(a, b)			((a) > (b) ? (a) : (b))
#define LOCAL_MIN(a, b)			((a) < (b) ? (a) : (b))
#define BUFFER_LENGTH			4096

void 
calculateReplayGain(NSArray *streams, BOOL calculateAlbumGain, NSModalSession modalSession)
{
	NSCParameterAssert(nil != streams);
	
	Float64			sampleRate		= 0;
	float			scale			= (1L << (16 - 1));
	float			albumPeak		= 0;
	float			*rgBuffers		[2];
	
	// Allocate RG buffers (only two are needed because the RG analysis code only works on mono or stereo)
	rgBuffers[0] = (float *)calloc(BUFFER_LENGTH, sizeof(float));
	NSCAssert(NULL != rgBuffers[0], NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	
	rgBuffers[1] = (float *)calloc(BUFFER_LENGTH, sizeof(float));
	NSCAssert(NULL != rgBuffers[1], NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
	
	// Allocate the AudioBufferList for the decoder to use (2 channels regardless of channels in file)
	AudioBufferList *bufferList = calloc(sizeof(AudioBufferList) + sizeof(AudioBuffer), 1);
	NSCAssert(NULL != bufferList, @"Unable to allocate memory");
	
	bufferList->mNumberBuffers = 2;
	
	unsigned i;
	for(i = 0; i < bufferList->mNumberBuffers; ++i) {
		bufferList->mBuffers[i].mData = calloc(BUFFER_LENGTH, sizeof(float));
		NSCAssert(NULL != bufferList->mBuffers[i].mData, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
		bufferList->mBuffers[i].mDataByteSize = BUFFER_LENGTH * sizeof(float);
		bufferList->mBuffers[i].mNumberChannels = 1;
	}
	
#if DEBUG
	clock_t album_start = clock();
#endif
	
	for(AudioStream *stream in streams) {
		
#if DEBUG
		clock_t track_start = clock();
#endif
		
		id <AudioDecoderMethods> decoder = [stream decoder:nil];
		
		// Skip this stream if any errors occurred
		if(nil == decoder)
			continue;
		
		// Also skip this stream if it is not mono or stereo
		if(1 != [decoder format].mChannelsPerFrame && 2 != [decoder format].mChannelsPerFrame)
			continue;
		
		// To avoid parameter errors from the decoders, set the number of buffer to the number of channels
		bufferList->mNumberBuffers = [decoder format].mChannelsPerFrame;
		
		// Init RG analysis for the first stream to be analyzed
		if(0 == sampleRate) {
			sampleRate = [decoder format].mSampleRate;
			
			int result = InitGainAnalysis((long)sampleRate);
			if(INIT_GAIN_ANALYSIS_OK != result)
				goto cleanup;
		}
		
		// If the sample rate changed, adjust accordingly
		if([decoder format].mSampleRate != sampleRate) {
			sampleRate = [decoder format].mSampleRate;
			
			int result = ResetSampleFrequency((long)sampleRate);
			if(INIT_GAIN_ANALYSIS_OK != result)
				goto cleanup;			
		}
		
		AudioStreamBasicDescription		asbd				= [decoder format];
		float							trackPeak			= 0;
		UInt32							channelsToProcess	= LOCAL_MIN(asbd.mChannelsPerFrame, bufferList->mNumberBuffers);
		
		// Process the file
		for(;;) {
			// Reset read parameters
			for(i = 0; i < bufferList->mNumberBuffers; ++i)
				bufferList->mBuffers[i].mDataByteSize = BUFFER_LENGTH * sizeof(float);
			
			// Read some audio
			UInt32 framesRead = [decoder readAudio:bufferList frameCount:BUFFER_LENGTH];
			if(0 == framesRead)
				break;
			
			unsigned channel, sample;
			for(channel = 0; channel < channelsToProcess; ++channel) {
				float *floatBuffer = (float *)bufferList->mBuffers[channel].mData;
				for(sample = 0; sample < framesRead; ++sample) {
					rgBuffers[channel][sample] =  floatBuffer[sample] * scale;
					trackPeak = LOCAL_MAX(trackPeak, fabsf(floatBuffer[sample]));
				}
			}
			
			// Submit the data to the RG analysis engine
			int result = AnalyzeSamples(rgBuffers[0], (1 == channelsToProcess ? NULL : rgBuffers[1]), framesRead, channelsToProcess);
			if(GAIN_ANALYSIS_OK != result)
				goto cleanup;
			
			// Allow user cancellation
			if(NULL != modalSession && NSRunContinuesResponse != [[NSApplication sharedApplication] runModalSession:modalSession])
				goto cleanup;
		}
		
		// Get the track's gain
		[stream setValue:[NSNumber numberWithFloat:GetTitleGain()] forKey:ReplayGainTrackGainKey];
		[stream setValue:[NSNumber numberWithFloat:ReplayGainReferenceLoudness] forKey:ReplayGainReferenceLoudnessKey];
		[stream setValue:[NSNumber numberWithFloat:trackPeak] forKey:ReplayGainTrackPeakKey];
		
		if(calculateAlbumGain)
			albumPeak = LOCAL_MAX(albumPeak, trackPeak);
		
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
		double elapsed = (album_end - album_start) / (double)CLOCKS_PER_SEC;
		NSLog(@"Calculated album ReplayGain in %f seconds (%f seconds per track)", elapsed, elapsed / [streams count]);
#endif		
	}
	
	// Free allocated memory
cleanup:
	free(rgBuffers[0]);
	free(rgBuffers[1]);
	for(i = 0; i < bufferList->mNumberBuffers; ++i)
		free(bufferList->mBuffers[i].mData);
	free(bufferList);
}
