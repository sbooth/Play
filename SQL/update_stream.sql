UPDATE 'streams' SET
		url = :url,
		starting_frame = :starting_frame,
		frame_count = :frame_count,
		
		date_added = :date_added,
		first_played_date = :first_played_date,
		last_played_date = :last_played_date,
		last_skipped_date = :last_skipped_date,
		play_count = :play_count,
		skip_count = :skip_count,
		rating = :rating,		

		title = :title,
		album_title = :album_title,
		artist = :artist,
		album_artist = :album_artist,
		genre = :genre,
		composer = :composer,
		date = :date,
		compilation = :compilation,
		track_number = :track_number,
		track_total = :track_total,
		disc_number = :disc_number,
		disc_total = :disc_total,
		comment = :comment,
		isrc = :isrc,
		mcn = :mcn,
		bpm = :bpm,
		
		musicdns_puid = :musicdns_puid,
		musicbrainz_id = :musicbrainz_id,

		reference_loudness = :reference_loudness,
		track_replay_gain = :track_replay_gain,
		track_peak = :track_peak,
		album_replay_gain = :album_replay_gain,
		album_peak = :album_peak,

		file_type = :file_type,
		data_format = :data_format,
		format_description = :format_description,
		bits_per_channel = :bits_per_channel,
		channels_per_frame = :channels_per_frame,
		sample_rate = :sample_rate,
		total_frames = :total_frames,
		bitrate = :bitrate

	WHERE id == :id;
	