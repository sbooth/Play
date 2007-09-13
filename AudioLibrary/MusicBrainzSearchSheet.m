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

#import "MusicBrainzSearchSheet.h"

#import "MusicBrainzUtilities.h"

@implementation MusicBrainzSearchSheet

- (id) init
{
	if((self = [super init])) {
		BOOL result = [NSBundle loadNibNamed:@"MusicBrainzSearchSheet" owner:self];
		if(NO == result) {
			NSLog(@"Missing resource: \"MusicBrainzSearchSheet.nib\".");
			[self release];
			return nil;
		}		
	}
	return self;
}

- (void) dealloc
{
	[_title release], _title = nil;
	[_artist release], _artist = nil;
	[_albumTitle release], _albumTitle = nil;
	[_duration release], _duration = nil;

	[super dealloc];
}

- (NSWindow *) sheet
{
	return [[_sheet retain] autorelease];
}

- (NSString *) title
{
	return [[_title retain] autorelease];
}

- (void) setTitle:(NSString *)title
{
	[_title release];
	_title = [title retain];
}

- (NSString *) artist
{
	return [[_artist retain] autorelease];
}

- (void) setArtist:(NSString *)artist
{
	[_artist release];
	_artist = [artist retain];
}

- (NSString *) albumTitle
{
	return [[_albumTitle retain] autorelease];
}

- (void) setAlbumTitle:(NSString *)albumTitle
{
	[_albumTitle release];
	_albumTitle = [albumTitle retain];
}

- (NSNumber *) duration
{
	return [[_duration retain] autorelease];
}

- (void) setDuration:(NSNumber *)duration
{
	[_duration release];
	_duration = [duration retain];
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
	NSArray *matches = getMusicBrainzTracksMatching([self title], [self artist], [self albumTitle], [self duration], &error);
	[self stopProgressIndicator:sender];
	
	if(nil == matches) {
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert runModal];
		
		return;
	}
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
