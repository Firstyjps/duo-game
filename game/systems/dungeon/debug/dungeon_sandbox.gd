extends Node2D
## ฉากทดสอบระบบดันเจี้ยน isometric (ห้อง 1 -> ห้อง 2 -> ห้อง 3)
## ต่อกับ Player จริง และ GameCamera ผ่าน EventBus (contract #52)

@onready var dungeon: Dungeon = $Dungeon
@onready var player: Player = $Player
@onready var camera: GameCamera = $GameCamera
@onready var info_label: Label = $CanvasLayer/HUD/InfoLabel
@onready var status_label: Label = $CanvasLayer/HUD/StatusLabel


func _ready() -> void:
	Player.ensure_input_actions()
	
	if dungeon != null:
		dungeon.setup()
		dungeon.room_changed.connect(_on_room_changed)
		dungeon.dungeon_reset.connect(_on_dungeon_reset)
		dungeon.dungeon_completed.connect(_on_dungeon_completed)
		dungeon.run_completed.connect(_on_dungeon_completed)
		
		for r: Room in dungeon.rooms:
			r.room_started.connect(_on_room_state_changed)
			r.room_cleared.connect(_on_room_state_changed)
	
	if player != null and dungeon != null and not dungeon.rooms.is_empty():
		var sp: Marker2D = dungeon.rooms[0].player_spawn_point
		if sp != null:
			player.global_position = sp.global_position
	
	if camera != null and player != null:
		camera.target = player
		if dungeon != null and not dungeon.rooms.is_empty():
			camera.set_bounds(dungeon.rooms[0].get_room_rect())
			camera.snap_to_target()
	
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.room_started.connect(_on_event_bus_room_started)
	
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shoot(arg.trim_prefix("--shot="))
	
	_update_hud()


func _exit_tree() -> void:
	if EventBus != null and is_instance_valid(EventBus) and EventBus.room_started.is_connected(_on_event_bus_room_started):
		EventBus.room_started.disconnect(_on_event_bus_room_started)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if EventBus != null and is_instance_valid(EventBus) and EventBus.room_started.is_connected(_on_event_bus_room_started):
			EventBus.room_started.disconnect(_on_event_bus_room_started)


func _process(_delta: float) -> void:
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	
	var key_event: InputEventKey = event as InputEventKey
	match key_event.keycode:
		KEY_R:
			if dungeon != null:
				dungeon.reset_dungeon()
				if player != null and not dungeon.rooms.is_empty():
					player.revive(dungeon.rooms[0].player_spawn_point.global_position)
				_update_hud()
		KEY_1:
			if player != null and dungeon != null and dungeon.rooms.size() > 0:
				player.global_position = dungeon.rooms[0].player_spawn_point.global_position
				_update_hud()
		KEY_2:
			if player != null and dungeon != null and dungeon.rooms.size() > 1:
				player.global_position = dungeon.rooms[1].player_spawn_point.global_position
				_update_hud()
		KEY_3:
			if player != null and dungeon != null and dungeon.rooms.size() > 2:
				player.global_position = dungeon.rooms[2].player_spawn_point.global_position
				_update_hud()
		KEY_K:
			# Debug: กำจัดศัตรูในห้องปัจจุบันทันทีเพื่อทดสอบประตูเปิด (ทำดาเมจอย่างเดียว ไม่ emit เอง)
			var current: Room = dungeon.get_current_room() if dungeon != null else null
			if current != null and current.state == Room.State.LOCKED:
				var enemies_to_kill: Array[Node] = current.spawned_enemies.duplicate()
				for enemy: Node in enemies_to_kill:
					if is_instance_valid(enemy):
						if enemy.has_node("Health"):
							var h: Health = enemy.get_node("Health") as Health
							h.take_damage(999)
						else:
							enemy.queue_free()


func _update_hud() -> void:
	if dungeon == null or status_label == null:
		return
	
	var r: Room = dungeon.get_current_room()
	var r_name: String = str(r.room_id) if r != null else "None"
	var r_state: String = "IDLE"
	var remaining: int = 0
	if r != null:
		match r.state:
			Room.State.IDLE: r_state = "IDLE (ก้าวเข้าไปเพื่อเริ่ม)"
			Room.State.LOCKED: r_state = "LOCKED (กำจัดศัตรูทั้งหมด)"
			Room.State.CLEARED: r_state = "CLEARED (ประตูเปิดแล้ว เดินผ่านไปห้องถัดไป)"
		remaining = r.get_remaining_enemies_count()
	
	var p_hp: int = player.health.hp if player != null and player.health != null else 0
	var p_stam: int = int(player.stamina) if player != null else 0
	
	status_label.text = "ห้อง: %d/3 (%s) | สถานะ: %s | ศัตรูเหลือ: %d ตัว\nPlayer HP: %d/12 | Stamina: %d/100" % [
		dungeon.current_room_index + 1,
		r_name,
		r_state,
		remaining,
		p_hp,
		p_stam
	]


func _on_event_bus_room_started(_room: Node, _room_rect: Rect2) -> void:
	_update_hud()


func _on_room_changed(prev_idx: int, new_idx: int, new_room: Room) -> void:
	print("Room changed from %d to %d (%s)" % [prev_idx, new_idx, new_room.room_id])
	_update_hud()


func _on_room_state_changed(_room: Room) -> void:
	_update_hud()


func _on_dungeon_reset() -> void:
	print("Dungeon reset to Room 1")
	_update_hud()


func _on_dungeon_completed() -> void:
	print("Dungeon completed!")
	_update_hud()


func _shoot(path: String) -> void:
	if path.contains("overview") or path.contains("wide"):
		if camera != null:
			camera.bounds = Rect2()
			camera.position = Vector2(480, 360)
			camera.zoom = Vector2(0.48, 0.48)
	await get_tree().create_timer(1.0).timeout
	var tex: ViewportTexture = get_viewport().get_texture()
	if tex != null:
		var img: Image = tex.get_image()
		if img != null:
			img.save_png(path)
			print("Saved screenshot to ", path)
	get_tree().quit()
