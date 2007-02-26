CREATE TABLE IF NOT EXISTS 'watch_folders' (

	'id' 					INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	'url'					TEXT UNIQUE,
	
	'name'					TEXT

);
