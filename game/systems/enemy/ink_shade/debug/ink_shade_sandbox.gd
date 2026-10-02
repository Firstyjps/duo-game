extends Node2D
## Scene ทดสอบศัตรูเงาหมึก (InkShade): F6 ใน editor หรือ godot --path game res://systems/enemy/ink_shade/debug/ink_shade_sandbox.tscn
## ควบคุม Dummy: ลูกศร/WASD เดิน, Space ฟันโจมตี

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shoot(arg.trim_prefix("--shot="))


func _shoot(path: String) -> void:
	await get_tree().create_timer(float(OS.get_environment("SHOT_DELAY")) if OS.has_environment("SHOT_DELAY") else 2.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
