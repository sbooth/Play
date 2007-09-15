/*
 *  $Id$
 *
 *  Copyright (C) 2007 Stephen F. Booth <me@sbooth.org>
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

#import "MusicBrainzMatchesSheet.h"

#import "MusicBrainzUtilities.h"

@implementation MusicBrainzMatchesSheet

- (id) init
{
	if((self = [super init])) {
		BOOL result = [NSBundle loadNibNamed:@"MusicBrainzMatchesSheet" owner:self];
		if(NO == result) {
			NSLog(@"Missing resource: \"MusicBrainzMatchesSheet.nib\".");
			[self release];
			return nil;
		}		
	}
	return self;
}

- (void) dealloc
{
	[_PUID release], _PUID = nil;
	
	[super dealloc];
}

- (NSWindow *) sheet
{
	return [[_sheet retain] autorelease];
}

- (NSString *) PUID
{
	return [[_PUID retain] autorelease];
}

- (void) setPUID:(NSString *)PUID
{
	[_PUID release];
	_PUID = [PUID retain];
}

- (IBAction) ok:(id)sender
{
    [[NSApplication sharedApplication] endSheet:[self sheet] returnCode:NSOKButton];
}

- (IBAction) cancel:(id)sender
{
    [[NSApplication sharedApplication] endSheet:[self sheet] returnCode:NSCancelButton];
}

- (IBAction) search:(id)sender
{
	NSError *error = nil;
	
	[self startProgressIndicator:sender];
	NSArray *matches = getMusicBrainzTracksMatchingPUID([self PUID], &error);
	[self stopProgressIndicator:sender];
	
	if(nil == matches) {
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert runModal];
		
		return;
	}
	else if(0 == [matches count])
		[self ok:sender];
	else
		[self setMatches:matches];
}

- (IBAction) startProgressIndicator:(id)sender
{
	[_progressIndicator setHidden:NO];
	[_progressIndicator startAnimation:sender];
}

- (IBAction) stopProgressIndicator:(id)sender
{
	[_progressIndicator stopAnimation:sender];
	[_progressIndicator setHidden:YES];
}

- (void) setMatches:(NSArray *)matches
{
	[_matchesController setContent:matches];
}

- (NSDictionary *) selectedMatch
{
	return [[_matchesController selectedObjects] lastObject];
}

@end
