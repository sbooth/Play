SELECT * FROM 'streams' WHERE id IN (SELECT stream_id FROM 'playlist_entries' WHERE playlist_id == :playlist_id);
