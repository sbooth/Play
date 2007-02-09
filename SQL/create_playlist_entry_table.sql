CREATE TABLE IF NOT EXISTS 'playlist_entries' (

	'id' 					INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	'playlist_id'			INTEGER,
	'stream_id'				INTEGER,
	'position' 				INTEGER

);

CREATE TRIGGER 'playlist_was_deleted' DELETE ON 'playlists'
	BEGIN
		DELETE FROM 'playlist_entries' WHERE playlist_id == old.id;
	END;

CREATE TRIGGER 'stream_was_deleted' DELETE ON 'streams'
	BEGIN
		DELETE FROM 'playlist_entries' WHERE stream_id == old.id;
	END;
