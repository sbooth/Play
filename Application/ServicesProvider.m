/*
 *  $Id$
 *
 *  Copyright (C) 2005, 2006 Stephen F. Booth <me@sbooth.org>
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

#import "ServicesProvider.h"
#import "AudioLibrary.h"

@implementation ServicesProvider

- (void) playFile:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
	NSArray		*types			= [pboard types];
	NSArray 	*filenames 		= nil;
	
	if([types containsObject:NSFilenamesPboardType]) {
		filenames = [pboard propertyListForType:NSFilenamesPboardType];
	}
	else if([types containsObject:NSStringPboardType]) {
		filenames = [NSArray arrayWithObject:[pboard stringForType:NSStringPboardType]];
	}
	
	BOOL successfullyAdded = [[AudioLibrary defaultLibrary] addFiles:filenames];

	if(successfullyAdded) {
		BOOL			successfullyPlayed	= NO;
		NSEnumerator	*enumerator			= [filenames objectEnumerator];
		NSString		*filename			= nil;

		while(NO == successfullyPlayed && (filename = [enumerator nextObject])) {
			successfullyPlayed = [[AudioLibrary defaultLibrary] playFile:filename];
		}

		if(successfullyPlayed) {
			[[AudioLibrary defaultLibrary] scrollNowPlayingToVisible:self];
		}
	}
	else {
		*error = NSLocalizedStringFromTable(@"The document was not in a format that Play understands.", @"Errors", @"");
	}
}

@end
