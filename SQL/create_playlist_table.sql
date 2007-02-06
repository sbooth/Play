CREATE TABLE IF NOT EXISTS 'playlists' (

	'id' 					INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	'type'					INTEGER,
	'name' 					TEXT,

	'date_added' 			REAL,
	'first_played_date' 	REAL,
	'last_played_date' 		REAL,
	'play_count' 			INTEGER DEFAULT 0

);
