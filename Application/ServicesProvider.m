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
	AudioLibrary	*library	= [AudioLibrary defaultLibrary];
	NSArray			*types			= [pboard types];
	NSEnumerator	*enumerator;
	NSString		*current;
	
	if([types containsObject:NSFilenamesPboardType]) {
		enumerator = [[pboard propertyListForType:NSFilenamesPboardType] objectEnumerator];
		while((current = [enumerator nextObject])) {
			if(NO == [library addFile:current]) {
				*error = [NSString stringWithFormat:NSLocalizedStringFromTable(@"The document \"%@\" does not appear to be a valid FLAC or Ogg Vorbis file.", @"Errors", @""), [current lastPathComponent]];
				return;
			}
		}
		
		[library playSelection:self];
	}
	else if([types containsObject:NSStringPboardType]) {
		if(NO == [library addFile:[pboard stringForType:NSStringPboardType]]) {
			*error = [NSString stringWithFormat:NSLocalizedStringFromTable(@"The document \"%@\" does not appear to be a valid FLAC or Ogg Vorbis file.", @"Errors", @""), [[pboard stringForType:NSStringPboardType] lastPathComponent]];
			return;
		}
	}	
}

@end
