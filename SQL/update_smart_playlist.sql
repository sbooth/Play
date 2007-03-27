UPDATE 'smart_playlists' SET
		
		name = :name,

		predicate = :predicate,
		
		date_created = :date_created,
		first_played_date = :first_played_date,
		last_played_date = :last_played_date,
		play_count = :play_count
		
	WHERE id == :id;
