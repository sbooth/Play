CREATE TABLE IF NOT EXISTS 'streams' (

	'id' 					INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	'url'					TEXT UNIQUE,

	'date_added' 			REAL,
	'first_played_date' 	REAL,
	'last_played_date' 		REAL,
	'play_count' 			INTEGER DEFAULT 0,

	'title' 				TEXT,
	'album_title' 			TEXT,
	'artist'	 			TEXT,
	'album_artist' 			TEXT,
	'genre' 				TEXT,
	'composer' 				TEXT,
	'date' 					TEXT,
	'compilation' 			INTEGER,
	'track_number' 			INTEGER,
	'track_total' 			INTEGER,
	'disc_number' 			INTEGER,
	'disc_total' 			INTEGER,
	'comment' 				TEXT,
	'isrc' 					TEXT,
	'mcn' 					TEXT,

	'file_type'				TEXT,
	'format_type'			TEXT,
	'bits_per_channel'		INTEGER,
	'channels_per_frame'	INTEGER,
	'sample_rate' 			REAL,
	'total_frames' 			INTEGER,
	'duration'				REAL,
	'bitrate' 				REAL
	
);
