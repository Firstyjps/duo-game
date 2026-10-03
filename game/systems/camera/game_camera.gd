class_name GameCamera
extends Camera2D
## กล้องของระบบ A — ติดตามเป้าหมายแบบนุ่ม (pixel snap), สั่นตาม trauma², และ hitstop
## contract: docs/contracts/damage.md · EventBus.damage_dealt

const DEFAULT_HITSTOP_SCALE: float = 0.05

@export_group("Follow")
@export var target: Node2D = null
## ความเร็ว lerp ในการตามเป้าหมาย (ยิ่งสูงยิ่งตามเร็ว, <= 0 คือ snap ทันที)
@export var follow_smooth_speed: float = 8.0
## ขอบเขตการเคลื่อนที่ของกล้อง (Rect2() = ไม่จำกัด)
@export var bounds: Rect2 = Rect2()
## เวลาเลื่อนกล้องไปห้องใหม่เมื่อได้ EventBus.room_started (0 = ตัดภาพ)
@export var room_slide_duration: float = 0.5

@export_group("Focus Target")
## เป้าหมายที่สองสำหรับจัดเฟรมแบบ lock-on (framing ระหว่าง target กับ focus_target)
@export var focus_target: Node2D = null
## น้ำหนักการให้น้ำหนักไปทาง focus_target (0.0 = อยู่ที่ผู้เล่น, 1.0 = อยู่ที่เป้าหมาย)
@export var focus_weight: float = 0.35
## ระยะขยับสูงสุดของเฟรมกล้องจากผู้เล่น (pixel)
@export var max_focus_offset: float = 64.0

@export_group("Slide")
## เกิดเมื่อ slide_to ดำเนินการจนเสร็จสิ้น
signal slide_completed

@export_group("Trauma & Shake")
## อัตราการลด trauma ต่อวินาที
@export var trauma_decay: float = 1.2
## ขนาดสั่นสูงสุด (pixel)
@export var max_shake_offset: Vector2 = Vector2(12.0, 10.0)
## trauma เมื่อตัวผู้เล่น (group "player") โดนดาเมจ
@export var trauma_on_player_hit: float = 0.5
## trauma เมื่อเป้าหมายอื่นโดนดาเมจ
@export var trauma_on_other_hit: float = 0.2

@export_group("Hitstop")
## เปิด/ปิด hitstop เมื่อเกิด damage_dealt
@export var hitstop_enabled: bool = true
## time_scale ขณะ hitstop
@export var hitstop_time_scale: float = DEFAULT_HITSTOP_SCALE
## ระยะเวลา hitstop เมื่อตัวผู้เล่นโดนดาเมจ (วินาที)
@export var hitstop_player_hit_duration: float = 0.08
## ระยะเวลา hitstop เมื่อเป้าหมายอื่นโดนดาเมจ (วินาที)
@export var hitstop_other_hit_duration: float = 0.05

var trauma: float = 0.0
var _internal_pos: Vector2 = Vector2.ZERO
var _is_sliding: bool = false
var _slide_start_pos: Vector2 = Vector2.ZERO
var _slide_target_pos: Vector2 = Vector2.ZERO
var _slide_target_rect: Rect2 = Rect2()
var _slide_duration: float = 0.0
var _slide_elapsed: float = 0.0

static var _hitstop_count: int = 0


func _enter_tree() -> void:
	_connect_bus()


func _ready() -> void:
	setup()


func _exit_tree() -> void:
	_disconnect_bus()
	reset_hitstop()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_bus()


## กำหนดค่าเริ่มต้นและผูก signal — แยกจาก _ready ให้เทสต์เรียกได้โดยไม่ต้องอยู่ใน scene tree
func setup() -> void:
	_internal_pos = position
	if bounds.size != Vector2.ZERO:
		set_bounds(bounds)
	_connect_bus()


## signal ที่กล้องฟัง (contract damage · feedback · dungeon-flow) — ต่อใน _enter_tree/setup, ตัดใน _exit_tree/PREDELETE
func _bus_links() -> Array[Array]:
	return [
		[EventBus.damage_dealt, _on_damage_dealt],
		[EventBus.screen_shake_requested, _on_screen_shake_requested],
		[EventBus.room_started, _on_room_started],
		[EventBus.player_respawn_requested, _on_player_respawn_requested],
	]


func _connect_bus() -> void:
	if EventBus == null or not is_instance_valid(EventBus):
		return
	for link: Array in _bus_links():
		var sig: Signal = link[0]
		if not sig.is_connected(link[1]):
			sig.connect(link[1])


func _disconnect_bus() -> void:
	if EventBus == null or not is_instance_valid(EventBus):
		return
	for link: Array in _bus_links():
		var sig: Signal = link[0]
		if sig.is_connected(link[1]):
			sig.disconnect(link[1])


## กำหนดเป้าหมายที่กล้องจะติดตาม
func follow(new_target: Node2D, snap: bool = false) -> void:
	target = new_target
	if snap and target != null and is_instance_valid(target):
		snap_to_target()


## วาร์ปตำแหน่งกล้องไปยังเป้าหมายทันทีโดยไม่ lerp
func snap_to_target() -> void:
	if target != null and is_instance_valid(target):
		var target_pos: Vector2 = target.global_position
		if focus_target != null and is_instance_valid(focus_target):
			target_pos = compute_focus_point(target.global_position, focus_target.global_position, focus_weight, max_focus_offset)
		_internal_pos = clamp_to_bounds(target_pos, bounds)
		position = _internal_pos.round()


## กำหนดเป้าหมายโฟกัสร่วม (framing ระหว่าง target กับ focus_target) — ส่ง null เพื่อเลิก
func set_focus_target(node: Node2D) -> void:
	focus_target = node


## เริ่มเลื่อนกล้องไปยังห้องใหม่ (rect) แบบนุ่มนวล โดยระหว่างเลื่อนจะไม่ follow ผู้เล่น
## เมื่อเลื่อนถึงปลายทางแล้ว จะตั้ง set_bounds(rect)
func slide_to(rect: Rect2, duration: float) -> void:
	if duration <= 0.0:
		_is_sliding = false
		_internal_pos = rect.get_center()
		position = _internal_pos.round()
		set_bounds(rect)
		slide_completed.emit()
		return

	if _is_camera_in_tree():
		force_update_scroll()
		_slide_start_pos = (self as Variant).get_screen_center_position()
	else:
		_slide_start_pos = _internal_pos

	_internal_pos = _slide_start_pos
	_slide_target_pos = rect.get_center()
	_slide_target_rect = rect
	_slide_duration = duration
	_slide_elapsed = 0.0
	_is_sliding = true

	var union_rect: Rect2 = Rect2()
	if bounds.size != Vector2.ZERO:
		union_rect = bounds.merge(rect)
	_apply_limits(union_rect)


## คืนค่าตำแหน่งกึ่งกลางหน้าจอของกล้องใน global coordinate (คำนวณ clamp ขอบเขต limit)
@warning_ignore("native_method_override")
func get_screen_center_position() -> Vector2:
	if is_inside_tree() and get_viewport() != null:
		var sc: Vector2 = super.get_screen_center_position()
		if sc != Vector2.ZERO:
			return sc
	var min_x: float = float(limit_left)
	var max_x: float = float(limit_right)
	var min_y: float = float(limit_top)
	var max_y: float = float(limit_bottom)
	var p: Vector2 = position
	if limit_left != -10000000 and limit_right != 10000000 and max_x >= min_x:
		p.x = clampf(p.x, min_x, max_x)
	if limit_top != -10000000 and limit_bottom != 10000000 and max_y >= min_y:
		p.y = clampf(p.y, min_y, max_y)
	return p


func _is_camera_in_tree() -> bool:
	return is_inside_tree() or get_parent() != null


## คืนค่า true หากกล้องกำลังอยู่ในระหว่าง slide_to
func is_sliding() -> bool:
	return _is_sliding


## กำหนดตำแหน่งกล้องโดยตรง (คำนวณ clamp ขอบ และ round ให้)
func set_camera_position(pos: Vector2) -> void:
	_internal_pos = clamp_to_bounds(pos, bounds)
	position = _internal_pos.round()


## กำหนดขอบเขตกล้อง (Rect2)
func set_bounds(rect: Rect2) -> void:
	bounds = rect
	_apply_limits(bounds)
	_internal_pos = clamp_to_bounds(_internal_pos, bounds)
	position = _internal_pos.round()


func _apply_limits(rect: Rect2) -> void:
	if rect.size == Vector2.ZERO:
		limit_left = -10000000
		limit_top = -10000000
		limit_right = 10000000
		limit_bottom = 10000000
	else:
		limit_left = int(minf(rect.position.x, rect.end.x))
		limit_top = int(minf(rect.position.y, rect.end.y))
		limit_right = int(maxf(rect.position.x, rect.end.x))
		limit_bottom = int(maxf(rect.position.y, rect.end.y))


## เพิ่มค่า trauma สำหรับสั่น (clamp ที่ 0.0 ถึง 1.0)
func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## เรียกใช้ hitstop ตามระยะเวลาที่กำหนด (ขึ้นกับตัวเลือก hitstop_enabled)
func trigger_hitstop(seconds: float) -> SceneTreeTimer:
	if not hitstop_enabled:
		return null
	return hitstop(seconds, get_tree() if is_inside_tree() else null, hitstop_time_scale)


func _process(delta: float) -> void:
	if process_callback == Camera2DProcessCallback.CAMERA2D_PROCESS_IDLE:
		tick(delta)


func _physics_process(delta: float) -> void:
	if process_callback == Camera2DProcessCallback.CAMERA2D_PROCESS_PHYSICS:
		tick(delta)


## อัปเดตตรรกะกล้อง 1 เฟรม (follow lerp, clamp bounds, pixel round, trauma decay, shake offset) — เทสต์เรียกตรงได้
func tick(delta: float) -> void:
	if _is_sliding:
		_slide_elapsed += delta
		var t: float = clampf(_slide_elapsed / _slide_duration, 0.0, 1.0) if _slide_duration > 0.0 else 1.0
		_internal_pos = compute_slide_position(_slide_start_pos, _slide_target_pos, t)
		position = _internal_pos.round()
		if _slide_elapsed >= _slide_duration:
			_is_sliding = false
			_internal_pos = _slide_target_pos
			set_bounds(_slide_target_rect)
			position = _internal_pos.round()
			slide_completed.emit()
	else:
		var has_target: bool = target != null and is_instance_valid(target)
		var has_focus: bool = focus_target != null and is_instance_valid(focus_target)

		if has_target:
			var target_pos: Vector2 = target.global_position
			if has_focus:
				target_pos = compute_focus_point(target.global_position, focus_target.global_position, focus_weight, max_focus_offset)
			_internal_pos = compute_follow_position(_internal_pos, target_pos, follow_smooth_speed, delta)
		elif has_focus:
			_internal_pos = compute_follow_position(_internal_pos, focus_target.global_position, follow_smooth_speed, delta)

		_internal_pos = clamp_to_bounds(_internal_pos, bounds)
		position = _internal_pos.round()

	trauma = decay_trauma(trauma, trauma_decay, delta)
	offset = calculate_shake_offset(trauma, max_shake_offset).round()


# ── Static Logic ที่เทสต์ได้โดยไม่ต้องพึ่ง scene tree ──

## คำนวณตำแหน่งเลื่อนกล้องระหว่างเปลี่ยนห้อง (smooth interpolation)
static func compute_slide_position(start_pos: Vector2, end_pos: Vector2, t: float) -> Vector2:
	var clamped_t: float = clampf(t, 0.0, 1.0)
	var weight: float = smoothstep(0.0, 1.0, clamped_t)
	return start_pos.lerp(end_pos, weight)


## คำนวณ offset จุดโฟกัสระหว่างผู้เล่นกับเป้าหมาย lock-on
static func compute_focus_offset(player_pos: Vector2, target_pos: Vector2, weight: float, max_offset: float) -> Vector2:
	var diff: Vector2 = target_pos - player_pos
	var offset: Vector2 = diff * weight
	if max_offset > 0.0 and offset.length() > max_offset:
		offset = offset.limit_length(max_offset)
	return offset


## คำนวณจุดโฟกัสระหว่างผู้เล่นกับเป้าหมาย lock-on
static func compute_focus_point(player_pos: Vector2, target_pos: Vector2, weight: float, max_offset: float) -> Vector2:
	return player_pos + compute_focus_offset(player_pos, target_pos, weight, max_offset)

## คำนวณการลด trauma ตามเวลา
static func decay_trauma(current_trauma: float, decay_rate: float, delta: float) -> float:
	return maxf(0.0, current_trauma - decay_rate * delta)


## จำกัดตำแหน่งกล้องให้อยู่ในขอบเขต (ถ้า bounds มีขนาด 0 จะไม่จำกัด)
static func clamp_to_bounds(pos: Vector2, bounds_rect: Rect2) -> Vector2:
	if bounds_rect.size == Vector2.ZERO:
		return pos
	var min_x: float = minf(bounds_rect.position.x, bounds_rect.end.x)
	var max_x: float = maxf(bounds_rect.position.x, bounds_rect.end.x)
	var min_y: float = minf(bounds_rect.position.y, bounds_rect.end.y)
	var max_y: float = maxf(bounds_rect.position.y, bounds_rect.end.y)
	return Vector2(
		clampf(pos.x, min_x, max_x),
		clampf(pos.y, min_y, max_y)
	)


## คำนวณตำแหน่งติดตามแบบนุ่ม (lerp frame-rate independent)
static func compute_follow_position(current: Vector2, target_pos: Vector2, smooth_speed: float, delta: float) -> Vector2:
	if smooth_speed <= 0.0:
		return target_pos
	var weight: float = clampf(1.0 - exp(-smooth_speed * delta), 0.0, 1.0)
	return current.lerp(target_pos, weight)


## คำนวณ offset สั่นจาก trauma แบบ trauma²
## roll: ทิศทางการสั่น (-1.0 ถึง 1.0), หากเป็น INF จะสุ่มให้อัตโนมัติ
static func calculate_shake_offset(trauma_val: float, max_offset: Vector2, roll: Vector2 = Vector2(INF, INF)) -> Vector2:
	var t: float = clampf(trauma_val, 0.0, 1.0)
	var shake: float = t * t
	if shake <= 0.0:
		return Vector2.ZERO
	var dir: Vector2 = roll
	if is_inf(dir.x) or is_inf(dir.y):
		dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	return Vector2(dir.x * max_offset.x * shake, dir.y * max_offset.y * shake)


## หยุดเวลาชั่วคราว (hitstop) โดยตั้ง Engine.time_scale ต่ำลง แล้วคืนเป็น 1.0 เมื่อหมดเวลา
## ใช้ timer ที่ ignore_time_scale เพื่อให้นับเวลาจริงได้ รองรับการเรียกซ้อนกัน
static func hitstop(seconds: float, tree: SceneTree = null, scale_val: float = DEFAULT_HITSTOP_SCALE) -> SceneTreeTimer:
	var st: SceneTree = tree if tree != null else Engine.get_main_loop() as SceneTree
	if st == null:
		return null
	_hitstop_count += 1
	Engine.time_scale = scale_val
	var timer: SceneTreeTimer = st.create_timer(seconds, true, false, true)
	var called: Array[bool] = [false]
	timer.timeout.connect(func() -> void:
		if called[0]:
			return
		called[0] = true
		_on_hitstop_timeout()
	)
	return timer


static func _on_hitstop_timeout() -> void:
	_hitstop_count = maxi(0, _hitstop_count - 1)
	if _hitstop_count == 0:
		Engine.time_scale = 1.0


## คืนค่า time_scale เป็น 1.0 ทันที และล้างสถานะ hitstop
static func reset_hitstop() -> void:
	_hitstop_count = 0
	Engine.time_scale = 1.0


# ── Signal Callbacks ──

func _on_damage_dealt(damaged_target: Node, _info: DamageInfo, _final_amount: int) -> void:
	var is_player: bool = is_instance_valid(damaged_target) and damaged_target.is_in_group(&"player")
	var trauma_amount: float = trauma_on_player_hit if is_player else trauma_on_other_hit
	add_trauma(trauma_amount)
	if hitstop_enabled:
		var duration: float = hitstop_player_hit_duration if is_player else hitstop_other_hit_duration
		hitstop(duration, get_tree() if is_inside_tree() else null, hitstop_time_scale)


## เข้าห้องใหม่: ห้องแรก (ยังไม่มี bounds) = ตั้งทันที · ห้องต่อไป = เลื่อนกล้องไปห้องนั้น
func _on_room_started(_room: Node, room_rect: Rect2) -> void:
	if room_rect.size == Vector2.ZERO:
		return
	if bounds.size == Vector2.ZERO or room_slide_duration <= 0.0:
		set_bounds(room_rect)
		snap_to_target()
	else:
		slide_to(room_rect, room_slide_duration)


## ฟื้นที่จุดเกิด: เลิก bounds เดิม แล้ววาร์ปไปหาผู้เล่น (dungeon จะส่ง room_started ของห้องใหม่ตามมา)
## ฟื้น/พักศาลเจ้า: จุดใหม่ยังอยู่ในขอบห้องเดิม → คงขอบไว้ · อยู่นอก → เลิกขอบ (รอ room_started ของห้องใหม่) · แล้ววาร์ปไปหาผู้เล่น
func _on_player_respawn_requested(position_: Vector2) -> void:
	if bounds.size != Vector2.ZERO and not bounds.has_point(position_):
		set_bounds(Rect2())
	snap_to_target.call_deferred()


func _on_screen_shake_requested(strength: float, _position: Vector2) -> void:
	add_trauma(clampf(strength, 0.0, 1.0))

