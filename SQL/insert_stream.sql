INSERT INTO 'streams' (
		
		url, 
		
		date_added,
		first_played_date,
		last_played_date,
		play_count,
		
		title, 
		album_title,
		artist, 
		album_artist,
		genre,
		composer,
		date,
		compilation,
		track_number,
		track_total,
		disc_number,
		disc_total,
		comment,
		isrc,
		mcn,
		
		bits_per_channel,
		channels_per_frame,
		sample_rate,
		total_frames,
		duration,
		bitrate
	) 
	
	VALUES (
		?, 
		
		?, 
		?, 
		?, 
		?, 
		
		?, 
		?, 
		?, 
		?, 
		?, 
		?, 
		?, 
		?, 
		?, 
		?, 
		?, 
		?, 
		?, 
		?, 
		?, 
		
		?, 
		?, 
		?, 
		?, 
		?, 
		?
	);