CREATE TRIGGER IF NOT EXISTS 'stream_was_deleted' DELETE ON 'streams'
	BEGIN
		DELETE FROM 'playlist_entries' WHERE stream_id == old.id;
	END;
