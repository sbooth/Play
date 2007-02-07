CREATE TABLE IF NOT EXISTS '%@' (

	'id' 					INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	'stream_id'				INTEGER,
	'position' 				INTEGER

);

CREATE TRIGGER 'remove_contained_streams_%@' DELETE ON 'streams'
	BEGIN
		DELETE FROM '%@' WHERE stream_id == old.id;
	END;
