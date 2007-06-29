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

#import "AudioStreamInformationSheet.h"

@implementation AudioStreamInformationSheet

- (id) init
{
	if((self = [super init])) {
		BOOL result = [NSBundle loadNibNamed:@"AudioStreamInformationSheet" owner:self];
		if(NO == result) {
			NSLog(@"Missing resource: \"AudioStreamInformationSheet.nib\".");
			[self release];
			return nil;
		}
	}
	return self;
}

- (void) awakeFromNib
{
	// Set formatters
	
	// Generic numbers
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	
	[_channelsTextField setFormatter:numberFormatter];
	[_playCountTextField setFormatter:numberFormatter];
	[_skipCountTextField setFormatter:numberFormatter];
	[numberFormatter release];

	// Sample Rate
	NSNumberFormatter *sampleRateFormatter = [[NSNumberFormatter alloc] init];
	[sampleRateFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	[sampleRateFormatter setPositiveSuffix:NSLocalizedStringFromTable(@" Hz", @"Formats", @"")];
	
	[_sampleRateTextField setFormatter:sampleRateFormatter];
	[sampleRateFormatter release];

	// Sample Size
	NSNumberFormatter *sampleSizeFormatter = [[NSNumberFormatter alloc] init];
	[sampleSizeFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	[sampleSizeFormatter setPositiveSuffix:NSLocalizedStringFromTable(@" bits", @"Formats", @"")];
	
	[_sampleSizeTextField setFormatter:sampleSizeFormatter];
	[sampleSizeFormatter release];
	
	// Bitrate
	NSNumberFormatter *bitrateFormatter = [[NSNumberFormatter alloc] init];
	[bitrateFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	[bitrateFormatter setRoundingMode:NSNumberFormatterRoundHalfEven];
	[bitrateFormatter setRoundingIncrement:[NSNumber numberWithInt:100]];
//	[bitrateFormatter setMultiplier:[NSNumber numberWithFloat:0.001]];
	[bitrateFormatter setPositiveSuffix:NSLocalizedStringFromTable(@" bps", @"Formats", @"")];

	[_bitrateTextField setFormatter:bitrateFormatter];
	[bitrateFormatter release];

	// Dates
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateStyle:NSDateFormatterFullStyle];
	[dateFormatter setTimeStyle:NSDateFormatterFullStyle];
	
	[_dateAddedTextField setFormatter:dateFormatter];
	[_firstPlayedTextField setFormatter:dateFormatter];
	[_lastPlayedTextField setFormatter:dateFormatter];
	[_lastSkippedTextField setFormatter:dateFormatter];	
	[dateFormatter release];

	// Decibel values
	NSNumberFormatter *decibelFormatter = [[NSNumberFormatter alloc] init];
	[decibelFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	[decibelFormatter setMinimumFractionDigits:2];
	[decibelFormatter setPositiveSuffix:NSLocalizedStringFromTable(@" dB", @"Formats", @"")];
	[decibelFormatter setNegativeSuffix:NSLocalizedStringFromTable(@" dB", @"Formats", @"")];
	
	[_referenceLoudnessTextField setFormatter:decibelFormatter];
	[_trackGainTextField setFormatter:decibelFormatter];
	[_albumGainTextField setFormatter:decibelFormatter];
	[decibelFormatter release];
	
	// Peaks
	NSNumberFormatter *peakFormatter = [[NSNumberFormatter alloc] init];
	[peakFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	[peakFormatter setMinimumFractionDigits:8];
	
	[_trackPeakTextField setFormatter:peakFormatter];
	[_albumPeakTextField setFormatter:peakFormatter];
	[peakFormatter release];	
}

- (NSWindow *) sheet
{
	return [[_sheet retain] autorelease];
}

- (IBAction) ok:(id)sender
{
    [[NSApplication sharedApplication] endSheet:[self sheet] returnCode:NSOKButton];
}

- (IBAction) cancel:(id)sender
{
    [[NSApplication sharedApplication] endSheet:[self sheet] returnCode:NSCancelButton];
}

/*- (IBAction) chooseAlbumArt:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:NO];
	[panel setCanChooseDirectories:NO];
	[panel setCanChooseFiles:YES];
	
	if(NSOKButton == [panel runModalForTypes:[NSImage imageFileTypes]]) {
		NSArray		*filenames		= [panel filenames];
		unsigned	count			= [filenames count];
		unsigned	i;
		NSImage		*image			= nil;
		
		for(i = 0; i < count; ++i) {
			image	= [[NSImage alloc] initWithContentsOfFile:[filenames objectAtIndex:i]];
			if(nil != image) {
//				[_stream setValue:[image TIFFRepresentation] forKeyPath:@"albumArt"];
				[image release];
			}
		}
	}		
}*/

@end
