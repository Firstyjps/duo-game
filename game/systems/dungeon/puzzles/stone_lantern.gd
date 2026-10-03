class_name StoneLantern
extends StaticBody2D
## โคมหินจุดไฟ isometric (issue #57)
## โดนตี (Hurtbox team NEUTRAL รับ Hitbox ผู้เล่น) → จุดไฟ PointLight2D + on · lit_time (0 = ติดถาวร)
## เมื่อติดถาวรแล้ว ปิด hurtbox.monitorable เพื่อไม่ให้ lock-on ค้าง

signal toggled(on: bool)
signal ignited
signal extinguished

const ART_TEXTURE: Texture2D = preload("res://systems/dungeon/puzzles/art/stone_lantern.png")

@export var lit_time: float = 0.0
@export var targets: Array[NodePath] = []

var is_lit: bool = false
var hurtbox: Hurtbox
var point_light: PointLight2D
var collision_shape: CollisionShape2D
var sprite: Sprite2D

var _timer: float = 0.0
var _ready_done: bool = false


func _init() -> void:
	collision_layer = Combat.LAYER_WORLD
	collision_mask = 0


func _ready() -> void:
	setup()


func setup() -> void:
	if _ready_done:
		return
	_ready_done = true

	collision_layer = Combat.LAYER_WORLD
	collision_mask = 0

	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = ART_TEXTURE
		sprite.centered = false
		sprite.offset = Vector2(-32, -76)
		add_child(sprite)
	else:
		sprite.texture = ART_TEXTURE
		sprite.centered = false
		sprite.offset = Vector2(-32, -76)

	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = 10.0
		collision_shape.shape = circle
		add_child(collision_shape)

	hurtbox = get_node_or_null("Hurtbox") as Hurtbox
	if hurtbox == null:
		hurtbox = Hurtbox.new()
		hurtbox.name = "Hurtbox"
		hurtbox.team = Combat.Team.NEUTRAL
		var hcol := CollisionShape2D.new()
		hcol.name = "CollisionShape2D"
		var hshape := CircleShape2D.new()
		hshape.radius = 14.0
		hcol.position = Vector2(0, -32)
		hcol.shape = hshape
		hurtbox.add_child(hcol)
		add_child(hurtbox)
	else:
		hurtbox.team = Combat.Team.NEUTRAL

	if not hurtbox.hurt.is_connected(_on_hurt):
		hurtbox.hurt.connect(_on_hurt)

	point_light = get_node_or_null("PointLight2D") as PointLight2D
	if point_light == null:
		point_light = PointLight2D.new()
		point_light.name = "PointLight2D"
		point_light.position = Vector2(0, -43)
		point_light.color = Color(1.0, 0.72, 0.3)
		point_light.energy = 1.3
		point_light.texture = _create_light_texture()
		point_light.texture_scale = 1.5
		point_light.enabled = is_lit
		add_child(point_light)
	else:
		point_light.position = Vector2(0, -43)
		point_light.enabled = is_lit


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if is_lit and lit_time > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			extinguish()


func ignite() -> void:
	if is_lit and lit_time <= 0.0:
		return
	is_lit = true
	_timer = lit_time
	if lit_time <= 0.0 and hurtbox != null:
		hurtbox.set_deferred(&"monitorable", false)
	if point_light != null:
		point_light.enabled = true
	queue_redraw()
	ignited.emit()
	toggled.emit(true)
	_notify_targets(true)


func extinguish() -> void:
	if not is_lit:
		return
	is_lit = false
	_timer = 0.0
	if hurtbox != null:
		hurtbox.set_deferred(&"monitorable", true)
	if point_light != null:
		point_light.enabled = false
	queue_redraw()
	extinguished.emit()
	toggled.emit(false)
	_notify_targets(false)


func _on_hurt(info: DamageInfo) -> void:
	# NEUTRAL รับได้ทุกทีม แต่ lantern จุดเฉพาะเมื่อทีม PLAYER ตี
	if info.team == Combat.Team.PLAYER:
		ignite()


func _notify_targets(on: bool) -> void:
	for path in targets:
		var target := get_node_or_null(path)
		if target == null:
			continue
		if on:
			if target.has_method("activate"):
				target.call("activate", self)
		else:
			if target.has_method("deactivate"):
				target.call("deactivate", self)


func _create_light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex


func _draw() -> void:
	# Overlay: flame and glow inside the lantern window
	if is_lit:
		draw_circle(Vector2(0, -43), 4.5, Color(1.0, 0.85, 0.3, 0.95))
		draw_circle(Vector2(0, -43), 8.0, Color(1.0, 0.6, 0.1, 0.45))
