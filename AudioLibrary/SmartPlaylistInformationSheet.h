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

@class SmartPlaylist;
@class AudioLibrary;
@class SmartPlaylistCriterion;

@interface SmartPlaylistInformationSheet : NSObject
{
	IBOutlet NSWindow			*_sheet;
	IBOutlet NSView				*_criteriaView;
	IBOutlet NSButton			*_removeCriterionButton;
	IBOutlet NSPopUpButton		*_predicateTypePopUpButton;

	IBOutlet NSTextField		*_dateCreatedTextField;
	IBOutlet NSTextField		*_firstPlayedTextField;
	IBOutlet NSTextField		*_lastPlayedTextField;
	IBOutlet NSTextField		*_playCountTextField;
	
@private
	SmartPlaylist				*_playlist;

	NSMutableArray				*_criteria;
	NSCompoundPredicateType		_predicateType;
}

- (NSWindow *)			sheet;

- (IBAction)			ok:(id)sender;
- (IBAction)			cancel:(id)sender;

- (SmartPlaylist *)		smartPlaylist;
- (void)				setSmartPlaylist:(SmartPlaylist *)playlist;

- (IBAction)			add:(id)sender;
- (IBAction)			remove:(id)sender;

- (void)				addCriterion:(SmartPlaylistCriterion *)criterion;
- (void)				removeCriterion:(SmartPlaylistCriterion *)criterion;

- (NSCompoundPredicateType)		predicateType;
- (void)						setPredicateType:(NSCompoundPredicateType)predicateType;

@end
