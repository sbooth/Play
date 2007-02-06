UPDATE 'playlists' SET
		
		name = ?,
		
		first_played_date = ?,
		last_played_date = ?,
		play_count = ?
		
	WHERE id == ?;