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

#import "PlayApplication.h"

@class AudioStreamInformationSheet;
@class AudioMetadataEditingSheet;
@class StaticPlaylistInformationSheet;
@class DynamicPlaylistInformationSheet;
@class FolderPlaylistInformationSheet;

@implementation PlayApplication

- (id) targetForAction:(SEL)anAction to:(id)aTarget from:(id)sender
{
	id					keyWindowDelegate;

	if((anAction != @selector(undo:)) && (anAction != @selector(redo:))) {
		return [super targetForAction:anAction to:aTarget from:sender];
	}	
	
	keyWindowDelegate	= [[self keyWindow] delegate];
	if([keyWindowDelegate isKindOfClass:[AudioStreamInformationSheet class]] 
	   || [keyWindowDelegate isKindOfClass:[AudioMetadataEditingSheet class]]
	   || [keyWindowDelegate isKindOfClass:[StaticPlaylistInformationSheet class]]
	   || [keyWindowDelegate isKindOfClass:[DynamicPlaylistInformationSheet class]]
	   || [keyWindowDelegate isKindOfClass:[FolderPlaylistInformationSheet class]]) {
		return keyWindowDelegate;
	}
	
	return [super targetForAction:anAction to:aTarget from:sender];
}


- (BOOL) sendAction:(SEL)anAction to:(id)theTarget from:(id)sender
{
	id					keyWindowDelegate;

	if((anAction != @selector(undo:)) && (anAction != @selector(redo:))) {
		return [super sendAction:anAction to:theTarget from:sender];
	}
	
	keyWindowDelegate	= [[self keyWindow] delegate];
	if([keyWindowDelegate isKindOfClass:[AudioStreamInformationSheet class]] 
	   || [keyWindowDelegate isKindOfClass:[AudioMetadataEditingSheet class]]
	   || [keyWindowDelegate isKindOfClass:[StaticPlaylistInformationSheet class]]
	   || [keyWindowDelegate isKindOfClass:[DynamicPlaylistInformationSheet class]]
	   || [keyWindowDelegate isKindOfClass:[FolderPlaylistInformationSheet class]]) {
		return [super sendAction:anAction to:keyWindowDelegate from:sender];
	}
	
	return [super sendAction:anAction to:theTarget from:sender];
}

@end
