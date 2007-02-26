UPDATE 'watch_folders' SET
		
		url = :url,
		name = :name
		
	WHERE id == :id;
	