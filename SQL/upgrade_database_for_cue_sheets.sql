-- Ensure atomicity of this script
BEGIN TRANSACTION;

-- Rename the streams table, for later use
ALTER TABLE 'streams' RENAME TO 'streams_backup';

-- Create the new streams table
CREATE TABLE 'streams'  (
	'id'						INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	'url'						TEXT NOT NULL,
	'starting_frame'			INTEGER NOT NULL DEFAULT -1,
	'frame_count'				INTEGER NOT NULL DEFAULT -1,

	'date_added'				REAL,
	'first_played_date'			REAL,
	'last_played_date'			REAL,
	'last_skipped_date'			REAL,
	'play_count'				INTEGER DEFAULT 0,
	'skip_count'				INTEGER DEFAULT 0,
	'rating'					INTEGER,

	'title'						TEXT,
	'album_title'				TEXT,
	'artist'					TEXT,
	'album_artist'				TEXT,
	'genre'						TEXT,
	'composer'					TEXT,
	'date'						TEXT,
	'compilation'				INTEGER,
	'track_number'				INTEGER,
	'track_total'				INTEGER,
	'disc_number'				INTEGER,
	'disc_total'				INTEGER,
	'comment'					TEXT,
	'isrc'						TEXT,
	'mcn'						TEXT,
	'bpm'						INTEGER,

	'musicdns_puid'				TEXT,
	'musicbrainz_id'			TEXT,

	'reference_loudness'		REAL,
	'track_replay_gain'			REAL,
	'track_peak'				REAL,
	'album_replay_gain'			REAL,
	'album_peak'				REAL,
	
	'file_type'					TEXT,
	'data_format'				TEXT,
	'format_description'		TEXT,
	'bits_per_channel'			INTEGER,
	'channels_per_frame'		INTEGER,
	'sample_rate'				REAL,
	'total_frames'				INTEGER,
	'bitrate'					REAL,
	
	UNIQUE (url, starting_frame, frame_count)
);

-- Copy the old data into the new table
INSERT INTO 'streams' (
		id, 
		url,
		
		date_added,
		first_played_date,
		last_played_date,
		last_skipped_date,
		play_count,
		skip_count,
		rating,
		
		title, 
		album_title,
		artist, 
		album_artist,
		genre,
		composer,
		date,
		compilation,
		track_number,
		track_total,
		disc_number,
		disc_total,
		comment,
		isrc,
		mcn,
		bpm,

		musicdns_puid,
		musicbrainz_id,
		
		reference_loudness,
		track_replay_gain,
		track_peak,
		album_replay_gain,
		album_peak,
				
		file_type,
		data_format,
		format_description,
		bits_per_channel,
		channels_per_frame,
		sample_rate,
		total_frames,
		bitrate
		)
	SELECT 		
		id, 
		url,
		
		date_added,
		first_played_date,
		last_played_date,
		last_skipped_date,
		play_count,
		skip_count,
		rating,
		
		title, 
		album_title,
		artist, 
		album_artist,
		genre,
		composer,
		date,
		compilation,
		track_number,
		track_total,
		disc_number,
		disc_total,
		comment,
		isrc,
		mcn,
		bpm,

		musicdns_puid,
		musicbrainz_id,
		
		reference_loudness,
		track_replay_gain,
		track_peak,
		album_replay_gain,
		album_peak,
				
		file_type,
		data_format,
		format_description,
		bits_per_channel,
		channels_per_frame,
		sample_rate,
		total_frames,
		bitrate
	FROM 'streams_backup';

-- Delete the old table
DROP TABLE 'streams_backup';

-- Finito
COMMIT;
