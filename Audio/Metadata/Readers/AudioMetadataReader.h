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

// ========================================
// Error Codes
// ========================================
extern NSString * const		AudioMetadataReaderErrorDomain;

enum {
	AudioMetadataReaderFileFormatNotRecognizedError		= 0,
	AudioMetadataReaderFileFormatNotSupportedError		= 1
};

@interface AudioMetadataReader : NSObject
{
	NSURL							*_url;
	NSDictionary					*_metadata;
}

+ (AudioMetadataReader *)			metadataReaderForURL:(NSURL *)url error:(NSError **)error;

- (BOOL)							readMetadata:(NSError **)error;

- (NSDictionary *)					metadata;

@end
