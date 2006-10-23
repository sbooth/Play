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

#import "PlayApplicationDelegate.h"

@implementation PlayApplicationDelegate

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Automatically re-open the last document opened
	NSDocumentController		*documentController;
	NSArray						*recentDocumentURLs;
	
	documentController			= [NSDocumentController sharedDocumentController];
	recentDocumentURLs			= [documentController recentDocumentURLs];
	
	if(0 == [recentDocumentURLs count]) {
		[documentController newDocument:self];
	}
	else {
		NSURL					*documentURL;
		NSDocument				*document;
		NSError					*error;
		
		error					= nil;
		documentURL				= [recentDocumentURLs objectAtIndex:0];
		document				= [documentController openDocumentWithContentsOfURL:documentURL display:YES error:&error];
		
		if(nil == document) {
			BOOL				errorRecoveryDone;
			
			errorRecoveryDone	= [documentController presentError:error];
		}
	}
}

- (BOOL) applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	// Don't automatically create an untitled document
	return NO;
}

- (void) awakeFromNib
{
	[GrowlApplicationBridge setGrowlDelegate:self];
}

- (NSDictionary *) registrationDictionaryForGrowl
{
	NSDictionary				*registrationDictionary;
	NSArray						*defaultNotifications;
	NSArray						*allNotifications;
	
	defaultNotifications		= [NSArray arrayWithObjects:@"Stream Playback Started", nil];
	allNotifications			= [NSArray arrayWithObjects:@"Stream Playback Started", nil];
	registrationDictionary		= [NSDictionary dictionaryWithObjectsAndKeys:
		@"Play", GROWL_APP_NAME,  
		allNotifications, GROWL_NOTIFICATIONS_ALL, 
		defaultNotifications, GROWL_NOTIFICATIONS_DEFAULT,
		nil];
	
	return registrationDictionary;
}

@end
