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
#import "BrowserNode.h"

@class AudioStream;

// ========================================
// An object that is KVC-compliant for a set of AudioStreams
// Subclasses may access _streams directly, provided they do so
// in a KVC-compliant way
// ========================================
@interface AudioStreamCollectionNode : BrowserNode
{
	@protected
	NSMutableArray	*_streams;
}

// ========================================
// Subclasses must override these methods!
- (void) loadStreams;
- (void) refreshStreams;

- (BOOL) streamsAreOrdered;
- (BOOL) streamReorderingAllowed;

// ========================================
// State management
- (BOOL) canInsertStream;
- (BOOL) canRemoveStream;

// ========================================
// KVC Accessors
- (unsigned)		countOfStreams;
- (AudioStream *)	objectInStreamsAtIndex:(unsigned)index;
- (void)			getStreams:(id *)buffer range:(NSRange)aRange;

// ========================================
// KVC Mutators
- (void) insertObject:(AudioStream *)stream inStreamsAtIndex:(unsigned)index;
- (void) removeObjectFromStreamsAtIndex:(unsigned)index;

@end
