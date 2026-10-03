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
			# ตรวจสอบการตั้งค่า loop
			if wav.loop_mode != AudioStreamWAV.LOOP_FORWARD:
				# ถ้าใน .import ยังเป็น default ให้ AudioDirector.get_music_stream() ตั้งค่า loop ให้
				var director := AudioDirector.new()
				var loaded_stream: AudioStream = director.get_music_stream(music_name)
				director.free()
				if loaded_stream is AudioStreamWAV and (loaded_stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_FORWARD:
					printerr("Music stream loop_mode is not LOOP_FORWARD: ", path)
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

