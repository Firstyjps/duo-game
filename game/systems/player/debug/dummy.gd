class_name Dummy
extends CharacterBody2D
## หุ่นลองฟันสำหรับ sandbox — รับดาเมจตาม contract damage

@export var max_hp: int = 100
@export var defense: int = 0
@export var respawn_delay: float = 1.0

var health: Health
var hurtbox: Hurtbox
var collision_shape: CollisionShape2D
var _flash_t: float = 0.0
var _hp_label: Label


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Combat.LAYER_ENEMY
	collision_mask = Combat.LAYER_WORLD

	health = get_node_or_null("Health") as Health
	hurtbox = get_node_or_null("Hurtbox") as Hurtbox
	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	_hp_label = get_node_or_null("Label") as Label

	if hurtbox != null:
		hurtbox.team = Combat.Team.ENEMY
		if not hurtbox.hurt.is_connected(_on_hurt):
			hurtbox.hurt.connect(_on_hurt)

	if health != null:
		health.max_hp = max_hp
		health.reset()
		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)
		if not health.changed.is_connected(_on_health_changed):
			health.changed.connect(_on_health_changed)

	_update_label()


func _physics_process(delta: float) -> void:
	if velocity.length_squared() > 1.0:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
	if _flash_t > 0.0:
		_flash_t -= delta
		queue_redraw()


func _on_hurt(info: DamageInfo) -> void:
	var final_amount: int = maxi(1, info.amount - defense)
	var dealt: int = health.take_damage(final_amount)
	EventBus.damage_dealt.emit(self, info, dealt)
	velocity = info.knockback
	_flash_t = 0.1
	queue_redraw()


func _on_died() -> void:
	EventBus.enemy_died.emit(self, &"dummy", global_position)
	get_tree().create_timer(respawn_delay).timeout.connect(func() -> void:
		health.reset()
		_update_label()
	)


func _on_health_changed(_cur: int, _max: int) -> void:
	_update_label()


func _update_label() -> void:
	if _hp_label != null and health != null:
		_hp_label.text = "Dummy HP: %d/%d" % [health.hp, health.max_hp]


func _draw() -> void:
	# Ground shadow
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 16.0, Color(0.0, 0.0, 0.0, 0.4))
	draw_set_transform(Vector2.ZERO)

	# Dummy body
	var col: Color = Color(1.5, 0.5, 0.5) if _flash_t > 0.0 else Color(0.8, 0.55, 0.3)
	draw_circle(Vector2(0.0, -16.0), 14.0, col)
	draw_circle(Vector2(0.0, -32.0), 10.0, col.lightened(0.2))
	# Dummy target cross
	draw_line(Vector2(-8.0, -16.0), Vector2(8.0, -16.0), Color.DARK_RED, 2.0)
	draw_line(Vector2(0.0, -24.0), Vector2(0.0, -8.0), Color.DARK_RED, 2.0)
