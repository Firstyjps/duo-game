extends Node2D
## Sandbox สำหรับลองสู้กับบอสมิโนทอร์ (F6 ใน editor)
## -- --shot=<path> = ถ่ายภาพหน้าจอแล้วปิด (ตรวจภาพอัตโนมัติ)

@onready var boss: BossMinotaur = $BossMinotaur
@onready var dummy: CharacterBody2D = $Dummy
@onready var ui_label: Label = $CanvasLayer/Label


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shoot(arg.trim_prefix("--shot="))


func _process(_delta: float) -> void:
	if ui_label != null and boss != null and is_instance_valid(boss):
		var phase_str: String = "Phase 2 (< 50% HP)" if boss.is_phase_2() else "Phase 1"
		var state_str: String = BossMinotaur.State.keys()[boss.state]
		var atk_str: String = BossMinotaur.AttackType.keys()[boss.current_attack]
		ui_label.text = "บอสมิโนทอร์ AI Sandbox\n" \
			+ "ควบคุม Dummy: ลูกศร / WASD = เดิน · Space = โจมตี\n" \
			+ "Boss HP: %d / %d (%s) | State: %s | Atk: %s | Poise: %.0f / %.0f" % [
				boss.health.hp if boss.health else 0,
				boss.health.max_hp if boss.health else 0,
				phase_str,
				state_str,
				atk_str,
				boss.accumulated_stagger,
				boss.poise,
			]


func _shoot(path: String) -> void:
	await get_tree().create_timer(float(OS.get_environment("SHOT_DELAY")) if OS.has_environment("SHOT_DELAY") else 0.5).timeout
	var tex: ViewportTexture = get_viewport().get_texture()
	if tex != null:
		var img: Image = tex.get_image()
		if img != null:
			img.save_png(path)
	get_tree().quit()
