extends Node2D
## Scene ทดสอบศัตรูเงาหมึก (InkShade): F6 ใน editor หรือ godot --path game res://systems/enemy/ink_shade/debug/ink_shade_sandbox.tscn
## ควบคุม Dummy: ลูกศร/WASD เดิน, Space ฟันโจมตี

func _ready() -> void:
	var dummy: Node2D = get_node_or_null("Dummy") as Node2D
	if dummy != null:
		var hurt: Hurtbox = dummy.get_node_or_null("Hurtbox") as Hurtbox
		if hurt != null:
			hurt.team = Combat.Team.PLAYER
		var hit: Hitbox = dummy.get_node_or_null("Hitbox") as Hitbox
		if hit != null:
			hit.team = Combat.Team.PLAYER
			hit.source = dummy
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shoot(arg.trim_prefix("--shot="))


func _shoot(path: String) -> void:
	await get_tree().create_timer(float(OS.get_environment("SHOT_DELAY")) if OS.has_environment("SHOT_DELAY") else 2.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
