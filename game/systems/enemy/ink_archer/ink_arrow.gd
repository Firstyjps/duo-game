class_name InkArrow
extends Area2D
## ลูกธนูหมึก — กระสุนยิงตรงของนักธนูหมึก
## ชนกำแพง (world) หรือโดน Hurtbox แล้วหาย · โดน parry สะท้อนกลับเป็นทีม PLAYER

@export var speed: float = 260.0
@export var arrow_life: float = 3.0
@export var damage: int = 2
@export var knockback_force: float = 140.0
@export var stagger: float = 8.0

var direction: Vector2 = Vector2.RIGHT
var hitbox: Hitbox
var collision_shape: CollisionShape2D

var _time_alive: float = 0.0
var _is_reflected: bool = false
var _configured: bool = false


func _ready() -> void:
	setup()


## เรียกได้หลายครั้ง (ก่อน add_child และใน _ready) — ค่าที่ผู้ยิงตั้ง (damage/source) ต้องไม่ถูกรีเซ็ต
func setup() -> void:
	if _configured:
		return
	_configured = true
	collision_shape = $CollisionShape2D if has_node("CollisionShape2D") else null
	hitbox = $Hitbox if has_node("Hitbox") else null
	collision_layer = 0
	collision_mask = Combat.LAYER_WORLD
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if hitbox != null:
		hitbox.team = Combat.Team.ENEMY
		hitbox.damage = damage
		hitbox.knockback_force = knockback_force
		hitbox.stagger = stagger
		if hitbox.source == null:
			hitbox.source = self
		if not hitbox.hit_landed.is_connected(_on_hit_landed):
			hitbox.hit_landed.connect(_on_hit_landed)
		if not hitbox.deflected.is_connected(_on_deflected):
			hitbox.deflected.connect(_on_deflected)
		hitbox.activate()
	rotation = direction.angle()


func set_direction(dir: Vector2) -> void:
	if dir.length_squared() > 0.0001:
		direction = dir.normalized()
	rotation = direction.angle()
	queue_redraw()


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if is_queued_for_deletion():
		return
	_time_alive += delta
	if _time_alive >= arrow_life:
		destroy()
		return
	var move_step: Vector2 = direction * speed * delta
	if is_inside_tree():
		var world: World2D = get_world_2d()
		if world != null:
			var space: PhysicsDirectSpaceState2D = world.direct_space_state
			if space != null:
				var query := PhysicsRayQueryParameters2D.create(global_position, global_position + move_step, Combat.LAYER_WORLD)
				var hit: Dictionary = space.intersect_ray(query)
				if not hit.is_empty():
					_on_wall_hit(hit.collider as Node)
					return
	global_position += move_step
	rotation = direction.angle()


func _on_body_entered(body: Node2D) -> void:
	if body is StaticBody2D or body is TileMap or body is TileMapLayer or (body is CollisionObject2D and ((body as CollisionObject2D).collision_layer & Combat.LAYER_WORLD) != 0):
		_on_wall_hit(body)


func _on_wall_hit(_wall: Node) -> void:
	destroy()


func _on_hit_landed(_hurtbox: Hurtbox, _info: DamageInfo) -> void:
	destroy()


func _on_deflected(hurtbox: Hurtbox, _info: DamageInfo) -> void:
	if _is_reflected:
		return
	_is_reflected = true
	direction = -direction
	rotation = direction.angle()
	if hitbox != null:
		hitbox.team = Combat.Team.PLAYER
		hitbox.source = hurtbox.owner if hurtbox != null else null
		hitbox.activate()
	queue_redraw()


func destroy() -> void:
	if not is_queued_for_deletion():
		queue_free()


func is_reflected() -> bool:
	return _is_reflected


func _draw() -> void:
	var shaft_col := Color(0.12, 0.08, 0.16) if not _is_reflected else Color(0.9, 0.75, 0.2)
	var tip_col := Color(0.25, 0.12, 0.32) if not _is_reflected else Color(1.0, 0.9, 0.4)
	var feather_col := Color(0.35, 0.18, 0.45) if not _is_reflected else Color(0.4, 0.8, 1.0)
	var glow_col := Color(0.4, 0.1, 0.6, 0.35) if not _is_reflected else Color(0.2, 0.7, 1.0, 0.4)

	# Faint ink glow
	draw_line(Vector2(-10, 0), Vector2(7, 0), glow_col, 4.0)

	# Main arrow shaft
	draw_line(Vector2(-9, 0), Vector2(6, 0), shaft_col, 2.0)

	# Arrow head
	var head_points: PackedVector2Array = [
		Vector2(9, 0),
		Vector2(4, -3.5),
		Vector2(4, 3.5)
	]
	draw_colored_polygon(head_points, tip_col)

	# Arrow fletching
	draw_line(Vector2(-6, -2.5), Vector2(-9, 0), feather_col, 1.5)
	draw_line(Vector2(-6, 2.5), Vector2(-9, 0), feather_col, 1.5)
