INSERT INTO 'streams' (

		url, 
		
		date_added,
		first_played_date,
		last_played_date,
		last_skipped_date,
		play_count,
		skip_count,
		rating,
		
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
		bpm,
				
		file_type,
		format_type,
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
		?,
		?, 
		?, 
		?, 
		?, 
		?, 
		?
		
	);
