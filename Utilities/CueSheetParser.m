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

#import "CueSheetParser.h"

#import "AudioStream.h"
#import "AudioPropertiesReader.h"
#import "AudioMetadataReader.h"

BOOL 
scanPossiblyQuotedString(NSScanner		*scanner, 
						 NSString		**string)
{
	NSCParameterAssert(nil != scanner);

	// Consume leading whitespace (manually)
	NSCharacterSet *whitespaceCharacterSet = [NSCharacterSet whitespaceCharacterSet];
	while([[scanner string] length] > [scanner scanLocation] && [whitespaceCharacterSet characterIsMember:[[scanner string] characterAtIndex:[scanner scanLocation]]])
		[scanner setScanLocation:(1 + [scanner scanLocation])];

	if([[scanner string] length] == [scanner scanLocation])
		return NO;
	
	// Handle quoted strings
	BOOL quotedString = (0x0022 == [[scanner string] characterAtIndex:[scanner scanLocation]]);
	
	if(quotedString) {
		[scanner setScanLocation:(1 + [scanner scanLocation])];

		if(NO == [scanner scanUpToString:@"\"" intoString:string])
			return NO;
		
		// Ensure string is terminated
		if([[scanner string] length] > [scanner scanLocation] && 0x0022 == [[scanner string] characterAtIndex:[scanner scanLocation]])
			[scanner setScanLocation:(1 + [scanner scanLocation])];
		else {
			*string = NULL;
			return NO;
		}
	}
	else if(NO == [scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:string])
		return NO;

	return YES;
}

BOOL 
scanMSF(NSScanner		*scanner, 
		int				*minute,
		int				*second,
		int				*frame)
{
	NSCParameterAssert(nil != scanner);
	
	if(NO == [scanner scanInt:minute])
		return NO;
		
	if([[scanner string] length] > [scanner scanLocation] && 0x003A == [[scanner string] characterAtIndex:[scanner scanLocation]])
		[scanner setScanLocation:(1 + [scanner scanLocation])];
	else
		return NO;

	if(NO == [scanner scanInt:second])
		return NO;

	if([[scanner string] length] > [scanner scanLocation] && 0x003A == [[scanner string] characterAtIndex:[scanner scanLocation]])
		[scanner setScanLocation:(1 + [scanner scanLocation])];
	else
		return NO;
	
	if(NO == [scanner scanInt:frame])
		return NO;
	
	return YES;
}

@interface CueSheetParser (Private)

- (BOOL) parse:(NSError **)error;

@end

@implementation CueSheetParser

+ (id) cueSheetWithURL:(NSURL *)URL error:(NSError **)error
{
	CueSheetParser *cueSheetParser = [[CueSheetParser alloc] initWithURL:URL error:error];
	return [cueSheetParser autorelease];
}

- (id) initWithURL:(NSURL *)URL error:(NSError **)error
{
	NSParameterAssert(nil != URL);

	if((self = [super init])) {
		_URL = [URL retain];
		if(NO == [self parse:error]) {
			[self release];
			return nil;
		}
	}
	
	return self;
}

- (void) dealloc
{
	[_URL release], _URL = nil;
	[_cueSheetTracks release], _cueSheetTracks = nil;
	
	[super dealloc];
}

- (NSArray *) cueSheetTracks
{
	return [[_cueSheetTracks retain] autorelease];
}

@end

@implementation CueSheetParser (Private)

// Since cue sheets are simple, just use NSScanner in lieu of a full-blown lemon parser
// This is a bare-bones implementation that ignores many commands we're not interested in
// This is also an extremely lenient parser, ignoring most "rules" from http://digitalx.org/cuesheetsyntax.php
- (BOOL) parse:(NSError **)error
{
	// Attempt to read the cue sheet as a string for parsing
	NSString *fileContents = [NSString stringWithContentsOfURL:_URL encoding:NSUTF8StringEncoding error:error];
	if(nil == fileContents)
		return NO;		
	
	NSMutableDictionary		*cueSheet			= [NSMutableDictionary dictionary];
	NSMutableArray			*cueSheetTracks		= [NSMutableArray array];
	NSMutableDictionary		*currentTrack		= nil;

	// The current file
	NSURL					*fileURL			= nil;
	AudioPropertiesReader	*propertiesReader	= nil;
	AudioMetadataReader		*metadataReader		= nil;
	
	// Create a newline character set
	unichar			rawNewlineCharacters []		= { 0x000D, 0x000A, 0x0085 };
	NSString		*newlineCharacters			= [NSString stringWithCharacters:rawNewlineCharacters length:3];
	NSCharacterSet	*newlineCharacterSet		= [NSCharacterSet characterSetWithCharactersInString:newlineCharacters];
	
	// Parse the cue sheet one line at a time
	NSScanner	*fileScanner	= [NSScanner scannerWithString:fileContents];
	NSString	*line			= nil;

	while(NO == [fileScanner isAtEnd] && [fileScanner scanUpToCharactersFromSet:newlineCharacterSet intoString:&line]) {
		// Parse the line
		NSScanner	*lineScanner	= [NSScanner scannerWithString:line];
		NSString	*command		= nil;
		
		// Grab the cue sheet command
		if(NO == [lineScanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&command])
			continue;
		
		// Handle each cue sheet command
		if([command isEqualToString:@"CATALOG"]) {
			NSString *mcn = nil;
			if([lineScanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&mcn])
				[cueSheet setValue:mcn forKey:MetadataMCNKey];
		}
		else if([command isEqualToString:@"CDTEXTFILE"])
			;
		else if([command isEqualToString:@"FILE"]) {
			NSString *filename = nil;
			
			if(scanPossiblyQuotedString(lineScanner, &filename)) {
				// If the file doesn't exist as an absolute path attempt to resolve it
				if(NO == [[NSFileManager defaultManager] fileExistsAtPath:filename]) {
					NSString	*cueSheetPath	= [[_URL path] stringByDeletingLastPathComponent];
					NSString	*filenamePath	= [cueSheetPath stringByAppendingPathComponent:filename];

					if(NO == [[NSFileManager defaultManager] fileExistsAtPath:filenamePath])
						return NO;
					else
						filename = filenamePath;
				}
				
				fileURL = [NSURL fileURLWithPath:filename];
				
				// Read the properties for the file
				propertiesReader = [AudioPropertiesReader propertiesReaderForURL:fileURL error:error];
				if(nil == propertiesReader)
					return NO;
				
				if(NO == [propertiesReader readProperties:error])
					return NO;
				
				metadataReader = [AudioMetadataReader metadataReaderForURL:fileURL error:error];
				if(nil == metadataReader)
					return NO;
				
				if(NO == [metadataReader readMetadata:error])
					return NO;
			}
			else
				return NO;
			
			// Ignore anything after the filename; we don't care what type it is or the format
		}
		else if([command isEqualToString:@"FLAGS"])
			;
		else if([command isEqualToString:@"INDEX"]) {
			if(nil == currentTrack)
				continue;
			
			int indexNumber = 0;
			if(NO == [lineScanner scanInt:&indexNumber])
				continue;
			
			// Index 0 is pregap (ignored)
			if(1 == indexNumber) {
				int minute = 0, second = 0, frame = 0;
				if(NO == scanMSF(lineScanner, &minute, &second, &frame))
					continue;
				
				unsigned	framesPerSector		= [[[propertiesReader properties] valueForKey:PropertiesSampleRateKey] floatValue] / 75;
				unsigned	startingSector		= (((60 * minute) + second) * 75) + frame;
				long long	startingFrame		= startingSector * framesPerSector;
				long long	totalFrames			= [[[propertiesReader properties] valueForKey:PropertiesTotalFramesKey] longLongValue];
				
				// Sanity check
				if(startingFrame >= totalFrames)
					continue;
				
				[currentTrack setValue:[NSNumber numberWithLongLong:startingFrame] forKey:StreamStartingFrameKey];
			}
		}
		else if([command isEqualToString:@"ISRC"]) {
			if(nil == currentTrack)
				continue;

			NSString *isrc = nil;
			if([lineScanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&isrc])
				[currentTrack setValue:isrc forKey:MetadataISRCKey];
		}
		else if([command isEqualToString:@"PERFORMER"]) {
			NSString *performer = nil;
			if(scanPossiblyQuotedString(lineScanner, &performer)) {
				if(nil == currentTrack)
					[cueSheet setValue:performer forKey:MetadataArtistKey];
				else
					[currentTrack setValue:performer forKey:MetadataArtistKey];
			}
		}
		else if([command isEqualToString:@"POSTGAP"])
			;
		else if([command isEqualToString:@"PREGAP"])
			;
		else if([command isEqualToString:@"REM"])
			;
		else if([command isEqualToString:@"SONGWRITER"]) {
			NSString *songwriter = nil;
			if(scanPossiblyQuotedString(lineScanner, &songwriter)) {
				if(nil == currentTrack)
					[cueSheet setValue:songwriter forKey:MetadataComposerKey];
				else
					[currentTrack setValue:songwriter forKey:MetadataComposerKey];
			}
		}
		else if([command isEqualToString:@"TITLE"]) {
			NSString *title = nil;
			
			if(scanPossiblyQuotedString(lineScanner, &title)) {
				if(nil == currentTrack)
					[cueSheet setValue:title forKey:MetadataAlbumTitleKey];
				else
					[currentTrack setValue:title forKey:MetadataTitleKey];
			}
		}
		else if([command isEqualToString:@"TRACK"]) {
			currentTrack = nil;
			
			if(nil == fileURL)
				continue;
			
			int trackNumber = 0;
			if(NO == [lineScanner scanInt:&trackNumber])
				continue;

			NSString *trackType = nil;			
			if(NO == scanPossiblyQuotedString(lineScanner, &trackType) || NO == [trackType isEqualToString:@"AUDIO"])
				continue;
				
			currentTrack = [NSMutableDictionary dictionaryWithObject:fileURL forKey:StreamURLKey];

			[currentTrack setValue:[NSNumber numberWithInt:trackNumber] forKey:MetadataTrackNumberKey];
			[currentTrack addEntriesFromDictionary:[propertiesReader properties]];
			[currentTrack addEntriesFromDictionary:[metadataReader metadata]];
			
			[cueSheetTracks addObject:currentTrack];
		}
		else
			NSLog(@"Unknown cue sheet command: \"%@\"", command);
		
		// Consume any newlines in preparation for scanning the next line
		[fileScanner scanCharactersFromSet:newlineCharacterSet intoString:NULL];
	}
	
	// Iterate through the tracks and update the frame counts
	unsigned i;
	for(i = 0; i < [cueSheetTracks count]; ++i) {
		NSMutableDictionary *thisTrack = [cueSheetTracks objectAtIndex:i];

		[thisTrack addEntriesFromDictionary:cueSheet];
		
		NSMutableDictionary *previousTrack = nil;
		if(0 != i)
			previousTrack = [cueSheetTracks objectAtIndex:(i - 1)];

		// Fill in frame counts
		if(nil != previousTrack && [[previousTrack valueForKey:StreamURLKey] isEqual:[thisTrack valueForKey:StreamURLKey]]) {
			unsigned frameCount = ([[thisTrack valueForKey:StreamStartingFrameKey] longLongValue] - 1) - [[previousTrack valueForKey:StreamStartingFrameKey] longLongValue];
			
			[previousTrack setValue:[NSNumber numberWithUnsignedInt:frameCount] forKey:StreamFrameCountKey];
		}
		
		// Special handling for last tracks
		if(nil == [thisTrack valueForKey:StreamFrameCountKey]) {
			unsigned frameCount = [[thisTrack valueForKey:PropertiesTotalFramesKey] unsignedIntValue] - [[thisTrack valueForKey:StreamStartingFrameKey] longLongValue] + 1;
			
			[thisTrack setValue:[NSNumber numberWithUnsignedInt:frameCount] forKey:StreamFrameCountKey];
		}
	}
	
	_cueSheetTracks = [cueSheetTracks copy];
	
	return YES;
}

@end
