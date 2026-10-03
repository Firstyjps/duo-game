extends Node2D

@onready var player: Player = $Player
@onready var dummy: Dummy = $Dummy
@onready var dummy2: Dummy = get_node_or_null("Dummy2") as Dummy
@onready var hud_label: Label = $CanvasLayer/HUDLabel
@onready var parry_label: Label = $CanvasLayer/ParryLabel

var _parry_feedback_t: float = 0.0


func _ready() -> void:
	if player != null:
		player.stamina_changed.connect(_on_stamina_changed)
		if player.health != null:
			player.health.changed.connect(_on_hp_changed)
		player.lock_target_changed.connect(_on_lock_target_changed)
		player.parried.connect(_on_parried)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			# สั่งหุ่นที่ใกล้ที่สุด (หรือเป้าที่ล็อคอยู่) โจมตีใส่ผู้เล่นเพื่อลอง Parry
			var target_dummy: Dummy = dummy
			if player != null and player.lock_target is Dummy:
				target_dummy = player.lock_target as Dummy
			if target_dummy != null and player != null:
				target_dummy.trigger_attack(player.global_position)


func _process(delta: float) -> void:
	_update_hud()
	if _parry_feedback_t > 0.0:
		_parry_feedback_t -= delta
		if parry_label != null:
			parry_label.modulate.a = clampf(_parry_feedback_t / 0.6, 0.0, 1.0)
	elif parry_label != null and parry_label.visible:
		parry_label.visible = false


func _on_stamina_changed(_cur: float, _max: float) -> void:
	_update_hud()


func _on_hp_changed(_cur: int, _max: int) -> void:
	_update_hud()


func _on_lock_target_changed(_target: Node2D) -> void:
	_update_hud()


func _on_parried(_info: DamageInfo) -> void:
	_parry_feedback_t = 1.0
	if parry_label != null:
		parry_label.visible = true
		parry_label.modulate.a = 1.0


func _update_hud() -> void:
	if player == null or hud_label == null:
		return
	var state_name: String = Player.State.keys()[player.state] if player.state < Player.State.size() else "UNKNOWN"
	if player.state == Player.State.ATTACK and player.attack_phase == Player.AttackPhase.CHARGING:
		state_name = "CHARGING (Ready!)" if player.is_charged() else "CHARGING..."
	var hp_str: String = "%d/%d" % [player.health.hp, player.health.max_hp] if player.health != null else "-"
	var lock_str: String = player.lock_target.name if player.is_locked_on() else "None"
	hud_label.text = "HP: %s  |  Stamina: %.1f/%.0f  |  State: %s  |  Lock-on: %s" % [
		hp_str, player.stamina, player.stamina_max, state_name, lock_str
	]
