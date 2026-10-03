extends Node2D
## Audio Sandbox — ทดสอบระบบเสียง (ระบบเสียง เฟส 6 Issue #60)
## รองรับการกดปุ่มบนจอ และปุ่มคีย์บอร์ด 0–9, Q–R สำหรับ SFX, A–L สำหรับ EventBus, Z–C สำหรับเพลง
## รองรับ --shot=<path> เพื่อบันทึกภาพหน้าจอ

@onready var director: AudioDirector = $AudioDirector
@onready var status_label: Label = $CanvasLayer/Panel/MarginContainer/VBox/StatusLabel

var _dummy_player: Node2D = null
var _dummy_enemy: Node2D = null
var _dummy_boss: Node2D = null
var _last_action_text: String = "พร้อมทดสอบ (กดปุ่มหรือคลิกปุ่มบนหน้าจอ)"


func _ready() -> void:
	_create_dummies()
	if director != null:
		director.setup()

	_connect_ui_buttons()
	_update_status()

	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shoot(arg.trim_prefix("--shot="))


func _create_dummies() -> void:
	_dummy_player = Node2D.new()
	_dummy_player.name = "DummyPlayer"
	_dummy_player.add_to_group(&"player")
	add_child(_dummy_player)

	_dummy_enemy = Node2D.new()
	_dummy_enemy.name = "DummyEnemy"
	_dummy_enemy.add_to_group(&"enemies")
	add_child(_dummy_enemy)

	_dummy_boss = Node2D.new()
	_dummy_boss.name = "DummyBoss"
	var health := Health.new()
	health.name = "Health"
	_dummy_boss.add_child(health)
	add_child(_dummy_boss)


func _connect_ui_buttons() -> void:
	var container: GridContainer = $CanvasLayer/Panel/MarginContainer/VBox/GridContainer
	for child: Node in container.get_children():
		if child is Button:
			var btn: Button = child as Button
			var action_id: String = btn.name
			btn.pressed.connect(_on_button_pressed.bind(action_id))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return

	var key_event := event as InputEventKey
	match key_event.physical_keycode:
		KEY_1:
			_trigger_sfx(&"slash")
		KEY_2:
			_trigger_sfx(&"hit_flesh")
		KEY_3:
			_trigger_sfx(&"hit_player")
		KEY_4:
			_trigger_sfx(&"parry")
		KEY_5:
			_trigger_sfx(&"dodge")
		KEY_6:
			_trigger_sfx(&"enemy_die")
		KEY_7:
			_trigger_sfx(&"boss_roar")
		KEY_8:
			_trigger_sfx(&"door_open")
		KEY_9:
			_trigger_sfx(&"door_close")
		KEY_0:
			_trigger_sfx(&"heal")
		KEY_Q:
			_trigger_sfx(&"shard_pickup")
		KEY_W:
			_trigger_sfx(&"ui_move")
		KEY_E:
			_trigger_sfx(&"ui_confirm")
		KEY_R:
			_trigger_sfx(&"thud")
		KEY_A:
			_emit_damage_flesh()
		KEY_S:
			_emit_damage_player()
		KEY_D:
			_emit_parry()
		KEY_F:
			_emit_enemy_died()
		KEY_G:
			_emit_screen_shake()
		KEY_H:
			_emit_boss_engaged()
		KEY_J:
			_emit_room_started()
		KEY_K:
			_emit_room_cleared()
		KEY_L:
			_emit_player_died()
		KEY_Z:
			_play_music(&"music_explore")
		KEY_X:
			_play_music(&"music_combat")
		KEY_C:
			_stop_music()


func _on_button_pressed(action_id: String) -> void:
	match action_id:
		"BtnSlash": _trigger_sfx(&"slash")
		"BtnHitFlesh": _trigger_sfx(&"hit_flesh")
		"BtnHitPlayer": _trigger_sfx(&"hit_player")
		"BtnParry": _trigger_sfx(&"parry")
		"BtnDodge": _trigger_sfx(&"dodge")
		"BtnEnemyDie": _trigger_sfx(&"enemy_die")
		"BtnBossRoar": _trigger_sfx(&"boss_roar")
		"BtnDoorOpen": _trigger_sfx(&"door_open")
		"BtnDoorClose": _trigger_sfx(&"door_close")
		"BtnHeal": _trigger_sfx(&"heal")
		"BtnShard": _trigger_sfx(&"shard_pickup")
		"BtnUiMove": _trigger_sfx(&"ui_move")
		"BtnUiConfirm": _trigger_sfx(&"ui_confirm")
		"BtnThud": _trigger_sfx(&"thud")
		"BtnEmitFlesh": _emit_damage_flesh()
		"BtnEmitPlayer": _emit_damage_player()
		"BtnEmitParry": _emit_parry()
		"BtnEmitEnemyDie": _emit_enemy_died()
		"BtnEmitShake": _emit_screen_shake()
		"BtnEmitBoss": _emit_boss_engaged()
		"BtnEmitRoomStart": _emit_room_started()
		"BtnEmitRoomClear": _emit_room_cleared()
		"BtnEmitPlayerDied": _emit_player_died()
		"BtnMusicExplore": _play_music(&"music_explore")
		"BtnMusicCombat": _play_music(&"music_combat")
		"BtnMusicStop": _stop_music()


func _trigger_sfx(sfx_name: StringName) -> void:
	director.play_sfx(sfx_name)
	_last_action_text = "Play SFX: %s" % sfx_name
	_update_status()


func _play_music(music_name: StringName) -> void:
	director.play_music(music_name)
	_last_action_text = "Crossfade Music: %s" % music_name
	_update_status()


func _stop_music() -> void:
	director.stop_music()
	_last_action_text = "Stop Music (fade out)"
	_update_status()


func _emit_damage_flesh() -> void:
	var info := DamageInfo.new()
	info.amount = 10
	EventBus.damage_dealt.emit(_dummy_enemy, info, 10)
	_last_action_text = "EventBus: damage_dealt -> hit_flesh"
	_update_status()


func _emit_damage_player() -> void:
	var info := DamageInfo.new()
	info.amount = 15
	EventBus.damage_dealt.emit(_dummy_player, info, 15)
	_last_action_text = "EventBus: damage_dealt -> hit_player"
	_update_status()


func _emit_parry() -> void:
	var info := DamageInfo.new()
	EventBus.attack_deflected.emit(_dummy_player, info)
	_last_action_text = "EventBus: attack_deflected -> parry"
	_update_status()


func _emit_enemy_died() -> void:
	EventBus.enemy_died.emit(_dummy_enemy, &"slime", Vector2(100, 100))
	_last_action_text = "EventBus: enemy_died -> enemy_die"
	_update_status()


func _emit_screen_shake() -> void:
	EventBus.screen_shake_requested.emit(0.6, Vector2.ZERO)
	_last_action_text = "EventBus: screen_shake_requested(0.6) -> thud"
	_update_status()


func _emit_boss_engaged() -> void:
	var h: Health = _dummy_boss.get_node("Health") as Health
	EventBus.boss_engaged.emit(_dummy_boss, h, "Minotaur")
	_last_action_text = "EventBus: boss_engaged -> boss_roar + music_combat"
	_update_status()


func _emit_room_started() -> void:
	EventBus.room_started.emit(self, Rect2(0, 0, 960, 540))
	_last_action_text = "EventBus: room_started -> crossfade music_combat"
	_update_status()


func _emit_room_cleared() -> void:
	EventBus.room_cleared.emit(self)
	_last_action_text = "EventBus: room_cleared -> crossfade music_explore + door_open"
	_update_status()


func _emit_player_died() -> void:
	EventBus.player_died.emit()
	_last_action_text = "EventBus: player_died -> fade out music"
	_update_status()


func _update_status() -> void:
	if status_label == null:
		return
	var cur_music: String = str(director.current_music_name) if director != null else "none"
	if cur_music.is_empty():
		cur_music = "(none)"
	status_label.text = "สถานะ: %s\nเพลงปัจจุบัน: %s | Pool: SFX=%d, 2D=%d" % [
		_last_action_text,
		cur_music,
		director.get_sfx_pool_size() if director else 0,
		director.get_sfx_2d_pool_size() if director else 0
	]


func _shoot(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	var tex: ViewportTexture = get_viewport().get_texture()
	if tex != null:
		var img: Image = tex.get_image()
		if img != null:
			img.save_png(path)
	get_tree().quit()
