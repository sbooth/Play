UPDATE 'playlists' SET
		
		name = :name,
		
		date_created = :date_created,
		first_played_date = :first_played_date,
		last_played_date = :last_played_date,
		play_count = :play_count
		
	WHERE id == :id;
