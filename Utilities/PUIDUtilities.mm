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

#import "PUIDUtilities.h"
#import "AudioStream.h"

#include <ofa1/ofa.h>
#include "protocol.h"

#include <SystemConfiguration/SCNetwork.h>

#define LOCAL_MAX(a, b)			((a) > (b) ? (a) : (b))
#define LOCAL_MIN(a, b)			((a) < (b) ? (a) : (b))
#define BUFFER_LENGTH			4096
#define SECONDS_TO_PROCESS		135
#define PLAY_CLIENT_ID			"79245705acce76cd5e0e2143fce6a8a1"

BOOL
canConnectToMusicDNS()
{
	SCNetworkConnectionFlags flags;
	if(SCNetworkCheckReachabilityByName("ofa.musicdns.org", &flags)) {
		if(kSCNetworkFlagsReachable & flags && !(kSCNetworkFlagsConnectionRequired & flags))
			return YES;
	}
	
	return NO;
}

void 
calculateFingerprintAndRequestPUID(AudioStream *stream, NSModalSession modalSession)
{
	NSCParameterAssert(nil != stream);
	
	calculateFingerprintsAndRequestPUIDs([NSArray arrayWithObject:stream], modalSession);
}

void 
calculateFingerprintsAndRequestPUIDs(NSArray *streams, NSModalSession modalSession)
{
	NSCParameterAssert(nil != streams);
	
	float		scale				= (1L << (16 - 1));
	int16_t		*fingerprintBuffer	= NULL;
	
	// Allocate the AudioBufferList for the decoder to use (2 channels regardless of channels in file)
	AudioBufferList *bufferList = (AudioBufferList *)calloc(sizeof(AudioBufferList) + sizeof(AudioBuffer), 1);
	NSCAssert(NULL != bufferList, @"Unable to allocate memory");
	
	bufferList->mNumberBuffers = 2;
	
	unsigned i;
	for(i = 0; i < bufferList->mNumberBuffers; ++i) {
		bufferList->mBuffers[i].mData = calloc(BUFFER_LENGTH, sizeof(float));
		NSCAssert(NULL != bufferList->mBuffers[i].mData, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
		bufferList->mBuffers[i].mDataByteSize = BUFFER_LENGTH * sizeof(float);
		bufferList->mBuffers[i].mNumberChannels = 1;
	}
	
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
		
		AudioStreamBasicDescription		asbd				= [decoder format];
		UInt32							channelsToProcess	= LOCAL_MIN(asbd.mChannelsPerFrame, bufferList->mNumberBuffers);
		UInt32							framesToRead		= SECONDS_TO_PROCESS * asbd.mSampleRate;
		UInt32							framesRemaining		= framesToRead;
		
		// Allocate the OFA fingerprint buffer
		fingerprintBuffer = (int16_t *)calloc(channelsToProcess * framesToRead, sizeof(int16_t));
		NSCAssert(NULL != fingerprintBuffer, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Errors", @""));
		
		int16_t *fingerprintAlias = fingerprintBuffer;
		
		// Process the first SECONDS_TO_PROCESS seconds of the file
		for(;;) {
			
			// Reset read parameters
			for(i = 0; i < bufferList->mNumberBuffers; ++i)
				bufferList->mBuffers[i].mDataByteSize = BUFFER_LENGTH * sizeof(float);
			
			// Read some audio
			UInt32 framesRead = [decoder readAudio:bufferList frameCount:BUFFER_LENGTH];
			if(0 == framesRead)
				break;
			
			UInt32 framesToProcess = LOCAL_MIN(framesRead, framesRemaining);
			
			// Interleave the samples and convert to 16-bit sample size for processing
			unsigned channel, sample;
			for(sample = 0; sample < framesToProcess; ++sample) {
				for(channel = 0; channel < channelsToProcess; ++channel) {
					float *floatBuffer = (float *)bufferList->mBuffers[channel].mData;
					*fingerprintAlias++ = floatBuffer[sample] * scale;
				}
			}
			
			framesRemaining -= framesToProcess;
			
			// Terminate loop if no frames remain to be read
			if(0 == framesRemaining)
				break;
			
			// Allow user cancellation
			if(NULL != modalSession && NSRunContinuesResponse != [[NSApplication sharedApplication] runModalSession:modalSession])
				goto cleanup;
		}

		// Query MusicDNS for the PUID matching this fingerprint
		AudioData	*trackData		= new AudioData();
		NSString	*pathExtension	= [[[stream valueForKey:StreamURLKey] path] pathExtension];
		int			milliseconds	= [decoder totalFrames] / (asbd.mSampleRate / 1000);
		
#if __BIG_ENDIAN__
/*		const char *fingerprint = ofa_create_print((unsigned char *)fingerprintBuffer, 
												   OFA_BIG_ENDIAN, 
												   (channelsToProcess * (framesToRead - framesRemaining)),
												   asbd.mSampleRate, 
												   (2 == channelsToProcess));*/
		trackData->setData((unsigned char *)fingerprintBuffer, 
						   OFA_BIG_ENDIAN, 
						   (channelsToProcess * (framesToRead - framesRemaining)), 
						   asbd.mSampleRate, 
						   (2 == channelsToProcess), 
						   milliseconds, 
						   [pathExtension UTF8String]);
#else
/*		const char *fingerprint = ofa_create_print((unsigned char *)fingerprintBuffer, 
												   OFA_LITTLE_ENDIAN, 
												   (channelsToProcess * (framesToRead - framesRemaining)),
												   asbd.mSampleRate, 
												   (2 == channelsToProcess));*/
		trackData->setData((unsigned char *)fingerprintBuffer, 
						   OFA_LITTLE_ENDIAN, 
						   (channelsToProcess * (framesToRead - framesRemaining)), 
						   asbd.mSampleRate, 
						   (2 == channelsToProcess), 
						   milliseconds, 
						   [pathExtension UTF8String]);
#endif

		// Create the audio fingerprint
		if(false == trackData->createPrint()) {
			delete trackData;
			continue;
		}

		// Get the PUID
		NSString *bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
		TrackInformation *trackInfo = trackData->getMetadata(PLAY_CLIENT_ID, [bundleVersion UTF8String], true);
		if(NULL != trackInfo) {
			std::string PUID = trackInfo->getPUID();
			if(0 < PUID.length())
				[stream setValue:[NSString stringWithCString:PUID.c_str() encoding:NSASCIIStringEncoding] forKey:MetadataMusicDNSPUIDKey];			
		}
		else
			NSLog(@"Unable to retrieve MusicDNS metadata");
		
		delete trackData;

#if DEBUG
		clock_t track_end = clock();
		NSLog(@"Calculated PUID for %@ in %f seconds", stream, (track_end - track_start) / (double)CLOCKS_PER_SEC);
#endif		
	}
		
	// Free allocated memory
cleanup:
	for(i = 0; i < bufferList->mNumberBuffers; ++i)
		free(bufferList->mBuffers[i].mData);
	free(bufferList);
}
