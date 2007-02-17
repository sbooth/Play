CREATE TABLE IF NOT EXISTS 'playlist_entries' (

	'id' 					INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	'playlist_id'			INTEGER,
	'stream_id'				INTEGER,
	'stream_index' 			INTEGER

);
