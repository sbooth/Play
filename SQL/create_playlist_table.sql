CREATE TABLE IF NOT EXISTS 'playlists' (

	'id' 					INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	
	'name' 					TEXT,

	'date_created' 			REAL,
	'first_played_date' 	REAL,
	'last_played_date' 		REAL,
	'play_count' 			INTEGER DEFAULT 0

);
