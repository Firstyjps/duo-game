class_name AudioDirector
extends Node
## AudioDirector — ตัวจัดการระบบเสียงและเพลง (เฟส 6 Issue #60)
## วางในฉากเกม (ไม่ใช่ autoload) · จัดการ Bus Music/SFX, pool ผู้เล่นเสียง, และ crossfade เพลงตาม EventBus

const SFX_PATHS: Dictionary = {
	&"slash": "res://systems/audio/sfx/slash.wav",
	&"hit_flesh": "res://systems/audio/sfx/hit_flesh.wav",
	&"hit_player": "res://systems/audio/sfx/hit_player.wav",
	&"parry": "res://systems/audio/sfx/parry.wav",
	&"dodge": "res://systems/audio/sfx/dodge.wav",
	&"enemy_die": "res://systems/audio/sfx/enemy_die.wav",
	&"boss_roar": "res://systems/audio/sfx/boss_roar.wav",
	&"door_close": "res://systems/audio/sfx/door_close.wav",
	&"door_open": "res://systems/audio/sfx/door_open.wav",
	&"heal": "res://systems/audio/sfx/heal.wav",
	&"shard_pickup": "res://systems/audio/sfx/shard_pickup.wav",
	&"ui_move": "res://systems/audio/sfx/ui_move.wav",
	&"ui_confirm": "res://systems/audio/sfx/ui_confirm.wav",
	&"thud": "res://systems/audio/sfx/thud.wav",
}

const MUSIC_PATHS: Dictionary = {
	&"music_explore": "res://systems/audio/sfx/music_explore.wav",
	&"music_combat": "res://systems/audio/sfx/music_combat.wav",
}

const SILENCE_DB: float = -80.0
const DEFAULT_MUSIC_VOLUME_DB: float = 0.0

@export_group("Pool Limits")
## จำนวน AudioStreamPlayer สูงสุดสำหรับ SFX ทั่วไป (ไม่ 2D)
@export var max_sfx_players: int = 16
## จำนวน AudioStreamPlayer2D สูงสุดสำหรับ SFX ในตำแหน่ง 2D
@export var max_sfx_2d_players: int = 16
## จำกัดจำนวนเสียงประเภทเดียวกันที่เล่นพร้อมกัน (ป้องกันเสียงซ้อนหนวกหู)
@export var max_polyphony_per_sfx: int = 3

@export_group("Playback Tuning")
## เพลงที่จะเล่นอัตโนมัติเมื่อเริ่มเกม และเล่นใหม่เมื่อผู้เล่นเกิดใหม่ (respawn)
@export var autoplay_music: StringName = &"music_explore"
## การสุ่ม pitch ของ SFX (±5% คือ 0.05)
@export var pitch_randomness: float = 0.05
## ระยะเวลา crossfade เพลงพื้นฐาน (วินาที)
@export var music_crossfade_duration: float = 1.5
## ระยะเสียงได้ยินสูงสุดสำหรับ AudioStreamPlayer2D
@export var sfx_max_distance: float = 1200.0

var current_music_name: StringName = &""

var _sfx_cache: Dictionary = {}
var _music_cache: Dictionary = {}

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_2d_pool: Array[AudioStreamPlayer2D] = []
var _sfx_active_counts: Dictionary = {}
var _sfx_play_counter: int = 0

var _music_players: Array[AudioStreamPlayer] = []
var _music_player_a: AudioStreamPlayer = null
var _music_player_b: AudioStreamPlayer = null
var _active_music_player: AudioStreamPlayer = null
var _fading_music_player: AudioStreamPlayer = null
var _fading_entries: Array[Dictionary] = []

var _is_crossfading: bool = false
var _is_fading_out: bool = false
var _fade_timer: float = 0.0
var _fade_duration: float = 1.5
var _fade_start_active_linear: float = 0.0


func _enter_tree() -> void:
	_connect_event_bus()


func _ready() -> void:
	setup()
	if not autoplay_music.is_empty():
		play_music(autoplay_music, 0.0)


func _process(delta: float) -> void:
	tick(delta)


func _exit_tree() -> void:
	_disconnect_event_bus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_event_bus()


# ─────────────────────────────────────────────────────────────
# Setup & Lifecycle
# ─────────────────────────────────────────────────────────────

## กำหนดค่าเริ่มต้น สร้าง bus, pool, และผูก EventBus
func setup() -> void:
	ensure_buses()
	_init_music_players()
	_connect_event_bus()


## สร้าง Audio Bus "Music" และ "SFX" หากยังไม่มีใน AudioServer (ปลอดภัยสำหรับเรียกซ้ำ)
static func ensure_buses() -> void:
	if AudioServer.get_bus_index(&"Music") == -1:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, &"Music")
		AudioServer.set_bus_send(idx, &"Master")

	if AudioServer.get_bus_index(&"SFX") == -1:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, &"SFX")
		AudioServer.set_bus_send(idx, &"Master")


func _init_music_players() -> void:
	if _music_player_a == null:
		_music_player_a = AudioStreamPlayer.new()
		_music_player_a.name = "MusicPlayerA"
		_music_player_a.bus = &"Music"
		_music_player_a.volume_db = SILENCE_DB
		add_child(_music_player_a)
		_music_players.append(_music_player_a)

	if _music_player_b == null:
		_music_player_b = AudioStreamPlayer.new()
		_music_player_b.name = "MusicPlayerB"
		_music_player_b.bus = &"Music"
		_music_player_b.volume_db = SILENCE_DB
		add_child(_music_player_b)
		_music_players.append(_music_player_b)

	_active_music_player = _music_player_a
	_fading_music_player = _music_player_b


func _connect_event_bus() -> void:
	if EventBus == null or not is_instance_valid(EventBus):
		return

	if not EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.connect(_on_damage_dealt)
	if not EventBus.attack_deflected.is_connected(_on_attack_deflected):
		EventBus.attack_deflected.connect(_on_attack_deflected)
	if not EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.connect(_on_enemy_died)
	if not EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.connect(_on_player_died)
	if not EventBus.player_respawn_requested.is_connected(_on_player_respawn_requested):
		EventBus.player_respawn_requested.connect(_on_player_respawn_requested)
	if not EventBus.boss_engaged.is_connected(_on_boss_engaged):
		EventBus.boss_engaged.connect(_on_boss_engaged)
	if not EventBus.room_started.is_connected(_on_room_started):
		EventBus.room_started.connect(_on_room_started)
	if not EventBus.room_cleared.is_connected(_on_room_cleared):
		EventBus.room_cleared.connect(_on_room_cleared)
	if not EventBus.screen_shake_requested.is_connected(_on_screen_shake_requested):
		EventBus.screen_shake_requested.connect(_on_screen_shake_requested)


func _disconnect_event_bus() -> void:
	if EventBus == null or not is_instance_valid(EventBus):
		return

	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)
	if EventBus.attack_deflected.is_connected(_on_attack_deflected):
		EventBus.attack_deflected.disconnect(_on_attack_deflected)
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)
	if EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)
	if EventBus.player_respawn_requested.is_connected(_on_player_respawn_requested):
		EventBus.player_respawn_requested.disconnect(_on_player_respawn_requested)
	if EventBus.boss_engaged.is_connected(_on_boss_engaged):
		EventBus.boss_engaged.disconnect(_on_boss_engaged)
	if EventBus.room_started.is_connected(_on_room_started):
		EventBus.room_started.disconnect(_on_room_started)
	if EventBus.room_cleared.is_connected(_on_room_cleared):
		EventBus.room_cleared.disconnect(_on_room_cleared)
	if EventBus.screen_shake_requested.is_connected(_on_screen_shake_requested):
		EventBus.screen_shake_requested.disconnect(_on_screen_shake_requested)


# ─────────────────────────────────────────────────────────────
# Logic Tick (Deterministic)
# ─────────────────────────────────────────────────────────────

## อัปเดตสถานะ crossfade และ fade out — แยกให้เทสต์เรียกแบบ deterministic ได้
func tick(delta: float) -> void:
	if _is_crossfading:
		_fade_timer += delta
		var progress: float = clampf(_fade_timer / maxf(0.001, _fade_duration), 0.0, 1.0)
		if _active_music_player != null:
			var act_linear: float = lerpf(_fade_start_active_linear, 1.0, progress)
			_active_music_player.volume_db = _linear_to_db_safe(act_linear)

		for entry: Dictionary in _fading_entries:
			var p: AudioStreamPlayer = entry["player"]
			var start_lin: float = float(entry["start_linear"])
			p.volume_db = _linear_to_db_safe(start_lin * (1.0 - progress))

		if progress >= 1.0:
			_is_crossfading = false
			for entry: Dictionary in _fading_entries:
				var p: AudioStreamPlayer = entry["player"]
				if p.is_inside_tree():
					p.stop()
				p.volume_db = SILENCE_DB
			_fading_entries.clear()
			_fading_music_player = null
			if _active_music_player != null:
				_active_music_player.volume_db = DEFAULT_MUSIC_VOLUME_DB

	elif _is_fading_out:
		_fade_timer += delta
		var progress: float = clampf(_fade_timer / maxf(0.001, _fade_duration), 0.0, 1.0)
		for entry: Dictionary in _fading_entries:
			var p: AudioStreamPlayer = entry["player"]
			var start_lin: float = float(entry["start_linear"])
			p.volume_db = _linear_to_db_safe(start_lin * (1.0 - progress))

		if progress >= 1.0:
			_is_fading_out = false
			for entry: Dictionary in _fading_entries:
				var p: AudioStreamPlayer = entry["player"]
				if p.is_inside_tree():
					p.stop()
				p.volume_db = SILENCE_DB
			_fading_entries.clear()
			_fading_music_player = null
			if _active_music_player != null:
				if _active_music_player.is_inside_tree():
					_active_music_player.stop()
				_active_music_player.volume_db = SILENCE_DB
				_active_music_player = null
			current_music_name = &""


func _linear_to_db_safe(linear_val: float) -> float:
	if linear_val <= 0.0001:
		return SILENCE_DB
	return linear_to_db(linear_val)


func _db_to_linear_safe(db_val: float) -> float:
	if db_val <= SILENCE_DB:
		return 0.0
	return db_to_linear(db_val)


# ─────────────────────────────────────────────────────────────
# Public Audio API
# ─────────────────────────────────────────────────────────────

## เล่นเสียง SFX: หาก position == Vector2.INF จะเล่นแบบ 2D=false (AudioStreamPlayer)
## หากระบุ position จะเล่นผ่าน AudioStreamPlayer2D ตามตำแหน่ง
func play_sfx(sfx_name: StringName, position: Vector2 = Vector2.INF) -> void:
	var stream: AudioStream = get_sfx_stream(sfx_name)
	if stream == null:
		return

	# ตรวจสอบขีดจำกัดเสียงซ้อน (polyphony limit)
	var active_count: int = _sfx_active_counts.get(sfx_name, 0)
	if active_count >= max_polyphony_per_sfx:
		return

	var pitch: float = 1.0 + randf_range(-pitch_randomness, pitch_randomness)
	_sfx_play_counter += 1

	if position == Vector2.INF:
		var player: AudioStreamPlayer = _acquire_sfx_player()
		if player == null:
			return
		_sfx_active_counts[sfx_name] = active_count + 1
		player.stream = stream
		player.pitch_scale = pitch
		player.bus = &"SFX"
		player.set_meta(&"sfx_name", sfx_name)
		player.set_meta(&"busy", true)
		player.set_meta(&"play_order", _sfx_play_counter)
		if player.is_inside_tree():
			player.play()
	else:
		var player_2d: AudioStreamPlayer2D = _acquire_sfx_2d_player()
		if player_2d == null:
			return
		_sfx_active_counts[sfx_name] = active_count + 1
		player_2d.stream = stream
		player_2d.pitch_scale = pitch
		player_2d.bus = &"SFX"
		player_2d.max_distance = sfx_max_distance
		player_2d.position = position
		player_2d.set_meta(&"sfx_name", sfx_name)
		player_2d.set_meta(&"busy", true)
		player_2d.set_meta(&"play_order", _sfx_play_counter)
		if player_2d.is_inside_tree():
			player_2d.play()


## เล่นหรือ crossfade เพลงตามชื่อ หาก fade < 0 จะใช้ค่า music_crossfade_duration
func play_music(music_name: StringName, fade: float = -1.0) -> void:
	if music_name == current_music_name and not _is_fading_out:
		return

	var stream: AudioStream = get_music_stream(music_name)
	if stream == null:
		return

	var duration: float = music_crossfade_duration if fade < 0.0 else fade

	# ถ้าเพลงเดิมกำลัง fade out ให้ reverse fade กลับขึ้นมาจากระดับเสียงปัจจุบัน
	if music_name == current_music_name and _is_fading_out:
		var resume_player: AudioStreamPlayer = null
		var resume_lin: float = 0.0
		for i in range(_fading_entries.size() - 1, -1, -1):
			var entry: Dictionary = _fading_entries[i]
			if entry["player"].stream == stream:
				resume_player = entry["player"]
				resume_lin = _db_to_linear_safe(resume_player.volume_db)
				_fading_entries.remove_at(i)
				break
		if resume_player != null:
			_active_music_player = resume_player
			_fade_start_active_linear = resume_lin
			if duration <= 0.0:
				_is_fading_out = false
				_is_crossfading = false
				_active_music_player.volume_db = DEFAULT_MUSIC_VOLUME_DB
				if _active_music_player.is_inside_tree():
					_active_music_player.play()
			else:
				_is_fading_out = false
				_is_crossfading = true
				_fade_timer = 0.0
				_fade_duration = duration
			return

	# เปลี่ยนเพลง: active player ปัจจุบันย้ายเข้า _fading_entries โดยจำระดับเสียงปัจจุบันไว้
	if _active_music_player != null:
		var act_lin: float = _db_to_linear_safe(_active_music_player.volume_db)
		if act_lin > 0.0001:
			_fading_entries.append({ "player": _active_music_player, "start_linear": act_lin })
		else:
			if _active_music_player.is_inside_tree():
				_active_music_player.stop()
			_active_music_player.volume_db = SILENCE_DB
		_active_music_player = null

	# อัปเดต start_linear ของทุก player ที่กำลัง fade อยู่ ให้เริ่ม fade ลงจากระดับเสียงปัจจุบัน ไม่เด้งกลับ 0 dB
	for entry: Dictionary in _fading_entries:
		var p: AudioStreamPlayer = entry["player"]
		entry["start_linear"] = _db_to_linear_safe(p.volume_db)

	# เลือกหรือสร้าง music player ใหม่ที่ไม่ติด fading อยู่ เพื่อไม่ตัดเสียง player ที่เล่นค้าง
	var incoming_player: AudioStreamPlayer = _acquire_music_player()
	_active_music_player = incoming_player
	_fade_start_active_linear = 0.0
	current_music_name = music_name

	incoming_player.stream = stream
	incoming_player.bus = &"Music"

	if not _fading_entries.is_empty():
		_fading_music_player = _fading_entries[-1]["player"]

	if duration <= 0.0:
		_is_crossfading = false
		_is_fading_out = false
		for entry: Dictionary in _fading_entries:
			var p: AudioStreamPlayer = entry["player"]
			if p.is_inside_tree():
				p.stop()
			p.volume_db = SILENCE_DB
		_fading_entries.clear()
		_fading_music_player = null
		incoming_player.volume_db = DEFAULT_MUSIC_VOLUME_DB
		if incoming_player.is_inside_tree():
			incoming_player.play()
	else:
		_is_crossfading = true
		_is_fading_out = false
		_fade_timer = 0.0
		_fade_duration = duration
		incoming_player.volume_db = SILENCE_DB
		if incoming_player.is_inside_tree():
			incoming_player.play()


## ค่อย ๆ ลดเสียงเพลงจนเงียบ (fade out) ทั้ง active และ fading player
func stop_music(fade: float = -1.0) -> void:
	if current_music_name.is_empty() and not _is_crossfading and _fading_entries.is_empty():
		return

	var duration: float = music_crossfade_duration if fade < 0.0 else fade
	if duration <= 0.0:
		_is_crossfading = false
		_is_fading_out = false
		if _active_music_player != null:
			if _active_music_player.is_inside_tree():
				_active_music_player.stop()
			_active_music_player.volume_db = SILENCE_DB
			_active_music_player = null
		for entry: Dictionary in _fading_entries:
			var p: AudioStreamPlayer = entry["player"]
			if p.is_inside_tree():
				p.stop()
			p.volume_db = SILENCE_DB
		_fading_entries.clear()
		_fading_music_player = null
		current_music_name = &""
	else:
		_is_crossfading = false
		_is_fading_out = true
		_fade_timer = 0.0
		_fade_duration = duration

		if _active_music_player != null:
			var act_lin: float = _db_to_linear_safe(_active_music_player.volume_db)
			if act_lin > 0.0001:
				_fading_entries.append({ "player": _active_music_player, "start_linear": act_lin })
			else:
				if _active_music_player.is_inside_tree():
					_active_music_player.stop()
				_active_music_player.volume_db = SILENCE_DB
			_active_music_player = null

		for entry: Dictionary in _fading_entries:
			var p: AudioStreamPlayer = entry["player"]
			entry["start_linear"] = _db_to_linear_safe(p.volume_db)

		if not _fading_entries.is_empty():
			_fading_music_player = _fading_entries[-1]["player"]

		current_music_name = &""


# ─────────────────────────────────────────────────────────────
# Audio Stream Retrieval & Caching
# ─────────────────────────────────────────────────────────────

func get_sfx_stream(sfx_name: StringName) -> AudioStream:
	if _sfx_cache.has(sfx_name):
		return _sfx_cache[sfx_name]

	if not SFX_PATHS.has(sfx_name):
		return null

	var path: String = SFX_PATHS[sfx_name]
	var stream: AudioStream = load(path) as AudioStream
	if stream != null:
		_sfx_cache[sfx_name] = stream
	return stream


func get_music_stream(music_name: StringName) -> AudioStream:
	if _music_cache.has(music_name):
		return _music_cache[music_name]

	if not MUSIC_PATHS.has(music_name):
		return null

	var path: String = MUSIC_PATHS[music_name]
	var stream: AudioStream = load(path) as AudioStream
	if stream != null:
		_music_cache[music_name] = stream
	return stream


# ─────────────────────────────────────────────────────────────
# Pooling & Acquisition Implementation
# ─────────────────────────────────────────────────────────────

func _acquire_music_player() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _music_players:
		if p != _active_music_player and not _is_player_fading(p):
			return p

	var new_player := AudioStreamPlayer.new()
	new_player.name = "MusicPlayer_%d" % _music_players.size()
	new_player.bus = &"Music"
	new_player.volume_db = SILENCE_DB
	add_child(new_player)
	_music_players.append(new_player)
	return new_player


func _is_player_fading(player: AudioStreamPlayer) -> bool:
	for entry: Dictionary in _fading_entries:
		if entry["player"] == player:
			return true
	return false


func _is_player_busy(player: Node) -> bool:
	if player.is_inside_tree():
		if player is AudioStreamPlayer:
			return (player as AudioStreamPlayer).playing
		elif player is AudioStreamPlayer2D:
			return (player as AudioStreamPlayer2D).playing
	return bool(player.get_meta(&"busy", false))


func _acquire_sfx_player() -> AudioStreamPlayer:
	# ค้นหา player ใน pool ที่หยุดเล่นแล้ว
	for player: AudioStreamPlayer in _sfx_pool:
		if not _is_player_busy(player):
			return player

	# หากไม่มีและยังไม่เกิน limit ให้สร้างใหม่
	if _sfx_pool.size() < max_sfx_players:
		var new_player := AudioStreamPlayer.new()
		new_player.bus = &"SFX"
		new_player.finished.connect(_on_sfx_player_finished.bind(new_player))
		add_child(new_player)
		_sfx_pool.append(new_player)
		return new_player

	# หากเต็ม limit แล้ว ให้แย่งตัวที่เล่นมานานที่สุดจริง (play_order ต่ำสุด)
	if not _sfx_pool.is_empty():
		var oldest: AudioStreamPlayer = _sfx_pool[0]
		var oldest_order: int = int(oldest.get_meta(&"play_order", 0))
		for p: AudioStreamPlayer in _sfx_pool:
			var order: int = int(p.get_meta(&"play_order", 0))
			if order < oldest_order:
				oldest = p
				oldest_order = order
		_return_sfx_polyphony(oldest)
		oldest.set_meta(&"busy", false)
		if oldest.is_inside_tree():
			oldest.stop()
		return oldest

	return null


func _acquire_sfx_2d_player() -> AudioStreamPlayer2D:
	for player: AudioStreamPlayer2D in _sfx_2d_pool:
		if not _is_player_busy(player):
			return player

	if _sfx_2d_pool.size() < max_sfx_2d_players:
		var new_player := AudioStreamPlayer2D.new()
		new_player.bus = &"SFX"
		new_player.finished.connect(_on_sfx_2d_player_finished.bind(new_player))
		add_child(new_player)
		_sfx_2d_pool.append(new_player)
		return new_player

	# หากเต็ม limit แล้ว ให้แย่งตัวที่เล่นมานานที่สุดจริง (play_order ต่ำสุด)
	if not _sfx_2d_pool.is_empty():
		var oldest: AudioStreamPlayer2D = _sfx_2d_pool[0]
		var oldest_order: int = int(oldest.get_meta(&"play_order", 0))
		for p: AudioStreamPlayer2D in _sfx_2d_pool:
			var order: int = int(p.get_meta(&"play_order", 0))
			if order < oldest_order:
				oldest = p
				oldest_order = order
		_return_sfx_2d_polyphony(oldest)
		oldest.set_meta(&"busy", false)
		if oldest.is_inside_tree():
			oldest.stop()
		return oldest

	return null


func _on_sfx_player_finished(player: AudioStreamPlayer) -> void:
	player.set_meta(&"busy", false)
	_return_sfx_polyphony(player)


func _on_sfx_2d_player_finished(player: AudioStreamPlayer2D) -> void:
	player.set_meta(&"busy", false)
	_return_sfx_2d_polyphony(player)


func _return_sfx_polyphony(player: AudioStreamPlayer) -> void:
	if player.has_meta(&"sfx_name"):
		var s_name: StringName = player.get_meta(&"sfx_name")
		var count: int = _sfx_active_counts.get(s_name, 0)
		if count > 0:
			_sfx_active_counts[s_name] = count - 1
		player.remove_meta(&"sfx_name")


func _return_sfx_2d_polyphony(player: AudioStreamPlayer2D) -> void:
	if player.has_meta(&"sfx_name"):
		var s_name: StringName = player.get_meta(&"sfx_name")
		var count: int = _sfx_active_counts.get(s_name, 0)
		if count > 0:
			_sfx_active_counts[s_name] = count - 1
		player.remove_meta(&"sfx_name")


## คืนขนาด pool ปัจจุบันสำหรับเทสต์
func get_sfx_pool_size() -> int:
	return _sfx_pool.size()


## คืนขนาด pool 2D ปัจจุบันสำหรับเทสต์
func get_sfx_2d_pool_size() -> int:
	return _sfx_2d_pool.size()


# ─────────────────────────────────────────────────────────────
# Static Selection Logic (Testable & Separated)
# ─────────────────────────────────────────────────────────────

## เลือกเสียงสำหรับ damage_dealt: หาก target อยู่ใน group "player" คืน &"hit_player" ไม่งั้น &"hit_flesh"
static func select_sfx_for_damage(target: Node) -> StringName:
	if target != null and is_instance_valid(target) and target.is_in_group(&"player"):
		return &"hit_player"
	return &"hit_flesh"


## เลือกเสียงสำหรับ attack_deflected
static func select_sfx_for_attack_deflected() -> StringName:
	return &"parry"


## เลือกเสียงสำหรับ enemy_died
static func select_sfx_for_enemy_died() -> StringName:
	return &"enemy_die"


## เลือกเสียงสำหรับ boss_engaged
static func select_sfx_for_boss_engaged() -> StringName:
	return &"boss_roar"


## เลือกเพลงสำหรับ boss_engaged
static func select_music_for_boss_engaged() -> StringName:
	return &"music_combat"


## เลือกเพลงสำหรับ room_started
static func select_music_for_room_started() -> StringName:
	return &"music_combat"


## เลือกเพลงสำหรับ room_cleared
static func select_music_for_room_cleared() -> StringName:
	return &"music_explore"


## เลือกเสียงสำหรับ room_cleared
static func select_sfx_for_room_cleared() -> StringName:
	return &"door_open"


## เลือกเสียงสำหรับ screen_shake_requested (strength >= 0.4 คืน &"thud" ไม่งั้น &"")
static func select_sfx_for_screen_shake(strength: float) -> StringName:
	if strength >= 0.4:
		return &"thud"
	return &""


# ─────────────────────────────────────────────────────────────
# EventBus Callbacks
# ─────────────────────────────────────────────────────────────

func _on_damage_dealt(target: Node, _info: DamageInfo, _final_amount: int) -> void:
	var sfx: StringName = select_sfx_for_damage(target)
	var pos: Vector2 = Vector2.INF
	if target is Node2D:
		pos = (target as Node2D).global_position
	play_sfx(sfx, pos)


func _on_attack_deflected(defender: Node, _info: DamageInfo) -> void:
	var pos: Vector2 = Vector2.INF
	if defender is Node2D:
		pos = (defender as Node2D).global_position
	play_sfx(select_sfx_for_attack_deflected(), pos)


func _on_enemy_died(_enemy: Node, _enemy_id: StringName, position: Vector2) -> void:
	play_sfx(select_sfx_for_enemy_died(), position)


func _on_player_died() -> void:
	stop_music()


func _on_player_respawn_requested(_position: Vector2) -> void:
	if not autoplay_music.is_empty():
		play_music(autoplay_music)


func _on_boss_engaged(boss: Node, _health: Health, _display_name: String) -> void:
	var pos: Vector2 = Vector2.INF
	if boss is Node2D:
		pos = (boss as Node2D).global_position
	play_sfx(select_sfx_for_boss_engaged(), pos)
	play_music(select_music_for_boss_engaged())


func _on_room_started(_room: Node, _room_rect: Rect2) -> void:
	play_music(select_music_for_room_started())


func _on_room_cleared(_room: Node) -> void:
	play_music(select_music_for_room_cleared())
	play_sfx(select_sfx_for_room_cleared())


func _on_screen_shake_requested(strength: float, position: Vector2) -> void:
	var sfx: StringName = select_sfx_for_screen_shake(strength)
	if not sfx.is_empty():
		var pos: Vector2 = position if (position != Vector2.ZERO and position != Vector2.INF) else Vector2.INF
		play_sfx(sfx, pos)
