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

#import <Cocoa/Cocoa.h>
#include <AudioToolbox/AudioToolbox.h>

@class AudioLibrary;
@class AudioStream;
@class AudioScheduler;
@class AudioDecoder;

// ========================================
// Error Codes
// ========================================
extern NSString * const			AudioPlayerErrorDomain;

enum {
	AudioPlayerInternalError							= 0,
	AudioPlayerFileFormatNotSupportedError				= 1,
	AudioPlayerInputOutputError							= 2
};

// ========================================
// User Defaults tag values
// ========================================
enum {
	// ReplayGain
	ReplayGainNone			= 0,
	ReplayGainTrackGain		= 1,
	ReplayGainAlbumGain		= 2,
	
	// Clipping behavior
	HardLimiting			= 0,
	ReducePreAmpGain		= 1
};

@interface AudioPlayer : NSObject
{
	AUGraph					_auGraph;

	AUNode					_generatorNode;
	AUNode					_limiterNode;
	AUNode					_outputNode;
	
	AudioUnit				_generatorUnit;
	AudioUnit				_limiterUnit;
	AudioUnit				_outputUnit;
	
	AudioScheduler			*_scheduler;
	
	SInt64					_startingFrame;
	SInt64					_playingFrame;
	SInt64					_totalFrames;
	SInt64					_regionStartingFrame;
	
	NSTimer					*_timer;
	AUEventListenerRef		_auEventListener;
	
	AudioStreamBasicDescription _format;
	AudioChannelLayout			_channelLayout;

	BOOL					_hasReplayGain;
	float					_replayGain;
	float					_preAmplification;
		
	BOOL					_playing;

	AudioLibrary			*_owner;
	NSRunLoop				*_runLoop;
}

- (AudioLibrary *)	owner;
- (void)			setOwner:(AudioLibrary *)owner;

- (BOOL)			setStream:(AudioStream *)stream error:(NSError **)error;
- (BOOL)			setNextStream:(AudioStream *)stream error:(NSError **)error;

- (void)			reset;

- (BOOL)			hasValidStream;
- (BOOL)			streamSupportsSeeking;

- (void)			play;
- (void)			playPause;
- (void)			pause;
- (void)			stop;

- (void)			skipForward;
- (void)			skipBackward;
- (void)			skipForward:(UInt32)seconds;
- (void)			skipBackward:(UInt32)seconds;

- (void)			skipToEnd;
- (void)			skipToBeginning;

- (BOOL)			isPlaying;

- (Float32)			volume;
- (void)			setVolume:(Float32)volume;

- (BOOL)			hasReplayGain;

- (float)			replayGain;

- (float)			preAmplification;
- (void)			setPreAmplification:(float)preAmplification;

- (AudioStreamBasicDescription) format;
- (AudioChannelLayout) channelLayout;

- (void)			saveStateToDefaults;
- (void)			restoreStateFromDefaults;

// ========================================
// Values available for UI binding
- (SInt64)			totalFrames;

- (SInt64)			currentFrame;
- (void)			setCurrentFrame:(SInt64)currentFrame;

- (SInt64)			framesRemaining;

- (NSTimeInterval)	totalSeconds;
- (NSTimeInterval)	currentSecond;
- (NSTimeInterval)	secondsRemaining;

@end

// ========================================
// Key names for DSP effects
// ========================================
extern NSString * const		AUTypeKey;
extern NSString * const		AUSubTypeKey;
extern NSString * const		AUManufacturerKey;
extern NSString * const		AUNameStringKey;
extern NSString * const		AUManufacturerStringKey;
extern NSString * const		AUNameAndManufacturerStringKey;
extern NSString * const		AUInformationStringKey;
extern NSString * const		AUIconKey;
extern NSString * const		AUClassDataKey;
extern NSString * const		AUNodeKey;

// ========================================
// DSP effect support
// ========================================
@interface AudioPlayer (DSPMethods)
- (NSArray *) currentEffects;
- (NSArray *) availableEffects;

- (AudioUnit) audioUnitForAUNode:(AUNode)node;
- (BOOL) addEffectToAUGraph:(NSDictionary *)auDictionary newNode:(AUNode *)newNode error:(NSError **)error;
- (BOOL) removeEffectFromAUGraph:(AUNode)effectNode error:(NSError **)error;
@end

