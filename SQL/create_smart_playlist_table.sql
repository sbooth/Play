CREATE TABLE IF NOT EXISTS 'smart_playlists' (

	'id' 					INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	
	'name' 					TEXT,

	'predicate' 			TEXT,

	'date_created' 			REAL,
	'first_played_date' 	REAL,
	'last_played_date' 		REAL,
	'play_count' 			INTEGER DEFAULT 0

);
