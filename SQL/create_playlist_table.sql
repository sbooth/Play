## The playlist table
CREATE TABLE IF NOT EXISTS 'playlists' (

	'id' 					INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	'name' 					TEXT,

	## General playlist information
	'date_added' 			REAL,
	'first_played_date' 	REAL,
	'last_played_date' 		REAL

);
