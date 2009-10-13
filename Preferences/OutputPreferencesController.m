/*
 *  $Id$
 *
 *  Copyright (C) 2005 - 2007 Stephen F. Booth <me@sbooth.org>
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

#import "OutputPreferencesController.h"
#include <CoreAudio/CoreAudio.h>

@implementation OutputPreferencesController

- (id) init
{
	if((self = [super initWithWindowNibName:@"OutputPreferences"])) {
		_outputDevices = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) dealloc
{
	[_outputDevices release], _outputDevices = nil;
	[super dealloc];
}

- (void) awakeFromNib
{
	UInt32 specifierSize = 0;
	OSStatus status = AudioHardwareGetPropertyInfo(kAudioHardwarePropertyDevices, &specifierSize, NULL);
	if(kAudioHardwareNoError != status) {
#if DEBUG
		NSLog(@"Unable to get output devices");
#endif
		return;
	}
	   
	unsigned deviceCount = specifierSize / sizeof(AudioDeviceID);
	
	AudioDeviceID *audioDevices = calloc(1, specifierSize);
	if(NULL == audioDevices) {
#if DEBUG
		NSLog(@"Unable to allocate memory");
#endif
		return;
	}
	
	status = AudioHardwareGetProperty(kAudioHardwarePropertyDevices, &specifierSize, audioDevices);
   if(kAudioHardwareNoError != status) {
#if DEBUG
	   NSLog(@"Unable to get output devices");
#endif
	   free(audioDevices);
	   return;
   }

	unsigned i;
	for(i = 0; i < deviceCount; ++i) {

		// Query device UID
		NSString *deviceUID = nil;
		specifierSize = sizeof(deviceUID);
		status = AudioDeviceGetProperty(audioDevices[i], 0, NO, kAudioDevicePropertyDeviceUID, &specifierSize, &deviceUID);
		if(kAudioHardwareNoError != status) {
#if DEBUG
			NSLog(@"Unable to get output device UID");
#endif
			continue;
		}
		
		// Query device name
		NSString *deviceName = nil;
		specifierSize = sizeof(deviceName);
		status = AudioDeviceGetProperty(audioDevices[i], 0, NO, kAudioDevicePropertyDeviceNameCFString, &specifierSize, &deviceName);
		if(kAudioHardwareNoError != status) {
#if DEBUG
			NSLog(@"Unable to get output device name");
#endif
			continue;
		}
		
		// Determine if device is an output device (it is an output device if it has output channels)
		specifierSize = 0;
		status = AudioDeviceGetPropertyInfo(audioDevices[i], 0, NO, kAudioDevicePropertyStreamConfiguration, &specifierSize, NULL);
		if(kAudioHardwareNoError != status) {
#if DEBUG
			NSLog(@"Unable to get output device stream configuration");
#endif
			continue;
		}

		AudioBufferList *bufferList = calloc(1, specifierSize);
		if(NULL == bufferList) {
			break;
		}
		
		status = AudioDeviceGetProperty(audioDevices[i], 0, NO, kAudioDevicePropertyStreamConfiguration, &specifierSize, bufferList);
		if(kAudioHardwareNoError != status || 0 == bufferList->mNumberBuffers) {
			free(bufferList);
			continue;			
		}
				
		free(bufferList);

		NSDictionary *deviceInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			deviceName, @"name",
			deviceUID, @"UID",
			nil];
		
		[self willChangeValueForKey:@"outputDevices"];
		[_outputDevices addObject:deviceInfo];
		[self didChangeValueForKey:@"outputDevices"];
	}

	free(audioDevices);
	
	NSString *outputDevice = [[NSUserDefaults standardUserDefaults] objectForKey:@"outputAudioDeviceUID"];
	unsigned index = [[_outputDevices valueForKey:@"UID"] indexOfObject:outputDevice];
	if(NSNotFound != index) {
		[_devicePopUpButton selectItemAtIndex:index];
	}
}

- (IBAction) outputDeviceChanged:(id)sender
{
	unsigned index = [_devicePopUpButton indexOfSelectedItem];	
	[[NSUserDefaults standardUserDefaults] setObject:[[_outputDevices objectAtIndex:index] valueForKey:@"UID"] forKey:@"outputAudioDeviceUID"];
}

@end
