extends RefCounted
## เทสต์ระบบเสียง — game/systems/audio/ · Issue #60
## รันผ่าน godot --headless --path game --script res://tests/run_tests.gd

func test_all_wav_files_loadable_and_non_empty() -> bool:
	# 1. ตรวจสอบไฟล์ SFX ทั้งหมดตาม contract
	for sfx_name: StringName in AudioDirector.SFX_PATHS:
		var path: String = AudioDirector.SFX_PATHS[sfx_name]
		if not FileAccess.file_exists(path):
			printerr("Missing SFX file: ", path)
			return false
		var stream: AudioStream = load(path) as AudioStream
		if stream == null:
			printerr("Failed to load SFX stream: ", path)
			return false
		if stream.get_length() <= 0.0:
			printerr("SFX length is zero: ", path)
			return false

	# 2. ตรวจสอบไฟล์ Music ทั้งหมดตาม contract (พร้อม loop_mode)
	for music_name: StringName in AudioDirector.MUSIC_PATHS:
		var path: String = AudioDirector.MUSIC_PATHS[music_name]
		if not FileAccess.file_exists(path):
			printerr("Missing Music file: ", path)
			return false
		var stream: AudioStream = load(path) as AudioStream
		if stream == null:
			printerr("Failed to load Music stream: ", path)
			return false
		if stream.get_length() <= 0.0:
			printerr("Music length is zero: ", path)
			return false
		if stream is AudioStreamWAV:
			var wav: AudioStreamWAV = stream as AudioStreamWAV
			# ตรวจสอบการตั้งค่า loop จาก .import
			if wav.loop_mode != AudioStreamWAV.LOOP_FORWARD:
				printerr("Music stream loop_mode is not LOOP_FORWARD: ", path)
				return false
			if wav.loop_end <= 0:
				printerr("Music stream loop_end is not greater than 0: ", path, " (got: ", wav.loop_end, ")")
				return false

	return true


func test_signal_selection_damage() -> bool:
	var player_dummy := Node2D.new()
	player_dummy.add_to_group(&"player")

	var enemy_dummy := Node2D.new()
	enemy_dummy.add_to_group(&"enemies")

	var sfx_player: StringName = AudioDirector.select_sfx_for_damage(player_dummy)
	var sfx_enemy: StringName = AudioDirector.select_sfx_for_damage(enemy_dummy)
	var sfx_null: StringName = AudioDirector.select_sfx_for_damage(null)

	player_dummy.free()
	enemy_dummy.free()

	return sfx_player == &"hit_player" and sfx_enemy == &"hit_flesh" and sfx_null == &"hit_flesh"


func test_signal_selection_combat_events() -> bool:
	var parry_sfx: StringName = AudioDirector.select_sfx_for_attack_deflected()
	var enemy_die_sfx: StringName = AudioDirector.select_sfx_for_enemy_died()
	var boss_sfx: StringName = AudioDirector.select_sfx_for_boss_engaged()
	var boss_music: StringName = AudioDirector.select_music_for_boss_engaged()

	var ok_parry: bool = parry_sfx == &"parry"
	var ok_die: bool = enemy_die_sfx == &"enemy_die"
	var ok_boss_sfx: bool = boss_sfx == &"boss_roar"
	var ok_boss_music: bool = boss_music == &"music_combat"

	return ok_parry and ok_die and ok_boss_sfx and ok_boss_music


func test_signal_selection_screen_shake() -> bool:
	var shake_high: StringName = AudioDirector.select_sfx_for_screen_shake(0.8)
	var shake_exact: StringName = AudioDirector.select_sfx_for_screen_shake(0.4)
	var shake_low: StringName = AudioDirector.select_sfx_for_screen_shake(0.39)
	var shake_zero: StringName = AudioDirector.select_sfx_for_screen_shake(0.0)

	var ok_high: bool = shake_high == &"thud"
	var ok_exact: bool = shake_exact == &"thud"
	var ok_low: bool = shake_low == &""
	var ok_zero: bool = shake_zero == &""

	return ok_high and ok_exact and ok_low and ok_zero


func test_signal_selection_room_events() -> bool:
	var room_start_music: StringName = AudioDirector.select_music_for_room_started()
	var room_clear_music: StringName = AudioDirector.select_music_for_room_cleared()
	var room_clear_sfx: StringName = AudioDirector.select_sfx_for_room_cleared()

	var ok_start: bool = room_start_music == &"music_combat"
	var ok_clear_music: bool = room_clear_music == &"music_explore"
	var ok_clear_sfx: bool = room_clear_sfx == &"door_open"

	return ok_start and ok_clear_music and ok_clear_sfx


func test_pool_limits_and_no_overflow() -> bool:
	var director := AudioDirector.new()
	director.max_sfx_players = 4
	director.max_sfx_2d_players = 3
	director.max_polyphony_per_sfx = 20
	director.setup()

	# เรียกเล่น SFX ปกติ 20 ครั้ง — ขนาด pool ต้องไม่เกิน limit 4
	for i in range(20):
		director.play_sfx(&"slash")

	var sfx_pool_ok: bool = director.get_sfx_pool_size() <= 4

	# เรียกเล่น SFX 2D 20 ครั้ง — ขนาด pool 2D ต้องไม่เกิน limit 3
	for i in range(20):
		director.play_sfx(&"parry", Vector2(100.0 + i, 200.0))

	var sfx_2d_pool_ok: bool = director.get_sfx_2d_pool_size() <= 3

	director.free()
	return sfx_pool_ok and sfx_2d_pool_ok


func test_music_crossfade_explore_to_combat() -> bool:
	var director := AudioDirector.new()
	director.music_crossfade_duration = 1.0
	director.setup()

	# เริ่มเพลง explore แบบทันที (fade = 0.0)
	director.play_music(&"music_explore", 0.0)
	var initial_ok: bool = director.current_music_name == &"music_explore"

	# สั่ง crossfade ไป music_combat ด้วยเวลา 1.0 วินาที
	director.play_music(&"music_combat", 1.0)
	var start_crossfade_ok: bool = director.current_music_name == &"music_combat"

	# tick ไปครึ่งทาง (0.5 วินาที)
	director.tick(0.5)
	var mid_ok: bool = director.current_music_name == &"music_combat"

	# tick ให้จบ crossfade (อีก 0.6 วินาที รวมเป็น 1.1 วินาที)
	director.tick(0.6)
	var final_ok: bool = director.current_music_name == &"music_combat"

	director.free()
	return initial_ok and start_crossfade_ok and mid_ok and final_ok


func test_music_fade_out_on_player_died() -> bool:
	var director := AudioDirector.new()
	director.music_crossfade_duration = 1.0
	director.setup()

	director.play_music(&"music_combat", 0.0)
	var playing_ok: bool = director.current_music_name == &"music_combat"

	# จำลอง signal player_died ผ่าน EventBus
	EventBus.player_died.emit()

	# tick ให้ fade out เสร็จสิ้น (1.1 วินาที)
	director.tick(1.1)
	var stopped_ok: bool = director.current_music_name == &""

	director.free()
	return playing_ok and stopped_ok


func test_event_bus_room_transitions() -> bool:
	var director := AudioDirector.new()
	director.music_crossfade_duration = 0.5
	director.setup()

	# 1. room_started -> combat music
	EventBus.room_started.emit(director, Rect2(0, 0, 960, 540))
	director._confirm_combat(director.get_instance_id())  # จบ frame (เทสต์อยู่นอก tree — call_deferred ไม่รัน)
	var room_start_ok: bool = director.current_music_name == &"music_combat"
	director.tick(0.6)

	# 2. room_cleared -> explore music
	EventBus.room_cleared.emit(director)
	var room_clear_ok: bool = director.current_music_name == &"music_explore"
	director.tick(0.6)

	director.free()
	return room_start_ok and room_clear_ok


func test_audio_buses_ensured() -> bool:
	AudioDirector.ensure_buses()
	var music_idx: int = AudioServer.get_bus_index(&"Music")
	var sfx_idx: int = AudioServer.get_bus_index(&"SFX")

	if music_idx == -1 or sfx_idx == -1:
		return false

	var music_send: StringName = AudioServer.get_bus_send(music_idx)
	var sfx_send: StringName = AudioServer.get_bus_send(sfx_idx)

	# เรียกซ้ำต้อง idempotent (index และจำนวน bus ไม่ผิดเพี้ยน)
	var count_before: int = AudioServer.bus_count
	AudioDirector.ensure_buses()
	var count_after: int = AudioServer.bus_count

	return music_send == &"Master" and sfx_send == &"Master" and count_before == count_after


func test_polyphony_limit() -> bool:
	var director := AudioDirector.new()
	director.max_sfx_players = 16
	director.max_polyphony_per_sfx = 2
	director.setup()

	# เล่น slash 5 ครั้งติดต่อกัน
	director.play_sfx(&"slash")
	director.play_sfx(&"slash")
	director.play_sfx(&"slash")
	director.play_sfx(&"slash")

	# active count ของ slash ต้องไม่เกิน 2
	var slash_active: int = director._sfx_active_counts.get(&"slash", 0)
	director.free()

	return slash_active <= 2


func test_music_playback_beyond_17s_loops() -> bool:
	for music_name: StringName in AudioDirector.MUSIC_PATHS:
		var path: String = AudioDirector.MUSIC_PATHS[music_name]
		var stream: AudioStream = load(path) as AudioStream
		if not (stream is AudioStreamWAV):
			return false
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		if wav.loop_mode != AudioStreamWAV.LOOP_FORWARD or wav.loop_end <= 0:
			printerr("Music loop not configured: ", path, " mode=", wav.loop_mode, " end=", wav.loop_end)
			return false

		# Render playback beyond 17s (file length is 16.0s)
		var playback: AudioStreamPlayback = wav.instantiate_playback()
		if playback == null:
			printerr("Could not instantiate playback: ", path)
			return false
		playback.start(0.0)
		var chunk_size: int = 44100
		var has_sound: bool = false
		for sec in range(18):
			var frames: PackedVector2Array = playback.mix_audio(1.0, chunk_size)
			if not playback.is_playing():
				printerr("Playback stopped prematurely at sec ", sec, " for ", path)
				return false
			for f in frames:
				if f.x != 0.0 or f.y != 0.0:
					has_sound = true
					break

		if not playback.is_playing():
			printerr("Playback not playing after 18s: ", path)
			return false
		var pos: float = playback.get_playback_position()
		if pos > 3.0:
			printerr("Playback position did not loop back: pos=", pos)
			return false
		if not has_sound:
			printerr("Playback produced only silence: ", path)
			return false

	return true


func test_stop_music_during_crossfade_fades_and_stops_both() -> bool:
	var director := AudioDirector.new()
	director.music_crossfade_duration = 2.0
	director.setup()

	# Start explore music
	director.play_music(&"music_explore", 0.0)
	var p_explore: AudioStreamPlayer = director._active_music_player

	# Crossfade to combat music over 2.0s
	director.play_music(&"music_combat", 2.0)
	var p_combat: AudioStreamPlayer = director._active_music_player

	# Tick 1.0s into crossfade — both should be sounding
	director.tick(1.0)
	var explore_mid_vol: float = p_explore.volume_db
	var combat_mid_vol: float = p_combat.volume_db
	var both_sounding: bool = explore_mid_vol > AudioDirector.SILENCE_DB and combat_mid_vol > AudioDirector.SILENCE_DB

	# Stop music with fade 1.0s during crossfade
	director.stop_music(1.0)
	var is_fading_out: bool = director._is_fading_out

	# Tick 0.5s into stop fade — both players should still be fading down from mid volume
	director.tick(0.5)
	var explore_fading_down: bool = p_explore.volume_db < explore_mid_vol and p_explore.volume_db > AudioDirector.SILENCE_DB
	var combat_fading_down: bool = p_combat.volume_db < combat_mid_vol and p_combat.volume_db > AudioDirector.SILENCE_DB

	# Tick to completion (0.6s -> 1.1s total)
	director.tick(0.6)
	var explore_silent: bool = p_explore.volume_db <= AudioDirector.SILENCE_DB
	var combat_silent: bool = p_combat.volume_db <= AudioDirector.SILENCE_DB
	var stopped_clean: bool = director.current_music_name == &"" and not director._is_fading_out and not director._is_crossfading

	director.free()
	return both_sounding and is_fading_out and explore_fading_down and combat_fading_down and explore_silent and combat_silent and stopped_clean


func test_play_music_during_fade_does_not_bounce_volume() -> bool:
	var director := AudioDirector.new()
	director.music_crossfade_duration = 2.0
	director.setup()

	director.play_music(&"music_explore", 0.0)
	var p_explore: AudioStreamPlayer = director._active_music_player

	# Fade out over 2.0s
	director.stop_music(2.0)
	director.tick(1.0)  # at 1.0s / 2.0s, linear volume is ~0.5 (~ -6 dB)
	var vol_before_play: float = p_explore.volume_db

	# While fading out, call play_music(combat)
	director.play_music(&"music_combat", 2.0)
	# explore player must NOT bounce back to 0 dB!
	# Its volume must immediately be <= vol_before_play
	var vol_after_play: float = p_explore.volume_db
	var did_not_bounce: bool = vol_after_play <= vol_before_play + 0.1 and vol_after_play < -3.0

	# Tick 0.5s -> explore should continue fading down from vol_before_play, not from 0 dB
	director.tick(0.5)
	var continued_fading_down: bool = p_explore.volume_db < vol_before_play

	director.free()
	return did_not_bounce and continued_fading_down


func test_change_music_during_crossfade_does_not_cut_sound() -> bool:
	var director := AudioDirector.new()
	director.music_crossfade_duration = 2.0
	director.setup()

	# Start explore
	director.play_music(&"music_explore", 0.0)
	var p1: AudioStreamPlayer = director._active_music_player

	# Crossfade to combat
	director.play_music(&"music_combat", 2.0)
	var p2: AudioStreamPlayer = director._active_music_player

	director.tick(0.8)
	var p2_vol_mid: float = p2.volume_db

	# Middle of crossfade! Now change back to explore
	director.play_music(&"music_explore", 2.0)

	# Sound should NOT be abruptly cut to SILENCE_DB
	var p2_not_cut: bool = p2.volume_db > AudioDirector.SILENCE_DB
	# p2 should fade down smoothly
	director.tick(0.5)
	var p2_fading_smoothly: bool = p2.volume_db < p2_vol_mid and p2.volume_db > AudioDirector.SILENCE_DB

	director.free()
	return p2_not_cut and p2_fading_smoothly


func test_autoplay_and_respawn() -> bool:
	var director := AudioDirector.new()
	var default_autoplay_ok: bool = director.autoplay_music == &"music_explore"

	# When ready is called, autoplay_music starts
	director._ready()
	var autoplay_started: bool = director.current_music_name == &"music_explore"

	# When player dies, music stops
	EventBus.player_died.emit()
	director.tick(2.0)
	var stopped_on_death: bool = director.current_music_name == &""

	# When player respawns, autoplay_music resumes
	EventBus.player_respawn_requested.emit(Vector2.ZERO)
	var resumed_on_respawn: bool = director.current_music_name == &"music_explore"

	director.free()
	return default_autoplay_ok and autoplay_started and stopped_on_death and resumed_on_respawn


func test_pool_eviction_steals_oldest_player() -> bool:
	var director := AudioDirector.new()
	director.max_sfx_players = 2
	director.max_polyphony_per_sfx = 10
	director.setup()

	# Play 1 -> acquires player 0
	director.play_sfx(&"slash")
	var p0: AudioStreamPlayer = director._sfx_pool[0]

	# Play 2 -> acquires player 1
	director.play_sfx(&"slash")
	var p1: AudioStreamPlayer = director._sfx_pool[1]

	# Pool is full (size 2). Next acquire must steal p0 (the oldest)
	director.play_sfx(&"slash")
	var p_stolen_first: AudioStreamPlayer = director._acquire_sfx_player()
	# Because p0 was used for Play 3, p1 has now been playing longest!
	# So p_stolen_first should be p1!
	var stole_oldest_p1: bool = (p_stolen_first == p1)

	director.free()
	return stole_oldest_p1


func test_room_started_and_cleared_same_frame() -> bool:
	var director := AudioDirector.new()
	director.music_crossfade_duration = 1.0
	director.setup()

	# Start playing music_explore and seek/advance to 4.5s
	director.play_music(&"music_explore", 0.0)
	var p_explore: AudioStreamPlayer = director._active_music_player
	director.seek_music(4.5)
	var pos_before: float = director.get_music_playback_position()
	var sfx_count_before: int = director._sfx_play_counter

	# Simulate entering already cleared room: room_started + room_cleared in the exact same frame
	var mock_room := Node.new()
	EventBus.room_started.emit(mock_room, Rect2(0, 0, 960, 540))
	EventBus.room_cleared.emit(mock_room)

	# 1. explore music did not restart: same player, active, current_music_name unchanged
	var music_is_explore: bool = director.current_music_name == &"music_explore"
	var same_player: bool = director._active_music_player == p_explore
	var pos_after: float = director.get_music_playback_position()
	# Playback position must not reset to 0
	var pos_did_not_reset: bool = pos_after >= 4.0 and is_equal_approx(pos_after, pos_before)
	# 2. door_open must NOT play for same-frame clear
	var no_door_open: bool = director._sfx_play_counter == sfx_count_before

	# 3. Conversely, when room has real combat (tick between started and cleared) -> door_open plays!
	EventBus.room_started.emit(mock_room, Rect2(0, 0, 960, 540))
	director._confirm_combat(mock_room.get_instance_id())  # จบ frame โดยยังไม่มี room_cleared = สู้จริง
	director.tick(0.5) # combat active over time
	EventBus.room_cleared.emit(mock_room)
	var door_open_played_after_combat: bool = director._sfx_play_counter > sfx_count_before

	mock_room.free()
	director.free()

	return music_is_explore and same_player and pos_did_not_reset and no_door_open and door_open_played_after_combat


func test_music_seam_jump_less_than_five_times_average() -> bool:
	for music_name: StringName in AudioDirector.MUSIC_PATHS:
		var path: String = AudioDirector.MUSIC_PATHS[music_name]
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			printerr("Cannot open wav: ", path)
			return false
		var data: PackedByteArray = file.get_buffer(file.get_length())
		file.close()

		# Standard WAV format: find 'data' chunk
		var pcm_offset: int = 44
		for i in range(12, min(100, data.size() - 4)):
			if data[i] == 0x64 and data[i+1] == 0x61 and data[i+2] == 0x74 and data[i+3] == 0x61: # 'data'
				pcm_offset = i + 8
				break

		var num_samples: int = (data.size() - pcm_offset) / 4 # 2 bytes * 2 channels
		if num_samples <= 100:
			return false

		var left_samples: PackedInt32Array = PackedInt32Array()
		var right_samples: PackedInt32Array = PackedInt32Array()
		left_samples.resize(num_samples)
		right_samples.resize(num_samples)

		for i in range(num_samples):
			var idx: int = pcm_offset + i * 4
			var vl: int = data[idx] | (data[idx + 1] << 8)
			if vl >= 32768:
				vl -= 65536
			var vr: int = data[idx + 2] | (data[idx + 3] << 8)
			if vr >= 32768:
				vr -= 65536
			left_samples[i] = vl
			right_samples[i] = vr

		for ch_samples: PackedInt32Array in [left_samples, right_samples]:
			var jump: float = absf(float(ch_samples[0] - ch_samples[num_samples - 1]))
			var total_step: float = 0.0
			for i in range(1, num_samples):
				total_step += absf(float(ch_samples[i] - ch_samples[i - 1]))
			var avg_step: float = total_step / float(num_samples - 1)
			var ratio: float = jump / avg_step if avg_step > 0.0 else 0.0
			if ratio >= 5.0:
				printerr("Seam jump ratio too high in ", path, ": ratio=", ratio)
				return false

	return true

