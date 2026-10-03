class_name Door
extends Node2D
## ประตูห้องดันเจี้ยน isometric — ปิดขังเมื่อห้อง locked, เปิดเมื่อ cleared
## มี collision บน LAYER_WORLD เมื่อปิด, และ Area2D ตรวจจับผู้เล่นเดินผ่านเมื่อเปิด

signal entered(door: Door)
signal opened(door: Door)
signal closed(door: Door)

const REGION_CLOSED: Rect2 = Rect2(256, 32, 64, 64)
const REGION_OPEN: Rect2 = Rect2(320, 32, 64, 64)

@export var is_open: bool = false
@export var door_name: StringName = &"exit"

var sprite: Sprite2D
var blocker: StaticBody2D
var blocker_shape: CollisionPolygon2D
var exit_trigger: Area2D
var exit_shape: CollisionShape2D


func _ready() -> void:
	setup()


func setup() -> void:
	sprite = get_node_or_null("Sprite2D") as Sprite2D
	blocker = get_node_or_null("Blocker") as StaticBody2D
	if blocker != null:
		blocker_shape = blocker.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
		blocker.collision_layer = Combat.LAYER_WORLD
		blocker.collision_mask = 0
	
	exit_trigger = get_node_or_null("ExitTrigger") as Area2D
	if exit_trigger != null:
		exit_shape = exit_trigger.get_node_or_null("CollisionShape2D") as CollisionShape2D
		exit_trigger.collision_layer = 0
		exit_trigger.collision_mask = Combat.LAYER_PLAYER
		if not exit_trigger.body_entered.is_connected(_on_body_entered):
			exit_trigger.body_entered.connect(_on_body_entered)
	
	_update_visual_and_collision()


func open_door() -> void:
	is_open = true
	_update_visual_and_collision()
	opened.emit(self)


func close_door() -> void:
	is_open = false
	_update_visual_and_collision()
	closed.emit(self)


func _update_visual_and_collision() -> void:
	if sprite != null:
		sprite.region_rect = REGION_OPEN if is_open else REGION_CLOSED
	
	if blocker_shape != null:
		if is_inside_tree():
			blocker_shape.set_deferred("disabled", is_open)
		else:
			blocker_shape.disabled = is_open
	
	if exit_trigger != null:
		if is_inside_tree():
			exit_trigger.set_deferred("monitoring", is_open)
		else:
			exit_trigger.monitoring = is_open
	
	if exit_shape != null:
		if is_inside_tree():
			exit_shape.set_deferred("disabled", not is_open)
		else:
			exit_shape.disabled = not is_open


func _on_body_entered(body: Node2D) -> void:
	if not is_open:
		return
	if body.is_in_group(&"player") or (body.collision_layer & Combat.LAYER_PLAYER) != 0:
		entered.emit(self)
