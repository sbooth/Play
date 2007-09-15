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

#import "MusicBrainzUtilities.h"
#import "AudioStream.h"

#include <musicbrainz3/webservice.h>
#include <musicbrainz3/query.h>
#include <musicbrainz3/model.h>
#include <musicbrainz3/utils.h>

#include <SystemConfiguration/SCNetwork.h>
#include <typeinfo>

BOOL
canConnectToMusicBrainz()
{
	SCNetworkConnectionFlags flags;
	if(SCNetworkCheckReachabilityByName("musicbrainz.org", &flags)) {
		if(kSCNetworkFlagsReachable & flags && !(kSCNetworkFlagsConnectionRequired & flags))
			return YES;
	}
	
	return NO;
}

NSArray *
buildMusicBrainzResultArray(MusicBrainz::Query &q, MusicBrainz::TrackResultList &results, NSError **error)
{
	NSMutableArray *resultArray = [[NSMutableArray alloc] init];
	
	for(MusicBrainz::TrackResultList::iterator i = results.begin(); i != results.end(); ++i) {
		MusicBrainz::TrackResult	*result		= *i;
		MusicBrainz::Track			*track		= NULL;
		
		try {
			MusicBrainz::TrackIncludes includes = MusicBrainz::TrackIncludes().artist().releases().trackRelations();
			track = q.getTrackById(result->getTrack()->getId(), &includes);
			if(NULL == track)
				continue;
		}
		
		catch(/* const MusicBrainz::Exception &e */ const std::exception &e) {
			NSLog(@"MusicBrainz error: %s", e.what());
			continue;
		}
		
		NSMutableDictionary *trackDictionary = [NSMutableDictionary dictionary];
		
//		if(0 != result->getScore())
//			[trackDictionary setValue:[NSNumber numberWithInt:result->getScore()] forKey:@"score"];
		if(!track->getId().empty())
			[trackDictionary setValue:[NSString stringWithCString:track->getId().c_str() encoding:NSUTF8StringEncoding] forKey:MetadataMusicBrainzIDKey];
		if(!track->getTitle().empty())
			[trackDictionary setValue:[NSString stringWithCString:track->getTitle().c_str() encoding:NSUTF8StringEncoding] forKey:MetadataTitleKey];
		if(NULL != track->getArtist())
			[trackDictionary setValue:[NSString stringWithCString:track->getArtist()->getName().c_str() encoding:NSUTF8StringEncoding] forKey:MetadataArtistKey];
		
		MusicBrainz::ReleaseList releases = track->getReleases();
		
		for(MusicBrainz::ReleaseList::iterator j = releases.begin(); j != releases.end(); ++j) {
			MusicBrainz::Release *release = NULL;
			
			try {
				MusicBrainz::ReleaseIncludes includes = MusicBrainz::ReleaseIncludes().artist().counts().tracks().releaseEvents();
				release = q.getReleaseById((*j)->getId(), &includes);
				if(NULL == release)
					continue;
			}
			
			catch(/* const MusicBrainz::Exception &e */ const std::exception &e) {
				NSLog(@"MusicBrainz error: %s", e.what());
				continue;
			}
			
			NSMutableDictionary *releaseDictionary = [NSMutableDictionary dictionaryWithDictionary:trackDictionary];
			
			// Determine the track number
			for(int k = 0; k < release->getNumTracks(); ++k) {
				if(release->getTrack(k)->getId() == track->getId())
					[releaseDictionary setValue:[NSNumber numberWithInt:(1 + k)] forKey:MetadataTrackNumberKey];
			}
			
//			if(!release->getId().empty())
//				[releaseDictionary setValue:[NSString stringWithCString:release->getId().c_str() encoding:NSUTF8StringEncoding] forKey:@"releaseID"];
			if(!release->getTitle().empty())
				[releaseDictionary setValue:[NSString stringWithCString:release->getTitle().c_str() encoding:NSUTF8StringEncoding] forKey:MetadataAlbumTitleKey];
			if(0 != release->getNumTracks())
				[releaseDictionary setValue:[NSNumber numberWithInt:release->getNumTracks()] forKey:MetadataTrackTotalKey];
//			if(0 != release->getNumDiscs())
//				[releaseDictionary setValue:[NSNumber numberWithInt:release->getNumDiscs()] forKey:MetadataDiscTotalKey];
			// Only set the album artist if it is different from the track artist
			if(NULL != release->getArtist()) {
				NSString *albumArtist = [NSString stringWithCString:release->getArtist()->getName().c_str() encoding:NSUTF8StringEncoding];
				if(NO == [albumArtist isEqualToString:[releaseDictionary valueForKey:MetadataArtistKey]])
					[releaseDictionary setValue:albumArtist forKey:MetadataAlbumArtistKey];
			}
//			if(!release->getAsin().empty())
//				[releaseDictionary setValue:[NSString stringWithCString:release->getAsin().c_str() encoding:NSUTF8StringEncoding] forKey:@"ASIN"];
			
			// Take a best guess on the release date
			if(1 == release->getNumReleaseEvents()) {
				MusicBrainz::ReleaseEvent *releaseEvent = release->getReleaseEvent(0);
				[releaseDictionary setValue:[NSString stringWithCString:releaseEvent->getDate().c_str() encoding:NSUTF8StringEncoding] forKey:MetadataDateKey];
			}
			else {
				NSString	*currentLocale		= [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLocale"];
				NSArray		*localeElements		= [currentLocale componentsSeparatedByString:@"_"];
//				NSString	*currentLanguage	= [localeElements objectAtIndex:0];
				NSString	*currentCountry		= [localeElements objectAtIndex:1];
				
				// Try to match based on the assumption that the disc is from the user's own locale
				for(int k = 0; k < release->getNumReleaseEvents(); ++k) {
					MusicBrainz::ReleaseEvent *releaseEvent = release->getReleaseEvent(k);
					NSString *releaseEventCountry = [NSString stringWithCString:releaseEvent->getCountry().c_str() encoding:NSASCIIStringEncoding];
					if(NSOrderedSame == [releaseEventCountry caseInsensitiveCompare:currentCountry])
						[releaseDictionary setValue:[NSString stringWithCString:releaseEvent->getDate().c_str() encoding:NSUTF8StringEncoding] forKey:MetadataDateKey];
				}
				
				// Nothing matched, just take the first one
				if(nil == [releaseDictionary valueForKey:MetadataDateKey] && 0 < release->getNumReleaseEvents()) {
					MusicBrainz::ReleaseEvent *releaseEvent = release->getReleaseEvent(0);
					[releaseDictionary setValue:[NSString stringWithCString:releaseEvent->getDate().c_str() encoding:NSUTF8StringEncoding] forKey:MetadataDateKey];
				}
			}
			
			// Look for Composer relations
			MusicBrainz::RelationList relations = track->getRelations(MusicBrainz::Relation::TO_TRACK);
			
			for(MusicBrainz::RelationList::iterator j = relations.begin(); j != relations.end(); ++j) {
				MusicBrainz::Relation *relation = *j;
								
				if("Composer" == MusicBrainz::extractFragment(relation->getType())) {
					if(MusicBrainz::Relation::TO_ARTIST == relation->getTargetType()) {
						MusicBrainz::Artist *composer = NULL;

						try {
							composer = q.getArtistById(relation->getTargetId());
							if(NULL == composer)
								continue;
						}
						
						catch(/* const MusicBrainz::Exception &e */ const std::exception &e) {
							NSLog(@"MusicBrainz error: %s", e.what());
							continue;
						}
						
						[releaseDictionary setValue:[NSString stringWithCString:composer->getName().c_str() encoding:NSUTF8StringEncoding] forKey:MetadataComposerKey];

						delete composer;
					}
				}				
			}
			
			[resultArray addObject:releaseDictionary];
			
			delete release;
		}
		
		delete track;
	}
	
	return [resultArray autorelease];
}

NSArray *
getMusicBrainzTracksMatchingPUID(NSString *PUID, NSError **error)
{
	NSCParameterAssert(nil != PUID);

	MusicBrainz::Query				q;
	MusicBrainz::TrackResultList	results;

	try {
		MusicBrainz::TrackFilter f = MusicBrainz::TrackFilter().puid([PUID cStringUsingEncoding:NSASCIIStringEncoding]);
		results = q.getTracks(&f);
	}
	
	catch(/* const MusicBrainz::Exception &e */const std::exception &e) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:NSLocalizedStringFromTable(@"An error occurred while querying MusicBrainz.", @"Errors", @"") forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"MusicBrainz error", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The error message was: %s", @"Errors", @""), e.what()] forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:NSCocoaErrorDomain 
										 code:0 
									 userInfo:errorDictionary];
		}
		
		return nil;
	}

	return buildMusicBrainzResultArray(q, results, error);
}

NSArray * 
getMusicBrainzTracksMatching(NSString *title, NSString *artist, NSString *albumTitle, NSNumber *duration, NSError **error)
{
	MusicBrainz::Query				q;
	MusicBrainz::TrackResultList	results;
		
	try {
		MusicBrainz::TrackFilter f = MusicBrainz::TrackFilter();
		if(nil != title)
			f.title([title cStringUsingEncoding:NSUTF8StringEncoding]);
		if(nil != artist)
			f.artistName([artist cStringUsingEncoding:NSUTF8StringEncoding]);
		if(nil != albumTitle)
			f.releaseTitle([albumTitle cStringUsingEncoding:NSUTF8StringEncoding]);
		if(nil != duration)
			f.duration([duration intValue]);
		results = q.getTracks(&f);
	}
	
	// FIXME: Why are MusicBrainz exception classes not caught by any catch block that is more specific?
	catch(/* const MusicBrainz::Exception &e */const std::exception &e) {
		if(nil != error) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:NSLocalizedStringFromTable(@"An error occurred while querying MusicBrainz.", @"Errors", @"") forKey:NSLocalizedDescriptionKey];
			[errorDictionary setObject:NSLocalizedStringFromTable(@"MusicBrainz error", @"Errors", @"") forKey:NSLocalizedFailureReasonErrorKey];
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The error message was: %s", @"Errors", @""), e.what()] forKey:NSLocalizedRecoverySuggestionErrorKey];
			
			*error = [NSError errorWithDomain:NSCocoaErrorDomain 
										 code:0 
									 userInfo:errorDictionary];
		}

		return nil;
	}

	return buildMusicBrainzResultArray(q, results, error);
}
