CREATE TRIGGER IF NOT EXISTS 'playlist_was_deleted' DELETE ON 'playlists'
	BEGIN
		DELETE FROM 'playlist_entries' WHERE playlist_id == old.id;
	END;
