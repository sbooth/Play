/*
 *  $Id: AudioScrobbler.m 238 2007-01-26 22:55:20Z stephen_booth $
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

#import "AudioScrobbler.h"

#import "AudioScrobblerClient.h"
#import "AudioStream.h"
#import "AudioMetadata.h"

static NSString * 
escapeForLastFM(NSString *string)
{
	NSMutableString *result = [string mutableCopy];
	
	[result replaceOccurrencesOfString:@"&" 
							withString:@"&&" 
							   options:NSLiteralSearch 
								 range:NSMakeRange(0, [result length])];
	
	return (nil == result ? @"" : [result autorelease]);
}

@interface AudioScrobbler (Private)

- (NSMutableArray *)	queue;

- (void)				sendCommand:(NSString *)command;

- (BOOL)				keepProcessingAudioScrobblerCommands;
- (void)				setKeepProcessingAudioScrobblerCommands:(BOOL)keepProcessingAudioScrobblerCommands;

- (BOOL)				audioScrobblerThreadCompleted;
- (void)				setAudioScrobblerThreadCompleted:(BOOL)audioScrobblerThreadCompleted;

- (semaphore_t)			semaphore;

- (void)				processAudioScrobblerCommands:(AudioScrobbler *)myself;

@end

@implementation AudioScrobbler

- (id) init
{
	if((self = [super init])) {

		kern_return_t	result;

//		_pluginID		= @"pla";
		_pluginID		= @"tst";

//		_clientAvailable	= (nil != [[NSWorkspace sharedWorkspace] fullPathForApplication:@"Last.fm.app"]);
//		if(_clientAvailable && [[NSUserDefaults standardUserDefaults] boolForKey:@"automaticallyLaunchLastFM"]) {
//			[[NSWorkspace sharedWorkspace] launchApplication:@"Last.fm.app"];
//		}
		
		_keepProcessingAudioScrobblerCommands	= YES;

		result			= semaphore_create(mach_task_self(), &_semaphore, SYNC_POLICY_FIFO, 0);
		
		if(KERN_SUCCESS != result) {
			NSLog(@"Couldn't create semaphore (%s).", mach_error_type(result));

			[self release];
			return nil;
		}
		
		[NSThread detachNewThreadSelector:@selector(processAudioScrobblerCommands:) toTarget:self withObject:self];

		return self;
	}
	return nil;
}

- (void) dealloc
{
	if([self keepProcessingAudioScrobblerCommands] || NO == [self audioScrobblerThreadCompleted]) {
		[self shutdown];
	}
	
	[_queue release],		_queue = nil;
	
	semaphore_destroy(mach_task_self(), _semaphore),	_semaphore = 0;

	[super dealloc];
}

- (void) start:(AudioStream *)streamObject
{
	[self sendCommand:[NSString stringWithFormat:@"START c=%@&a=%@&t=%@&b=%@&m=%@&l=%i&p=%@\n", 
		_pluginID,
		escapeForLastFM([[streamObject metadata] artist]), 
		escapeForLastFM([[streamObject metadata] title]), 
		escapeForLastFM([[streamObject metadata] albumTitle]), 
		@"", 
		[[[streamObject properties] valueForKey:@"duration"] intValue], 
		escapeForLastFM([[NSURL URLWithString:[streamObject url]] path])
		]];	
}

- (void) stop
{
	[self sendCommand:[NSString stringWithFormat:@"STOP c=%@\n", _pluginID]];
}

- (void) pause
{
	[self sendCommand:[NSString stringWithFormat:@"PAUSE c=%@\n", _pluginID]];
}

- (void) resume
{
	[self sendCommand:[NSString stringWithFormat:@"RESUME c=%@\n", _pluginID]];
}

- (void) shutdown
{
	[self stop];
	[self setKeepProcessingAudioScrobblerCommands:NO];
	
	while(NO == [self audioScrobblerThreadCompleted]) {		
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
	}
}

@end

@implementation AudioScrobbler (Private)

- (NSMutableArray *) queue
{
	if(nil == _queue) {
		_queue = [[NSMutableArray alloc] init];
	}
	
	return _queue;
}

- (void) sendCommand:(NSString *)command
{
	@synchronized([self queue]) {
		[[self queue] addObject:command];
	}
	semaphore_signal([self semaphore]);
}

- (BOOL) keepProcessingAudioScrobblerCommands
{
	return _keepProcessingAudioScrobblerCommands;
}

- (void) setKeepProcessingAudioScrobblerCommands:(BOOL)keepProcessingAudioScrobblerCommands
{
	_keepProcessingAudioScrobblerCommands = keepProcessingAudioScrobblerCommands;
}

- (BOOL) audioScrobblerThreadCompleted
{
	return _audioScrobblerThreadCompleted;
}

- (void) setAudioScrobblerThreadCompleted:(BOOL)audioScrobblerThreadCompleted
{
	_audioScrobblerThreadCompleted = audioScrobblerThreadCompleted;
}

- (semaphore_t) semaphore
{
	return _semaphore;
}

- (void) processAudioScrobblerCommands:(AudioScrobbler *)myself
{
	NSAutoreleasePool		*pool				= [[NSAutoreleasePool alloc] init];
	AudioScrobblerClient			*client				= [[AudioScrobblerClient alloc] init];
	mach_timespec_t			timeout				= { 5, 0 };
	NSEnumerator			*enumerator			= nil;
	NSString				*command			= nil;
	NSString				*response			= nil;
	in_port_t				port				= 33367;
	
	while([myself keepProcessingAudioScrobblerCommands]) {

		// Get the first command to be sent
		@synchronized([myself queue]) {
			
			enumerator		= [[myself queue] objectEnumerator];
			command			= [enumerator nextObject];
		
			[[myself queue] removeObjectIdenticalTo:command];
		}

		if(nil != command) {
			@try {
				port		= [client connectToHost:@"localhost" port:port];
				
				[client send:command];
				
				response	= [client receive];
				
				[client shutdown];
			}
			
			@catch(NSException *exception) {
				NSLog(@"Exception: %@",exception);
				continue;
			}
		}
				
		semaphore_timedwait([myself semaphore], timeout);
	}
	
	[myself setAudioScrobblerThreadCompleted:YES];

	[client release];
	[pool release];
}

@end
