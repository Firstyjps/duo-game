extends CharacterBody2D
## หุ่นแทนผู้เล่น สำหรับลองศัตรูใน scene debug เท่านั้น (ตัวจริงเป็นของระบบ A)
## ลูกศร/WASD = เดิน · Space = ฟันรอบตัว · ไม่กดอะไร = เดินวนเองให้ศัตรูไล่

@export var speed: float = 90.0
@export var auto_walk: bool = true

var _t: float = 0.0
var _swing_t: float = 0.0
var _home: Vector2 = Vector2.ZERO

@onready var hitbox: Hitbox = $Hitbox
@onready var health: Health = $Health


func _ready() -> void:
	_home = position
	collision_layer = Combat.LAYER_PLAYER
	collision_mask = Combat.LAYER_WORLD
	$Hurtbox.hurt.connect(func(info: DamageInfo) -> void:
		health.take_damage(info.amount)
		velocity = info.knockback
		print("dummy โดน %d (เหลือ %d)" % [info.amount, health.hp]))


func _physics_process(delta: float) -> void:
	_t += delta
	var dir: Vector2 = Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	if dir == Vector2.ZERO and auto_walk:
		var goal: Vector2 = _home + Vector2(cos(_t * 0.7), sin(_t * 0.7) * 0.6) * 70.0
		dir = (goal - position).limit_length(1.0)
	velocity = velocity.move_toward(dir * speed, 900.0 * delta)
	move_and_slide()
	if Input.is_action_just_pressed(&"ui_accept"):
		hitbox.activate()
		_swing_t = 0.15
	if _swing_t > 0.0:
		_swing_t -= delta
		if _swing_t <= 0.0:
			hitbox.deactivate()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-6, -22, 12, 22), Color("d9c7a0"))
	draw_rect(Rect2(-6, -22, 12, 22), Color("3b2f2a"), false, 1.0)
	if _swing_t > 0.0:
		draw_arc(Vector2(0, -8), 22.0, 0.0, TAU, 24, Color(1, 1, 1, 0.6), 2.0)
