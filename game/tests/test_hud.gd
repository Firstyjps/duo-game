extends RefCounted
## เทสต์ระบบ HUD — game/systems/hud/ · contract: docs/contracts/damage.md

const HUD_SCENE: PackedScene = preload("res://systems/hud/hud.tscn")

class MockStamina extends RefCounted:
	signal stamina_changed(current: float, maximum: float)
	signal stamina_empty


class DummyStaminaWithProps extends RefCounted:
	var stamina: float = 45.0
	var stamina_max: float = 90.0


class MockLockSource extends RefCounted:
	signal lock_target_changed(target: Node2D)
	var lock_target: Node2D = null


func _spawn_hud() -> GameHud:
	var hud: GameHud = HUD_SCENE.instantiate()
	hud.setup()
	return hud


func test_hud_layer_and_initial_nodes() -> bool:
	var hud: GameHud = _spawn_hud()
	var ok: bool = hud.layer == 10 \
		and hud.hp_bar != null \
		and hud.stamina_bar != null \
		and hud.boss_box != null \
		and hud.boss_bar != null \
		and hud.boss_name != null \
		and hud.damage_container != null \
		and hud.lock_marker != null \
		and not hud.boss_box.visible \
		and not hud.lock_marker.visible
	hud.free()
	return ok


func test_player_health_changed_updates_hp_bar() -> bool:
	var hud: GameHud = _spawn_hud()
	var hp := Health.new()
	hp.max_hp = 20
	hp.reset()

	hud.bind_player(hp, null)
	var init_ok: bool = hud.hp_bar.max_value == 20.0 and hud.hp_bar.value == 20.0

	hp.take_damage(6)
	var damage_ok: bool = hud.hp_bar.value == 14.0 and hud.hp_bar.max_value == 20.0

	hp.heal(3)
	var heal_ok: bool = hud.hp_bar.value == 17.0

	hp.free()
	hud.free()
	return init_ok and damage_ok and heal_ok


func test_player_stamina_changed_updates_stamina_bar() -> bool:
	var hud: GameHud = _spawn_hud()
	var st := MockStamina.new()

	hud.bind_player(null, st)
	st.stamina_changed.emit(75.0, 100.0)
	var first_ok: bool = hud.stamina_bar.value == 75.0 and hud.stamina_bar.max_value == 100.0

	st.stamina_changed.emit(10.0, 100.0)
	var second_ok: bool = hud.stamina_bar.value == 10.0 and hud.stamina_bar.max_value == 100.0

	hud.free()
	return first_ok and second_ok


func test_player_stamina_empty_flashes() -> bool:
	var hud: GameHud = _spawn_hud()
	var st := MockStamina.new()

	hud.bind_player(null, st)
	st.stamina_empty.emit()
	var ok: bool = hud._stamina_fill_style != null \
		and hud._stamina_fill_style.bg_color == hud.stamina_empty_flash_color
	hud.free()
	return ok


func test_boss_engaged_shows_bar_and_values() -> bool:
	var hud: GameHud = _spawn_hud()
	var hp := Health.new()
	hp.max_hp = 80
	hp.reset()

	EventBus.boss_engaged.emit(null, hp, "Ancient Golem")
	var engaged_ok: bool = hud.boss_box.visible \
		and hud.boss_name.text == "Ancient Golem" \
		and hud.boss_bar.max_value == 80.0 \
		and hud.boss_bar.value == 80.0

	hp.take_damage(25)
	var damage_ok: bool = hud.boss_bar.value == 55.0

	hp.free()
	hud.free()
	return engaged_ok and damage_ok


func test_boss_died_hides_boss_bar() -> bool:
	var hud: GameHud = _spawn_hud()
	var hp := Health.new()
	hp.max_hp = 40
	hp.reset()

	EventBus.boss_engaged.emit(null, hp, "Dragon")
	var was_visible: bool = hud.boss_box.visible

	hp.take_damage(40)
	# ในเทสต์นอก scene tree handle_boss_died ต้องซ่อนทันที (assert จริง)
	var hidden_ok: bool = not hud.boss_box.visible

	hp.free()
	hud.free()
	return was_visible and hidden_ok


func test_player_died_hides_boss_bar() -> bool:
	var hud: GameHud = _spawn_hud()
	var hp := Health.new()
	hp.max_hp = 50
	hp.reset()

	EventBus.boss_engaged.emit(null, hp, "Titan")
	var was_visible: bool = hud.boss_box.visible

	EventBus.player_died.emit()
	var hidden_ok: bool = not hud.boss_box.visible

	hp.free()
	hud.free()
	return was_visible and hidden_ok


func test_boss_engaged_with_null_or_zero_hp_hides_boss() -> bool:
	var hud: GameHud = _spawn_hud()
	var hp := Health.new()
	hp.max_hp = 50
	hp.reset()

	EventBus.boss_engaged.emit(null, hp, "Titan")
	var was_visible: bool = hud.boss_box.visible

	var dead_hp := Health.new()
	dead_hp.max_hp = 50
	dead_hp.hp = 0
	EventBus.boss_engaged.emit(null, dead_hp, "Dead Boss")
	var hidden_zero_hp: bool = not hud.boss_box.visible

	EventBus.boss_engaged.emit(null, hp, "Titan")
	EventBus.boss_engaged.emit(null, null, "Null Boss")
	var hidden_null: bool = not hud.boss_box.visible

	hp.free()
	dead_hp.free()
	hud.free()
	return was_visible and hidden_zero_hp and hidden_null


func test_boss_switch_disconnects_old_boss_health() -> bool:
	var hud: GameHud = _spawn_hud()
	var hp1 := Health.new()
	hp1.max_hp = 50
	hp1.reset()

	EventBus.boss_engaged.emit(null, hp1, "Boss 1")
	var hp1_ok: bool = hud.boss_bar.value == 50.0 and hud.boss_name.text == "Boss 1"

	var hp2 := Health.new()
	hp2.max_hp = 100
	hp2.reset()

	EventBus.boss_engaged.emit(null, hp2, "Boss 2")
	var hp2_ok: bool = hud.boss_bar.value == 100.0 and hud.boss_name.text == "Boss 2"

	# ลดเลือดบอสตัวเก่า หลอดต้องไม่ขยับ
	hp1.take_damage(20)
	var old_not_moving: bool = hud.boss_bar.value == 100.0 and hud.boss_bar.max_value == 100.0

	# ลดเลือดบอสตัวใหม่ หลอดต้องลด
	hp2.take_damage(15)
	var new_moving: bool = hud.boss_bar.value == 85.0

	hp1.free()
	hp2.free()
	hud.free()
	return hp1_ok and hp2_ok and old_not_moving and new_moving


func test_boss_freed_hides_boss_bar() -> bool:
	var hud: GameHud = _spawn_hud()
	var hp := Health.new()
	hp.max_hp = 60
	hp.reset()

	EventBus.boss_engaged.emit(null, hp, "Ephemeral Boss")
	var engaged_ok: bool = hud.boss_box.visible

	# 1. ทดสอบ health.tree_exiting ซ่อนหลอดบอส
	hp.tree_exiting.emit()
	var hidden_on_exiting: bool = not hud.boss_box.visible

	# 2. ทดสอบกรณีบอสโดน free() โดยไม่ตาย -> tick(0.0) ตรวจพบและซ่อนหลอดบอส
	var hp2 := Health.new()
	hp2.max_hp = 40
	hp2.reset()
	EventBus.boss_engaged.emit(null, hp2, "Ephemeral Boss 2")
	var engaged_ok2: bool = hud.boss_box.visible
	hp2.free()
	hud.tick(0.0)
	var hidden_on_free: bool = not hud.boss_box.visible

	hp.free()
	hud.free()
	return engaged_ok and hidden_on_exiting and engaged_ok2 and hidden_on_free


func test_remove_and_readd_hud_receives_damage_dealt() -> bool:
	var hud: GameHud = _spawn_hud()
	var target := Node2D.new()
	target.position = Vector2(100, 100)

	var info := DamageInfo.new()
	info.amount = 10

	# 1. ยิง damage ครั้งแรกตอน HUD เชื่อมต่ออยู่
	EventBus.damage_dealt.emit(target, info, 10)
	var first_ok: bool = hud.damage_container.get_child_count() == 1

	# 2. จำลอง HUD ออกจาก tree (_exit_tree ตัดการเชื่อมต่อ EventBus)
	hud._exit_tree()

	# ยิง damage ระหว่างอยู่นอก tree (ไม่ควรได้รับ)
	EventBus.damage_dealt.emit(target, info, 10)
	var during_exit_ok: bool = hud.damage_container.get_child_count() == 1

	# 3. จำลอง HUD กลับเข้า tree (_enter_tree เชื่อมต่อ EventBus ใหม่)
	hud._enter_tree()

	# ยิง damage อีกครั้ง (ต้องได้รับ)
	EventBus.damage_dealt.emit(target, info, 10)
	var after_readd_ok: bool = hud.damage_container.get_child_count() == 2

	hud.cleanup()
	hud.free()
	target.free()
	return first_ok and during_exit_ok and after_readd_ok


func test_bind_real_player_scene() -> bool:
	var hud: GameHud = _spawn_hud()
	var player_scene: PackedScene = load("res://systems/player/player.tscn")
	var player: Node = player_scene.instantiate()

	var health: Health = player.get_node_or_null("Health") as Health
	var has_health: bool = health != null
	if health != null:
		health.reset()

	player.stamina_max = 140.0  # ไม่ใช่ค่า default ของหลอด (100) → พิสูจน์ว่าอ่าน stamina_max จริง
	player.stamina = 140.0
	hud.bind_player(health, player)

	var hp_max_ok: bool = hud.hp_bar.max_value == 12.0 and hud.hp_bar.value == 12.0
	var stamina_max_ok: bool = hud.stamina_bar.max_value == 140.0 and hud.stamina_bar.value == 140.0

	player.free()
	hud.free()
	return has_health and hp_max_ok and stamina_max_ok


func test_damage_formatting_and_colors() -> bool:
	var p_col: Color = GameHud.compute_damage_color_static(true, false, Color.RED, Color.WHITE, Color.YELLOW)
	var e_col: Color = GameHud.compute_damage_color_static(false, false, Color.RED, Color.WHITE, Color.YELLOW)
	var crit_col: Color = GameHud.compute_damage_color_static(false, true, Color.RED, Color.WHITE, Color.YELLOW)

	var s_norm: int = GameHud.compute_damage_font_size_static(false, 12, 18)
	var s_crit: int = GameHud.compute_damage_font_size_static(true, 12, 18)
	var text: String = GameHud.format_damage_text(42)

	return p_col == Color.RED \
		and e_col == Color.WHITE \
		and crit_col == Color.YELLOW \
		and s_norm == 12 \
		and s_crit == 18 \
		and text == "42"


func test_damage_dealt_spawns_floating_label() -> bool:
	var hud: GameHud = _spawn_hud()
	var target := Node2D.new()
	target.position = Vector2(100, 200)

	var info := DamageInfo.new()
	info.amount = 25
	info.is_crit = false

	EventBus.damage_dealt.emit(target, info, 25)
	var has_label: bool = hud.damage_container.get_child_count() == 1
	var label: Label = hud.damage_container.get_child(0) as Label if has_label else null
	var label_ok: bool = label != null and label.text == "25"

	target.free()
	hud.free()
	return has_label and label_ok


func test_damage_dealt_player_color_differs_from_enemy() -> bool:
	var hud: GameHud = _spawn_hud()
	var player_target := Node2D.new()
	player_target.add_to_group(&"player")

	var enemy_target := Node2D.new()

	var info := DamageInfo.new()
	info.amount = 10

	EventBus.damage_dealt.emit(player_target, info, 10)
	EventBus.damage_dealt.emit(enemy_target, info, 10)

	var ok: bool = false
	if hud.damage_container.get_child_count() == 2:
		var p_label: Label = hud.damage_container.get_child(0) as Label
		var e_label: Label = hud.damage_container.get_child(1) as Label
		var p_col: Color = p_label.get_theme_color(&"font_color")
		var e_col: Color = e_label.get_theme_color(&"font_color")
		ok = p_col != e_col and p_col == hud.damage_player_color and e_col == hud.damage_enemy_color

	player_target.free()
	enemy_target.free()
	hud.free()
	return ok


func test_damage_dealt_crit_uses_larger_font() -> bool:
	var hud: GameHud = _spawn_hud()
	var target := Node2D.new()

	var norm_info := DamageInfo.new()
	norm_info.is_crit = false

	var crit_info := DamageInfo.new()
	crit_info.is_crit = true

	EventBus.damage_dealt.emit(target, norm_info, 10)
	EventBus.damage_dealt.emit(target, crit_info, 30)

	var ok: bool = false
	if hud.damage_container.get_child_count() == 2:
		var norm_label: Label = hud.damage_container.get_child(0) as Label
		var crit_label: Label = hud.damage_container.get_child(1) as Label
		var norm_size: int = norm_label.get_theme_font_size(&"font_size")
		var crit_size: int = crit_label.get_theme_font_size(&"font_size")
		ok = crit_size > norm_size and crit_size == hud.damage_crit_font_size and norm_size == hud.damage_font_size

	target.free()
	hud.free()
	return ok


func test_world_to_screen_transform() -> bool:
	var t := Transform2D(0.0, Vector2(2, 2), 0.0, Vector2(10, 20))
	var screen_pos: Vector2 = GameHud.world_to_screen(Vector2(5, 5), t)
	return screen_pos == Vector2(20, 30)


func test_damage_label_position_with_non_identity_canvas_transform() -> bool:
	var hud: GameHud = _spawn_hud()
	hud.damage_jitter = Vector2.ZERO

	var target := Node2D.new()
	target.position = Vector2(100.0, 200.0)

	var info := DamageInfo.new()
	info.amount = 30

	var custom_transform := Transform2D(0.0, Vector2(2.0, 2.0), 0.0, Vector2(15.0, 25.0))
	hud.canvas_transform_override = custom_transform

	EventBus.damage_dealt.emit(target, info, 30)
	var label: Label = hud.damage_container.get_child(0) as Label
	var spawned_ok: bool = label != null

	var expected_world_pos: Vector2 = target.position + hud.damage_offset
	var expected_screen_pos: Vector2 = custom_transform * expected_world_pos
	var expected_label_pos: Vector2 = expected_screen_pos - label.size * 0.5
	var initial_pos_ok: bool = label.position.is_equal_approx(expected_label_pos)

	# ทดสอบเมื่อเวลาผ่านไป (ลอยขึ้น) ใน tick
	hud.tick(0.35)
	var float_progress: float = 0.35 / hud.damage_duration
	var ease_out: float = 1.0 - (1.0 - float_progress) * (1.0 - float_progress)
	var current_y: float = ease_out * hud.damage_float_distance
	var floating_world_pos: Vector2 = expected_world_pos + Vector2(0.0, -current_y)
	var expected_floating_pos: Vector2 = (custom_transform * floating_world_pos) - label.size * 0.5
	var floating_pos_ok: bool = label.position.is_equal_approx(expected_floating_pos)

	# ทดสอบเมื่อกล้องเลื่อน (เปลี่ยน transform) ตำแหน่งต้องอัปเดตตามทันทีใน tick ถัดไป
	var shifted_transform := Transform2D(0.0, Vector2(2.0, 2.0), 0.0, Vector2(35.0, 45.0))
	hud.canvas_transform_override = shifted_transform
	hud.tick(0.0)
	var expected_shifted_pos: Vector2 = (shifted_transform * floating_world_pos) - label.size * 0.5
	var shifted_pos_ok: bool = label.position.is_equal_approx(expected_shifted_pos)

	target.free()
	hud.free()
	return spawned_ok and initial_pos_ok and floating_pos_ok and shifted_pos_ok


func test_duck_typing_stamina_source_without_signal() -> bool:
	var hud: GameHud = _spawn_hud()
	var dummy_no_props := RefCounted.new()
	hud.bind_player(null, dummy_no_props)
	var no_crash_ok: bool = hud._player_stamina_source == dummy_no_props

	var dummy_with_props := DummyStaminaWithProps.new()
	hud.bind_player(null, dummy_with_props)
	var props_ok: bool = hud.stamina_bar.value == 45.0 and hud.stamina_bar.max_value == 90.0

	hud.free()
	return no_crash_ok and props_ok


func test_lock_marker_show_hide_and_free() -> bool:
	var hud: GameHud = _spawn_hud()
	var marker_init_hidden: bool = hud.lock_marker != null and not hud.lock_marker.visible

	var source := MockLockSource.new()
	hud.bind_lock_source(source)

	var target := Node2D.new()
	target.position = Vector2(200.0, 150.0)

	source.lock_target = target
	source.lock_target_changed.emit(target)
	var marker_shown: bool = hud.lock_marker.visible
	var expected_pos: Vector2 = target.global_position + hud.lock_marker_offset
	var pos_ok: bool = hud.lock_marker.position.is_equal_approx(expected_pos)

	# 1. เปลี่ยนเป้าเป็น null -> ต้องซ่อน
	source.lock_target = null
	source.lock_target_changed.emit(null)
	var marker_hidden_on_null: bool = not hud.lock_marker.visible

	# 2. ตั้งเป้าใหม่ แล้วเป้าส่ง tree_exiting -> ต้องซ่อน
	source.lock_target = target
	source.lock_target_changed.emit(target)
	var marker_reshown: bool = hud.lock_marker.visible

	target.tree_exiting.emit()
	var marker_hidden_on_exiting: bool = not hud.lock_marker.visible

	# 3. ตั้งเป้าใหม่เป็น target2 แล้ว free target2 -> tick(0.0) -> ต้องซ่อน
	var target2 := Node2D.new()
	source.lock_target = target2
	source.lock_target_changed.emit(target2)
	var marker_reshown2: bool = hud.lock_marker.visible

	target2.free()
	hud.tick(0.0)
	var marker_hidden_on_free: bool = not hud.lock_marker.visible

	target.free()
	hud.free()
	return marker_init_hidden and marker_shown and pos_ok and marker_hidden_on_null and marker_reshown and marker_hidden_on_exiting and marker_reshown2 and marker_hidden_on_free


## ผู้เล่นตาย → เครื่องหมายเป้า lock-on หาย
func test_player_died_hides_lock_marker() -> bool:
	var hud: GameHud = (load("res://systems/hud/hud.tscn") as PackedScene).instantiate()
	hud.setup()
	var target := Node2D.new()
	hud.set_lock_target(target)
	var shown: bool = hud._lock_target == target
	hud._on_player_died()
	var hidden: bool = hud._lock_target == null
	target.free()
	hud.free()
	return shown and hidden
