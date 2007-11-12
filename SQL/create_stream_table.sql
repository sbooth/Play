CREATE TABLE IF NOT EXISTS 'streams' (

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
