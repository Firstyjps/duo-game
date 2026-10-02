class_name GameHud
extends CanvasLayer
## HUD หลักของเกม (ระบบ A) — layer 10
## จัดการหลอด HP/stamina ของผู้เล่น, หลอด HP บอส, ตัวเลขดาเมจลอยบนจอ, และเป้า lock-on
## ออกแบบ layout ให้ anchor ขอบจอตาม base resolution 960x540 (aspect: expand)

class DamageItem extends RefCounted:
	var label: Label
	var world_pos: Vector2
	var elapsed: float = 0.0


class LockMarkerControl extends Control:
	var marker_color: Color = Color(1.0, 0.82, 0.2)
	var marker_size: float = 6.0

	func _draw() -> void:
		var s: float = marker_size
		var points := PackedVector2Array([
			Vector2(-s, -s * 1.6),
			Vector2(s, -s * 1.6),
			Vector2(0.0, 0.0)
		])
		var colors := PackedColorArray([marker_color, marker_color, marker_color])
		draw_polygon(points, colors)
		var outline := PackedVector2Array([
			Vector2(-s, -s * 1.6),
			Vector2(s, -s * 1.6),
			Vector2(0.0, 0.0),
			Vector2(-s, -s * 1.6)
		])
		draw_polyline(outline, Color(0.0, 0.0, 0.0, 0.85), 1.0)


@export_group("Layout")
@export var player_box_offset: Vector2 = Vector2(16.0, -42.0)
@export var boss_box_offset: Vector2 = Vector2(0.0, 14.0)

@export_group("Player Bars")
@export var hp_color: Color = Color(0.85, 0.2, 0.22)
@export var stamina_color: Color = Color(0.35, 0.85, 0.4)
@export var stamina_empty_flash_color: Color = Color(1.0, 0.25, 0.2)
@export var stamina_flash_in_duration: float = 0.05
@export var stamina_flash_out_duration: float = 0.3
@export var bar_bg_color: Color = Color(0.06, 0.06, 0.08, 0.85)
@export var bar_border_color: Color = Color(0.0, 0.0, 0.0, 1.0)
@export var hp_bar_size: Vector2 = Vector2(160.0, 10.0)
@export var stamina_bar_size: Vector2 = Vector2(160.0, 6.0)

@export_group("Boss Bar")
@export var boss_bar_color: Color = Color(0.95, 0.5, 0.15)
@export var boss_bar_size: Vector2 = Vector2(420.0, 8.0)
@export var boss_name_color: Color = Color(1.0, 0.88, 0.65)
@export var boss_name_font_size: int = 12
@export var boss_name_outline_size: int = 3
@export var boss_hide_delay: float = 1.5

@export_group("Damage Numbers")
@export var damage_player_color: Color = Color(1.0, 0.35, 0.3)
@export var damage_enemy_color: Color = Color(1.0, 0.95, 0.75)
@export var damage_crit_color: Color = Color(1.0, 0.85, 0.2)
@export var damage_font_size: int = 12
@export var damage_crit_font_size: int = 18
@export var damage_outline_size: int = 3
@export var damage_float_distance: float = 24.0
@export var damage_duration: float = 0.7
@export var damage_fade_delay: float = 0.3
@export var damage_offset: Vector2 = Vector2(0.0, -24.0)
@export var damage_jitter: Vector2 = Vector2(6.0, 4.0)

@export_group("Lock-On Marker")
@export var lock_marker_color: Color = Color(1.0, 0.82, 0.2)
@export var lock_marker_size: float = 6.0
@export var lock_marker_offset: Vector2 = Vector2(0.0, -32.0)

var root: Control
var player_box: Control
var hp_bar: ProgressBar
var stamina_bar: ProgressBar
var boss_box: Control
var boss_name: Label
var boss_bar: ProgressBar
var damage_container: Control
var lock_marker: Control

var _stamina_fill_style: StyleBoxFlat
var _stamina_tween: Tween
var _boss_hide_tween: Tween

var _player_health: Health = null
var _player_stamina_source: Object = null
var _boss_health: Health = null
var _lock_source: Object = null
var _lock_target: Node2D = null

var _is_setup: bool = false
var _damage_items: Array[DamageItem] = []

## สำหรับ override ในการทดสอบ หรือใช้ค่าจริงจาก Viewport
var canvas_transform_override: Transform2D = Transform2D()


func _enter_tree() -> void:
	if not _is_setup:
		setup()
	_connect_event_bus()


func _exit_tree() -> void:
	_disconnect_event_bus()


func _ready() -> void:
	setup()


func _process(delta: float) -> void:
	tick(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_event_bus()
		_cleanup_bindings()


## ผูก node และ signal — แยกออกมาให้เทสต์เรียกได้โดยไม่ต้องอยู่ใน scene tree
func setup() -> void:
	if _is_setup:
		return
	_is_setup = true
	layer = 10

	# Root full rect control
	root = get_node_or_null("Root") as Control
	if root == null:
		root = Control.new()
		root.name = "Root"
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(root)

	# กล่องหลอดเลือด/stamina ผู้เล่น (anchor ซ้ายล่าง)
	player_box = root.get_node_or_null("PlayerBox") as Control
	if player_box == null:
		var vb := VBoxContainer.new()
		vb.name = "PlayerBox"
		vb.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		vb.grow_vertical = Control.GROW_DIRECTION_BEGIN
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override(&"separation", 4)
		root.add_child(vb)
		player_box = vb

	player_box.offset_left = player_box_offset.x
	player_box.offset_top = player_box_offset.y
	player_box.offset_right = player_box_offset.x + hp_bar_size.x
	player_box.offset_bottom = player_box_offset.y + 26.0

	hp_bar = player_box.get_node_or_null("HpBar") as ProgressBar
	if hp_bar == null:
		hp_bar = ProgressBar.new()
		hp_bar.name = "HpBar"
		player_box.add_child(hp_bar)

	stamina_bar = player_box.get_node_or_null("StaminaBar") as ProgressBar
	if stamina_bar == null:
		stamina_bar = ProgressBar.new()
		stamina_bar.name = "StaminaBar"
		player_box.add_child(stamina_bar)

	# กล่องหลอดเลือดบอส (anchor กลางบน)
	boss_box = root.get_node_or_null("BossBox") as Control
	if boss_box == null:
		var bvb := VBoxContainer.new()
		bvb.name = "BossBox"
		bvb.set_anchors_preset(Control.PRESET_CENTER_TOP)
		bvb.grow_horizontal = Control.GROW_DIRECTION_BOTH
		bvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bvb.add_theme_constant_override(&"separation", 2)
		root.add_child(bvb)
		boss_box = bvb

	boss_box.offset_left = -boss_bar_size.x * 0.5 + boss_box_offset.x
	boss_box.offset_right = boss_bar_size.x * 0.5 + boss_box_offset.x
	boss_box.offset_top = boss_box_offset.y
	boss_box.offset_bottom = boss_box_offset.y + 30.0

	boss_name = boss_box.get_node_or_null("BossName") as Label
	if boss_name == null:
		boss_name = Label.new()
		boss_name.name = "BossName"
		boss_box.add_child(boss_name)

	boss_bar = boss_box.get_node_or_null("BossBar") as ProgressBar
	if boss_bar == null:
		boss_bar = ProgressBar.new()
		boss_bar.name = "BossBar"
		boss_box.add_child(boss_bar)

	# เป้า lock-on
	lock_marker = root.get_node_or_null("LockMarker") as Control
	if lock_marker == null:
		var marker := LockMarkerControl.new()
		marker.name = "LockMarker"
		marker.marker_color = lock_marker_color
		marker.marker_size = lock_marker_size
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(marker)
		lock_marker = marker
	lock_marker.visible = false

	# Damage numbers container
	damage_container = root.get_node_or_null("DamageContainer") as Control
	if damage_container == null:
		damage_container = Control.new()
		damage_container.name = "DamageContainer"
		damage_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		damage_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(damage_container)

	# ตั้งค่าหน้าตาหลอด
	_apply_bar_style(hp_bar, hp_color, hp_bar_size)
	_stamina_fill_style = _apply_bar_style(stamina_bar, stamina_color, stamina_bar_size)
	_apply_bar_style(boss_bar, boss_bar_color, boss_bar_size)

	# ตั้งค่า label บอส
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.add_theme_font_size_override(&"font_size", boss_name_font_size)
	boss_name.add_theme_color_override(&"font_color", boss_name_color)
	boss_name.add_theme_constant_override(&"outline_size", boss_name_outline_size)
	boss_name.add_theme_color_override(&"font_outline_color", Color.BLACK)
	boss_box.visible = false

	_connect_event_bus()


## อัปเดตตรรกะรายเฟรม — แยกออกมาให้เทสต์เรียกแบบ deterministic ได้
func tick(delta: float) -> void:
	if boss_box != null and boss_box.visible and not is_instance_valid(_boss_health):
		hide_boss()
	_process_damage_items(delta)
	_process_lock_marker(delta)


func _connect_event_bus() -> void:
	if EventBus == null or not is_instance_valid(EventBus):
		return
	if not EventBus.boss_engaged.is_connected(_on_boss_engaged):
		EventBus.boss_engaged.connect(_on_boss_engaged)
	if not EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.connect(_on_damage_dealt)
	if not EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.connect(_on_player_died)


func _disconnect_event_bus() -> void:
	if EventBus == null or not is_instance_valid(EventBus):
		return
	if EventBus.boss_engaged.is_connected(_on_boss_engaged):
		EventBus.boss_engaged.disconnect(_on_boss_engaged)
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)
	if EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)


## ล้างการเชื่อมต่อ bindings ทั้งหมดเมื่อ object กำลังถูกทำลาย
func cleanup() -> void:
	_disconnect_event_bus()
	_cleanup_bindings()


func _cleanup_bindings() -> void:
	if _player_health != null and is_instance_valid(_player_health):
		if _player_health.changed.is_connected(_on_player_health_changed):
			_player_health.changed.disconnect(_on_player_health_changed)
	_player_health = null

	if _player_stamina_source != null and is_instance_valid(_player_stamina_source):
		if _player_stamina_source.has_signal(&"stamina_changed") and _player_stamina_source.is_connected(&"stamina_changed", _on_player_stamina_changed):
			_player_stamina_source.disconnect(&"stamina_changed", _on_player_stamina_changed)
		if _player_stamina_source.has_signal(&"stamina_empty") and _player_stamina_source.is_connected(&"stamina_empty", _on_player_stamina_empty):
			_player_stamina_source.disconnect(&"stamina_empty", _on_player_stamina_empty)
	_player_stamina_source = null

	if _boss_health != null and is_instance_valid(_boss_health):
		if _boss_health.changed.is_connected(_on_boss_health_changed):
			_boss_health.changed.disconnect(_on_boss_health_changed)
		if _boss_health.died.is_connected(_on_boss_died):
			_boss_health.died.disconnect(_on_boss_died)
		if _boss_health.tree_exiting.is_connected(hide_boss):
			_boss_health.tree_exiting.disconnect(hide_boss)
	_boss_health = null

	if _lock_source != null and is_instance_valid(_lock_source):
		if _lock_source.has_signal(&"lock_target_changed") and _lock_source.is_connected(&"lock_target_changed", _on_lock_target_changed):
			_lock_source.disconnect(&"lock_target_changed", _on_lock_target_changed)
	_lock_source = null

	if _lock_target != null and is_instance_valid(_lock_target):
		if _lock_target.tree_exiting.is_connected(_on_lock_target_exiting):
			_lock_target.tree_exiting.disconnect(_on_lock_target_exiting)
	_lock_target = null

	if _stamina_tween != null and _stamina_tween.is_valid():
		_stamina_tween.kill()
	_stamina_tween = null

	if _boss_hide_tween != null and _boss_hide_tween.is_valid():
		_boss_hide_tween.kill()
	_boss_hide_tween = null

	_damage_items.clear()


# ── Player Binding ───────────────────────────────────────────────

## ผูก Health และ Stamina ของผู้เล่น (ใช้ duck typing + has_signal ไม่พึ่ง class Player)
func bind_player(health: Health, stamina_source: Object) -> void:
	if _player_health != null and is_instance_valid(_player_health):
		if _player_health.changed.is_connected(_on_player_health_changed):
			_player_health.changed.disconnect(_on_player_health_changed)
	_player_health = health
	if _player_health != null:
		_player_health.changed.connect(_on_player_health_changed)
		set_player_health(_player_health.hp, _player_health.max_hp)

	if _player_stamina_source != null and is_instance_valid(_player_stamina_source):
		if _player_stamina_source.has_signal(&"stamina_changed") and _player_stamina_source.is_connected(&"stamina_changed", _on_player_stamina_changed):
			_player_stamina_source.disconnect(&"stamina_changed", _on_player_stamina_changed)
		if _player_stamina_source.has_signal(&"stamina_empty") and _player_stamina_source.is_connected(&"stamina_empty", _on_player_stamina_empty):
			_player_stamina_source.disconnect(&"stamina_empty", _on_player_stamina_empty)
	_player_stamina_source = stamina_source
	if _player_stamina_source != null:
		if _player_stamina_source.has_signal(&"stamina_changed"):
			_player_stamina_source.connect(&"stamina_changed", _on_player_stamina_changed)
		if _player_stamina_source.has_signal(&"stamina_empty"):
			_player_stamina_source.connect(&"stamina_empty", _on_player_stamina_empty)

		var cur_val: Variant = _player_stamina_source.get(&"stamina")
		var max_val: Variant = _player_stamina_source.get(&"stamina_max")
		if max_val == null:
			max_val = _player_stamina_source.get(&"max_stamina")
		if max_val == null:
			max_val = _player_stamina_source.get(&"STAMINA_MAX")
		if cur_val != null and max_val != null:
			set_player_stamina(float(cur_val), float(max_val))


func set_player_health(current: int, maximum: int) -> void:
	if hp_bar != null:
		hp_bar.max_value = maximum
		hp_bar.value = current


func set_player_stamina(current: float, maximum: float) -> void:
	if stamina_bar != null:
		stamina_bar.max_value = maximum
		stamina_bar.value = current


func flash_stamina() -> void:
	if _stamina_fill_style == null:
		return
	if not is_inside_tree():
		_stamina_fill_style.bg_color = stamina_empty_flash_color
		return
	if _stamina_tween != null and _stamina_tween.is_valid():
		_stamina_tween.kill()
	_stamina_tween = create_tween()
	_stamina_tween.tween_property(_stamina_fill_style, "bg_color", stamina_empty_flash_color, stamina_flash_in_duration)
	_stamina_tween.tween_property(_stamina_fill_style, "bg_color", stamina_color, stamina_flash_out_duration)


func _on_player_health_changed(current: int, maximum: int) -> void:
	set_player_health(current, maximum)


func _on_player_stamina_changed(current: float, maximum: float) -> void:
	set_player_stamina(current, maximum)


func _on_player_stamina_empty() -> void:
	flash_stamina()


# ── Boss Bar ─────────────────────────────────────────────────────

func show_boss(display_name: String, health: Health) -> void:
	if health == null or health.hp <= 0:
		hide_boss()
		return

	if _boss_health != null and is_instance_valid(_boss_health):
		if _boss_health.changed.is_connected(_on_boss_health_changed):
			_boss_health.changed.disconnect(_on_boss_health_changed)
		if _boss_health.died.is_connected(_on_boss_died):
			_boss_health.died.disconnect(_on_boss_died)
		if _boss_health.tree_exiting.is_connected(hide_boss):
			_boss_health.tree_exiting.disconnect(hide_boss)
	if _boss_hide_tween != null and _boss_hide_tween.is_valid():
		_boss_hide_tween.kill()

	_boss_health = health
	if boss_name != null:
		boss_name.text = display_name
	if boss_bar != null and health != null:
		boss_bar.max_value = health.max_hp
		boss_bar.value = health.hp
	if boss_box != null:
		boss_box.visible = true
		boss_box.modulate.a = 1.0

	if _boss_health != null:
		_boss_health.changed.connect(_on_boss_health_changed)
		_boss_health.died.connect(_on_boss_died)
		_boss_health.tree_exiting.connect(hide_boss)


func hide_boss() -> void:
	if _boss_hide_tween != null and _boss_hide_tween.is_valid():
		_boss_hide_tween.kill()
	if boss_box != null:
		boss_box.visible = false
	if _boss_health != null and is_instance_valid(_boss_health):
		if _boss_health.changed.is_connected(_on_boss_health_changed):
			_boss_health.changed.disconnect(_on_boss_health_changed)
		if _boss_health.died.is_connected(_on_boss_died):
			_boss_health.died.disconnect(_on_boss_died)
		if _boss_health.tree_exiting.is_connected(hide_boss):
			_boss_health.tree_exiting.disconnect(hide_boss)
	_boss_health = null


func is_boss_hide_pending() -> bool:
	return _boss_hide_tween != null and _boss_hide_tween.is_valid()


func _on_boss_engaged(_boss: Node, health: Health, display_name: String) -> void:
	if health == null or health.hp <= 0:
		hide_boss()
		return
	show_boss(display_name, health)


func _on_player_died() -> void:
	hide_boss()


func _on_boss_health_changed(current: int, maximum: int) -> void:
	if boss_bar != null:
		boss_bar.max_value = maximum
		boss_bar.value = current


func _on_boss_died() -> void:
	handle_boss_died()


func handle_boss_died() -> void:
	if not is_inside_tree():
		hide_boss()
		return
	if _boss_hide_tween != null and _boss_hide_tween.is_valid():
		_boss_hide_tween.kill()
	_boss_hide_tween = create_tween()
	_boss_hide_tween.tween_interval(boss_hide_delay)
	_boss_hide_tween.tween_callback(func() -> void:
		hide_boss()
	)


# ── Lock-On Marker ───────────────────────────────────────────────

## ผูก lock source ด้วย duck typing (ต้องมี signal lock_target_changed)
func bind_lock_source(source: Object) -> void:
	if _lock_source != null and is_instance_valid(_lock_source):
		if _lock_source.has_signal(&"lock_target_changed") and _lock_source.is_connected(&"lock_target_changed", _on_lock_target_changed):
			_lock_source.disconnect(&"lock_target_changed", _on_lock_target_changed)
	_lock_source = source
	if _lock_source != null:
		if _lock_source.has_signal(&"lock_target_changed"):
			_lock_source.connect(&"lock_target_changed", _on_lock_target_changed)
		var cur_target: Variant = _lock_source.get(&"lock_target")
		if cur_target is Node2D:
			set_lock_target(cur_target as Node2D)
		else:
			set_lock_target(null)
	else:
		set_lock_target(null)


func set_lock_target(target: Node2D) -> void:
	if _lock_target != null and is_instance_valid(_lock_target):
		if _lock_target.tree_exiting.is_connected(_on_lock_target_exiting):
			_lock_target.tree_exiting.disconnect(_on_lock_target_exiting)
	_lock_target = target
	if _lock_target != null and is_instance_valid(_lock_target):
		if not _lock_target.tree_exiting.is_connected(_on_lock_target_exiting):
			_lock_target.tree_exiting.connect(_on_lock_target_exiting)
		if lock_marker != null:
			lock_marker.visible = true
			_update_lock_marker_pos()
	else:
		if lock_marker != null:
			lock_marker.visible = false


func _on_lock_target_changed(target: Node2D) -> void:
	set_lock_target(target)


func _on_lock_target_exiting() -> void:
	set_lock_target(null)


func _process_lock_marker(_delta: float) -> void:
	if _lock_target == null or not is_instance_valid(_lock_target):
		if _lock_target != null:
			set_lock_target(null)
		elif lock_marker != null and lock_marker.visible:
			lock_marker.visible = false
		return
	_update_lock_marker_pos()


func _update_lock_marker_pos() -> void:
	if lock_marker == null or _lock_target == null or not is_instance_valid(_lock_target):
		return
	var world_pos: Vector2 = _lock_target.global_position + lock_marker_offset
	var transform: Transform2D = get_effective_canvas_transform()
	lock_marker.position = transform * world_pos


# ── Damage Numbers ───────────────────────────────────────────────

func _on_damage_dealt(target: Node, info: DamageInfo, final_amount: int) -> void:
	if target == null or not is_instance_valid(target):
		return

	var world_pos: Vector2 = Vector2.ZERO
	if target is Node2D:
		world_pos = (target as Node2D).global_position
	elif target is Control:
		world_pos = (target as Control).global_position
	elif info != null and info.hit_position != Vector2.ZERO:
		world_pos = info.hit_position

	var jitter := Vector2.ZERO
	if damage_jitter != Vector2.ZERO:
		jitter = Vector2(randf_range(-damage_jitter.x, damage_jitter.x), randf_range(-damage_jitter.y, damage_jitter.y))
	var spawn_pos: Vector2 = world_pos + damage_offset + jitter

	var is_player: bool = target.is_in_group(&"player")
	var is_crit: bool = info != null and info.is_crit
	var color: Color = compute_damage_color(is_player, is_crit)
	var font_size: int = compute_damage_font_size(is_crit)
	var text: String = format_damage_text(final_amount)

	spawn_damage_number(spawn_pos, text, color, font_size)


func spawn_damage_number(spawn_world_pos: Vector2, text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_constant_override(&"outline_size", damage_outline_size)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.reset_size()

	if damage_container != null:
		damage_container.add_child(label)
	else:
		add_child(label)

	var transform: Transform2D = get_effective_canvas_transform()
	var screen_pos: Vector2 = transform * spawn_world_pos
	label.position = screen_pos - label.size * 0.5

	var item := DamageItem.new()
	item.label = label
	item.world_pos = spawn_world_pos
	item.elapsed = 0.0
	_damage_items.append(item)

	return label


func _process_damage_items(delta: float) -> void:
	var transform: Transform2D = get_effective_canvas_transform()
	var i: int = _damage_items.size() - 1
	while i >= 0:
		var item: DamageItem = _damage_items[i]
		if item == null or item.label == null or not is_instance_valid(item.label):
			_damage_items.remove_at(i)
			i -= 1
			continue

		item.elapsed += delta
		if item.elapsed >= damage_duration:
			item.label.queue_free()
			_damage_items.remove_at(i)
			i -= 1
			continue

		var progress: float = clampf(item.elapsed / maxf(damage_duration, 0.001), 0.0, 1.0)
		var ease_out: float = 1.0 - (1.0 - progress) * (1.0 - progress)
		var current_y: float = ease_out * damage_float_distance
		var current_world_pos: Vector2 = item.world_pos + Vector2(0.0, -current_y)
		var screen_pos: Vector2 = transform * current_world_pos
		item.label.position = screen_pos - item.label.size * 0.5

		if item.elapsed > damage_fade_delay:
			var fade_dur: float = maxf(damage_duration - damage_fade_delay, 0.001)
			item.label.modulate.a = clampf(1.0 - (item.elapsed - damage_fade_delay) / fade_dur, 0.0, 1.0)

		i -= 1


# ── Testable Helpers & Canvas Transform ──────────────────────────

func get_effective_canvas_transform() -> Transform2D:
	if canvas_transform_override != Transform2D():
		return canvas_transform_override
	if is_inside_tree():
		var vp: Viewport = get_viewport()
		if vp != null:
			return vp.get_canvas_transform()
	return Transform2D.IDENTITY


static func world_to_screen(world_pos: Vector2, canvas_transform: Transform2D) -> Vector2:
	return canvas_transform * world_pos


static func calculate_label_position(world_pos: Vector2, label_size: Vector2, canvas_transform: Transform2D) -> Vector2:
	return (canvas_transform * world_pos) - label_size * 0.5


static func compute_damage_color_static(is_player: bool, is_crit: bool, player_col: Color, enemy_col: Color, crit_col: Color) -> Color:
	if is_player:
		return player_col
	if is_crit:
		return crit_col
	return enemy_col


static func compute_damage_font_size_static(is_crit: bool, normal_size: int, crit_size: int) -> int:
	return crit_size if is_crit else normal_size


static func format_damage_text(amount: int) -> String:
	return str(amount)


func compute_damage_color(is_player: bool, is_crit: bool) -> Color:
	return compute_damage_color_static(is_player, is_crit, damage_player_color, damage_enemy_color, damage_crit_color)


func compute_damage_font_size(is_crit: bool) -> int:
	return compute_damage_font_size_static(is_crit, damage_font_size, damage_crit_font_size)


# ── Internal Style Helper ────────────────────────────────────────

func _apply_bar_style(bar: ProgressBar, fill_color: Color, size: Vector2) -> StyleBoxFlat:
	bar.show_percentage = false
	bar.custom_minimum_size = size
	bar.size = size

	var bg := StyleBoxFlat.new()
	bg.bg_color = bar_bg_color
	bg.border_color = bar_border_color
	bg.set_border_width_all(1)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color

	bar.add_theme_stylebox_override(&"background", bg)
	bar.add_theme_stylebox_override(&"fill", fill)
	return fill
