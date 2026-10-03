extends Node2D
## Sandbox สำหรับทดสอบ PauseMenu ร่วมกับ gameplay
## รัน: godot --path game res://systems/ui/debug/pause_sandbox.tscn
## กด Esc หรือ Joypad Start เพื่อหยุด/กลับเกม

var box: ColorRect
var speed: float = 200.0
var dir: float = 1.0


func _ready() -> void:
	box = get_node_or_null("Box") as ColorRect


func _process(delta: float) -> void:
	if box != null:
		box.position.x += speed * dir * delta
		if box.position.x > 800:
			dir = -1.0
		elif box.position.x < 100:
			dir = 1.0
