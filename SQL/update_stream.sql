UPDATE 'streams' SET
		
		first_played_date = ?,
		last_played_date = ?,
		play_count = ?,
		
		title = ?,
		album_title = ?,
		artist = ?,
		album_artist = ?,
		genre = ?,
		composer = ?,
		date = ?,
		compilation = ?,
		track_number = ?,
		track_total = ?,
		disc_number = ?,
		disc_total = ?,
		comment = ?,
		isrc = ?,
		mcn = ?		
		
	WHERE id == ?;