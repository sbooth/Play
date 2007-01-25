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

#import "AudioScrobbler.h"

#import "NetSocket.h"
#import "AudioStream.h"
#import "AudioMetadata.h"


@interface AudioScrobbler (Private)

- (NetSocket *)				socket;
- (NSMutableArray *)		queue;

- (void)					connect;

- (void)					sendCommand:(NSString *)command;

- (void)					processQueuedCommands;

@end

@implementation AudioScrobbler

- (id) init
{
	if((self = [super init])) {

//		_pluginID			= @"pla";
		_pluginID			= @"tst";
		
//		_clientAvailable	= (nil != [[NSWorkspace sharedWorkspace] fullPathForApplication:@"Last.fm.app"]);
//		if(_clientAvailable && [[NSUserDefaults standardUserDefaults] boolForKey:@"automaticallyLaunchLastFM"]) {
//			[[NSWorkspace sharedWorkspace] launchApplication:@"Last.fm.app"];
//		}
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_socket release],		_socket = nil;
	[_queue release],		_queue = nil;
	
	[super dealloc];
}

- (void) audioStreamStart:(AudioStream *)streamObject
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

@end

@implementation AudioScrobbler (NetSocketDelegateMethods)

// Why is this being called even when the port isn't open?!
- (void) netsocketConnected:(NetSocket*)inNetSocket
{
	[self processQueuedCommands];
}

- (void) netsocket:(NetSocket*)inNetSocket connectionTimedOut:(NSTimeInterval)inTimeout
{
	NSLog( @"netsocket:connectionTimedOut:" );
}

- (void) netsocketDisconnected:(NetSocket*)inNetSocket
{
	[[self socket] close];
}

- (void) netsocket:(NetSocket*)inNetSocket dataAvailable:(unsigned)inAmount
{
	NSString	*response	= [[self socket] readString:NSUTF8StringEncoding];
	
	if(NSOrderedSame != [response compare:@"OK" options:NSCaseInsensitiveSearch range:NSMakeRange(0, 2)]) {
		NSLog(@"Last.fm error: %@", response);
	}
}

@end

@implementation AudioScrobbler (Private)

- (NetSocket *) socket
{
	if(nil == _socket) {
		_socket = [[NetSocket alloc] init];
	}
	
	return _socket;
}

- (NSMutableArray *) queue
{
	if(nil == _queue) {
		_queue = [[NSMutableArray alloc] init];
	}
	
	return _queue;
}

- (void) connect
{
	BOOL result;
		
	result		= [[self socket] open];
	if(NO == result) {
		NSLog(@"Unable to open a socket for connecting to Last.fm.");
		[_socket release], _socket = nil;
		return;
	}
		
	result = [[self socket] connectToHost:@"localhost" port:33367 timeout:5.0];
	if(NO == result) {
		NSLog(@"Unable to connect to localhost:33367");
		return;
	}

	[[self socket] setDelegate:self];
	[[self socket] scheduleOnCurrentRunLoop];	
}

- (void) sendCommand:(NSString *)command
{
	[[self queue] addObject:command];	
	[self processQueuedCommands];
}

- (void) processQueuedCommands
{
	NSEnumerator	*enumerator		= nil;
	NSString		*command		= nil;

	if(NO == [[self socket] isConnected]) {
		[self connect];
		return;
	}
	
	enumerator		= [[self queue] objectEnumerator];
	command			= [enumerator nextObject];

	if(nil != command) {
		[[self socket] writeString:command encoding:NSUTF8StringEncoding];		
		[[self queue] removeObjectIdenticalTo:command];
	}	
}

@end
