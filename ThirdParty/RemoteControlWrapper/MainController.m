//
//  MainController.m
//  RemoteControlWrapper
//
//  Created by Martin Kahr on 16.03.06.
//  Copyright 2006 martinkahr.com. All rights reserved.
//

#import "MainController.h"
#import "AppleRemote.h"
#import "KeyspanFrontRowControl.h"
#import "GlobalKeyboardDevice.h"
#import "IRKeyboardEmuRemote.h"
#import "RemoteControlContainer.h"
#import "MultiClickRemoteBehavior.h"

// -------------------------------------------------------------------------------------------
// Below you'll see different usages of the remote control wrapper. Uncomment the macro 
// definition of the one you want to try out and learn from.
// -------------------------------------------------------------------------------------------

//#define SAMPLE1
//#define SAMPLE2
#define SAMPLE3


// -------------------------------------------------------------------------------------------
// Sample Code 1: Get events from the Apple Remote Control
// -------------------------------------------------------------------------------------------
#ifdef SAMPLE1
@implementation MainController(SampleCode1) 

- (void) awakeFromNib {
	remoteControl = [[[AppleRemote alloc] initWithDelegate: self] retain];
	[remoteControl startListening: self];
}

- (void) sendRemoteButtonEvent: (RemoteControlEventIdentifier) event pressedDown: (BOOL) pressedDown remoteControl: (RemoteControl*) remoteControl {
	NSLog(@"Button %d pressed down %d", event, pressedDown);
}

@end
#endif




// -------------------------------------------------------------------------------------------
// Sample Code 2: Using the Remote Control Container
// 
// To test press COMMAND-SHIFT-CONTROL-F1 to F7 which is the Global Keyboard virtual remote
// -------------------------------------------------------------------------------------------
#ifdef SAMPLE2
@implementation MainController(SampleCode3) 

- (void) awakeFromNib {
	
	
	//  A Remote Control Container manages a number of devices and conforms to the RemoteControl interface
	//  Therefore you can enable or disable all the devices of the container with a single "startListening:" call.
	RemoteControlContainer* container = [[RemoteControlContainer alloc] initWithDelegate: self];
	[container instantiateAndAddRemoteControlDeviceWithClass: [AppleRemote class]];	
	[container instantiateAndAddRemoteControlDeviceWithClass: [KeyspanFrontRowControl class]];
	[container instantiateAndAddRemoteControlDeviceWithClass: [GlobalKeyboardDevice class]];	
	
	[container startListening: self];
	
	remoteControl = container;
}

- (void) sendRemoteButtonEvent: (RemoteControlEventIdentifier) event pressedDown: (BOOL) pressedDown remoteControl: (RemoteControl*) remoteControl {
	NSLog(@"Button %d pressed down %d", event, pressedDown);
}
@end
#endif




// -------------------------------------------------------------------------------------------
// Sample Code 3: Multi Click Behavior and Hold Event Simulation
// -------------------------------------------------------------------------------------------
#ifdef SAMPLE3
@implementation MainController(SampleCode3) 

- (void) awakeFromNib {
	// 1. instantiate the desired behavior for the remote control device
	remoteControlBehavior = [[MultiClickRemoteBehavior alloc] init];	
	
	// 2. configure the behavior
	[remoteControlBehavior setDelegate: self];
		
	// 3. a Remote Control Container manages a number of devices and conforms to the RemoteControl interface
	//    Therefore you can enable or disable all the devices of the container with a single "startListening:" call.
	RemoteControlContainer* container = [[RemoteControlContainer alloc] initWithDelegate: remoteControlBehavior];
	[container instantiateAndAddRemoteControlDeviceWithClass: [AppleRemote class]];	
	[container instantiateAndAddRemoteControlDeviceWithClass: [KeyspanFrontRowControl class]];
	[container instantiateAndAddRemoteControlDeviceWithClass: [GlobalKeyboardDevice class]];	
	[container instantiateAndAddRemoteControlDeviceWithClass: [IRKeyboardEmuRemote class]];

	// to give the binding mechanism a chance to see the change of the attribute
	[self setValue: container forKey: @"remoteControl"];	
}

// delegate method for the MultiClickRemoteBehavior
- (void) remoteButton: (RemoteControlEventIdentifier)buttonIdentifier pressedDown: (BOOL) pressedDown clickCount: (unsigned int)clickCount
{
	NSString* buttonName=nil;
	NSString* pressed=@"";
	
	if (pressedDown) pressed = @"(pressed)"; else pressed = @"(released)";
	
	switch(buttonIdentifier) {
		case kRemoteButtonPlus:
			buttonName = @"Volume up";			
			break;
		case kRemoteButtonMinus:
			buttonName = @"Volume down";
			break;			
		case kRemoteButtonMenu:
			buttonName = @"Menu";
			break;			
		case kRemoteButtonPlay:
			buttonName = @"Play";
			break;			
		case kRemoteButtonRight:	
			buttonName = @"Right";
			break;			
		case kRemoteButtonLeft:
			buttonName = @"Left";
			break;			
		case kRemoteButtonRight_Hold:
			buttonName = @"Right holding";	
			break;	
		case kRemoteButtonLeft_Hold:
			buttonName = @"Left holding";		
			break;			
		case kRemoteButtonPlus_Hold:
			buttonName = @"Volume up holding";	
			break;				
		case kRemoteButtonMinus_Hold:			
			buttonName = @"Volume down holding";	
			break;				
		case kRemoteButtonPlay_Hold:
			buttonName = @"Play (sleep mode)";
			break;			
		case kRemoteButtonMenu_Hold:
			buttonName = @"Menu (long)";
			break;
		case kRemoteControl_Switched:
			buttonName = @"Remote Control Switched";
			break;
		default:
			NSLog(@"Unmapped event for button %d", buttonIdentifier); 
			break;
	}
	//NSLog(@"Button %@ pressed %@", buttonName, pressed);
	NSString* clickCountString = @"";
	if (clickCount > 1) clickCountString = [NSString stringWithFormat: @"%d clicks", clickCount];
	NSString* feedbackString = [NSString stringWithFormat:@"%@ %@ %@", buttonName, pressed, clickCountString];
	[feedbackText setStringValue:feedbackString];
	
	// delegate to view
	[feedbackView remoteButton:buttonIdentifier pressedDown:pressedDown clickCount: clickCount];
	
	// print out events
	NSLog(@"%@", feedbackString);
	if (pressedDown == NO) printf("\n");
	
	// simulate slow processing of events
	// [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.5]];
}
@end
#endif

@implementation MainController

- (void) dealloc {
	[remoteControl autorelease];
	[remoteControlBehavior autorelease];
	[super dealloc];
}

// for bindings access
- (RemoteControl*) remoteControl {
	return remoteControl;
}

- (MultiClickRemoteBehavior*) remoteBehavior {
	return remoteControlBehavior;
}

#ifndef SAMPLE3
#pragma mark -
#pragma mark NSApplication Delegates
- (void)applicationWillBecomeActive:(NSNotification *)aNotification {
	NSLog(@"Application will become active - Using remote controls");
	[remoteControl startListening: self];
}
- (void)applicationWillResignActive:(NSNotification *)aNotification {
	NSLog(@"Application will resign active - Releasing remote controls");
	[remoteControl stopListening: self];
}
#endif

@end