/*
 *  $Id$
 *
 *  Copyright (C) 2006 Stephen F. Booth <me@sbooth.org>
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

#import "UtilityFunctions.h"

#include <AudioToolbox/AudioFile.h>
#include <ogg/ogg.h>

static NSArray *sCoreAudioExtensions	= nil;

OggStreamType 
oggStreamType(NSURL *url)
{
	NSCParameterAssert([url isFileURL]);
	
	OggStreamType			streamType				= kOggStreamTypeInvalid;
	
	int						fd						= -1;
	int						result;
	ssize_t					bytesRead;
	
	ogg_sync_state			oy;
	ogg_page				og;
	ogg_packet				op;
	ogg_stream_state		os;
	
	char					*data					= NULL;
	
	// Open the input file
	fd			= open([[url path] fileSystemRepresentation], O_RDONLY);
	NSCAssert1(-1 != fd, @"Unable to open the input file (%s).", strerror(errno));
		
	// Initialize Ogg data struct
	ogg_sync_init(&oy);
	
	// Get the ogg buffer for writing
	data		= ogg_sync_buffer(&oy, 4096);
	
	// Read bitstream from input file
	bytesRead	= read(fd, data, 4096);
	NSCAssert1(-1 != bytesRead, @"Unable to read from the input file (%s).", strerror(errno));
	
	// Tell the sync layer how many bytes were written to its internal buffer
	result		= ogg_sync_wrote(&oy, bytesRead);
	NSCAssert(-1 != result, @"Ogg decoding error (ogg_sync_wrote).");
	
	// Turn the data we wrote into an ogg page
	result		= ogg_sync_pageout(&oy, &og);
//	NSCAssert(1 == result, @"The file does not appear to be an Ogg bitstream.");
	
	if(0 == result) {
		// Upgrade the stream type from invalid to unknown
		streamType	= kOggStreamTypeUnknown;
		
		// Initialize the stream and grab the serial number
		ogg_stream_init(&os, ogg_page_serialno(&og));
		
		result		= ogg_stream_pagein(&os, &og);
		NSCAssert(0 == result, @"Error reading first page of Ogg bitstream data.");
		
		result		= ogg_stream_packetout(&os, &op);
		NSCAssert(1 == result, @"Error reading initial Ogg packet header.");
		
		// Check to see if the content is Vorbis
		if(kOggStreamTypeUnknown == streamType) {
			oggpack_buffer		opb;
			char				buffer[6];
			int					packtype;
			unsigned			i;
			
			memset(buffer, 0, 6);
			oggpack_readinit(&opb, op.packet, op.bytes);
			
			packtype		= oggpack_read(&opb, 8);
			for(i = 0; i < 6; ++i) {
				buffer[i] = oggpack_read(&opb, 8);
			}
			
			if(0 == memcmp(buffer, "vorbis", 6)) {
				streamType = kOggStreamTypeVorbis;
			}
		}
		
		// Check to see if the content is Speex
		if(kOggStreamTypeUnknown == streamType) {
			if(0 == memcmp(op.packet, "Speex   ", 8)) {
				streamType = kOggStreamTypeSpeex;
			}
		}
		
		// Check to see if the content is FLAC
		// This code "borrowed" from ogg_decoder_aspect.c in libOggFLAC
		if(kOggStreamTypeUnknown == streamType) {
			uint8_t			*bytes			= (uint8_t *)op.packet;
			unsigned		headerLength	= 
				1 /*OggFLAC__MAPPING_PACKET_TYPE_LENGTH*/ +
				4 /*OggFLAC__MAPPING_MAGIC_LENGTH*/ +
				1 /*OggFLAC__MAPPING_VERSION_MAJOR_LENGTH*/ +
				1 /*OggFLAC__MAPPING_VERSION_MINOR_LENGTH*/ +
				2 /*OggFLAC__MAPPING_NUM_HEADERS_LENGTH*/;
			
			if(op.bytes >= (long)headerLength) {
				bytes += 1 /*OggFLAC__MAPPING_PACKET_TYPE_LENGTH*/;
				if(0 == memcmp(bytes, "FLAC" /*OggFLAC__MAPPING_MAGIC*/, 4 /*OggFLAC__MAPPING_MAGIC_LENGTH*/)) {
					streamType = kOggStreamTypeFLAC;
				}
			}		
		}
	}
	
	// Clean up
	result = close(fd);
	NSCAssert1(-1 != result, @"Unable to close the input file (%s).", strerror(errno));
	
	ogg_stream_clear(&os);
	ogg_sync_clear(&oy);
	
	return streamType;
}

NSArray *
getCoreAudioExtensions()
{
	OSStatus			err;
	UInt32				size;
	
	@synchronized(sCoreAudioExtensions) {
		if(nil == sCoreAudioExtensions) {
			size	= sizeof(sCoreAudioExtensions);
			err		= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AllExtensions, 0, NULL, &size, &sCoreAudioExtensions);
			NSCAssert2(noErr == err, @"The call to %@ failed (%@).", @"AudioFileGetGlobalInfo", UTCreateStringForOSType(err));
			
			[sCoreAudioExtensions retain];
		}
	}
	
	return sCoreAudioExtensions;
}
