extends Node2D

@onready var player: Player = $Player
@onready var hud_label: Label = $CanvasLayer/HUDLabel


func _ready() -> void:
	if player != null and hud_label != null:
		player.stamina_changed.connect(_on_stamina_changed)
		if player.health != null:
			player.health.changed.connect(_on_hp_changed)
		_update_hud()


func _process(_delta: float) -> void:
	_update_hud()


func _on_stamina_changed(_cur: float, _max: float) -> void:
	_update_hud()


func _on_hp_changed(_cur: int, _max: int) -> void:
	_update_hud()


func _update_hud() -> void:
	if player == null or hud_label == null:
		return
	var state_name: String = Player.State.keys()[player.state] if player.state < Player.State.size() else "UNKNOWN"
	var hp_str: String = "%d/%d" % [player.health.hp, player.health.max_hp] if player.health != null else "-"
	hud_label.text = "HP: %s  |  Stamina: %.1f/%.0f  |  State: %s" % [hp_str, player.stamina, player.stamina_max, state_name]
