SELECT * FROM 'streams' AS s, 'playlist_entries' AS p WHERE s.id IN (SELECT stream_id FROM 'playlist_entries' WHERE playlist_id == :playlist_id) AND s.id == p.stream_id ORDER BY position;
