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

static var _hitstop_count: int = 0


func _ready() -> void:
	setup()


func _exit_tree() -> void:
	if EventBus != null and is_instance_valid(EventBus) and EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)
	reset_hitstop()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if EventBus != null and is_instance_valid(EventBus) and EventBus.damage_dealt.is_connected(_on_damage_dealt):
			EventBus.damage_dealt.disconnect(_on_damage_dealt)


## กำหนดค่าเริ่มต้นและผูก signal — แยกจาก _ready ให้เทสต์เรียกได้โดยไม่ต้องอยู่ใน scene tree
func setup() -> void:
	_internal_pos = position
	if bounds.size != Vector2.ZERO:
		set_bounds(bounds)
	if EventBus != null and is_instance_valid(EventBus) and not EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.connect(_on_damage_dealt)


## กำหนดเป้าหมายที่กล้องจะติดตาม
func follow(new_target: Node2D, snap: bool = false) -> void:
	target = new_target
	if snap and target != null and is_instance_valid(target):
		snap_to_target()


## วาร์ปตำแหน่งกล้องไปยังเป้าหมายทันทีโดยไม่ lerp
func snap_to_target() -> void:
	if target != null and is_instance_valid(target):
		_internal_pos = clamp_to_bounds(target.global_position, bounds)
		position = _internal_pos.round()


## กำหนดตำแหน่งกล้องโดยตรง (คำนวณ clamp ขอบ และ round ให้)
func set_camera_position(pos: Vector2) -> void:
	_internal_pos = clamp_to_bounds(pos, bounds)
	position = _internal_pos.round()


## กำหนดขอบเขตกล้อง (Rect2)
func set_bounds(rect: Rect2) -> void:
	bounds = rect
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
	_internal_pos = clamp_to_bounds(_internal_pos, bounds)
	position = _internal_pos.round()


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
	if target != null and is_instance_valid(target):
		_internal_pos = compute_follow_position(_internal_pos, target.global_position, follow_smooth_speed, delta)

	_internal_pos = clamp_to_bounds(_internal_pos, bounds)
	position = _internal_pos.round()

	trauma = decay_trauma(trauma, trauma_decay, delta)
	offset = calculate_shake_offset(trauma, max_shake_offset).round()


# ── Static Logic ที่เทสต์ได้โดยไม่ต้องพึ่ง scene tree ──

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
