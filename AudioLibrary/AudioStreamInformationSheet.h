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

@interface AudioStreamInformationSheet : NSObject
{
	IBOutlet NSWindow		*_sheet;
	IBOutlet NSArrayController	*_streamController;
	
	IBOutlet NSTextField	*_channelsTextField;
	IBOutlet NSTextField	*_sampleRateTextField;
	IBOutlet NSTextField	*_sampleSizeTextField;
	IBOutlet NSTextField	*_bitrateTextField;

	IBOutlet NSTextField	*_dateAddedTextField;
	IBOutlet NSTextField	*_firstPlayedTextField;
	IBOutlet NSTextField	*_lastPlayedTextField;
	IBOutlet NSTextField	*_playCountTextField;
	IBOutlet NSTextField	*_lastSkippedTextField;
	IBOutlet NSTextField	*_skipCountTextField;

	IBOutlet NSTextField	*_referenceLoudnessTextField;
	IBOutlet NSTextField	*_trackGainTextField;
	IBOutlet NSTextField	*_trackPeakTextField;
	IBOutlet NSTextField	*_albumGainTextField;
	IBOutlet NSTextField	*_albumPeakTextField;
}

- (NSWindow *)			sheet;

- (IBAction)			ok:(id)sender;
- (IBAction)			cancel:(id)sender;

@end
