extends Node2D
## Sandbox สำหรับทดสอบ HUD (ระบบ A) — กดปุ่มในจอหรือแป้นพิมพ์ 1–6, R
## 1 = ลด HP ผู้เล่น
## 2 = ใช้ stamina (หมดจะกระพริบแดง)
## 3 = ส่ง EventBus.boss_engaged
## 4 = ส่ง EventBus.damage_dealt (สลับตีศัตรู, คริติคอล, ตีผู้เล่น)
## 5 = ลด HP บอส (เมื่อตายจะซ่อนหลังหน่วง 1.5 วิ)
## 6 = สลับเป้า lock-on (ศัตรู -> บอส -> ปลดล็อค)
## R = รีเซ็ต HP/stamina ผู้เล่น
## รองรับ --shot=<path> สำหรับบันทึกภาพหน้าจอ

class MockStaminaSource extends RefCounted:
	signal stamina_changed(current: float, maximum: float)
	signal stamina_empty

	var stamina: float = 100.0
	var stamina_max: float = 100.0

	func use(amount: float) -> void:
		stamina = maxf(0.0, stamina - amount)
		stamina_changed.emit(stamina, stamina_max)
		if stamina <= 0.0:
			stamina_empty.emit()

	func recover(amount: float) -> void:
		if stamina < stamina_max:
			stamina = minf(stamina_max, stamina + amount)
			stamina_changed.emit(stamina, stamina_max)

	func reset() -> void:
		stamina = stamina_max
		stamina_changed.emit(stamina, stamina_max)


class MockLockSource extends RefCounted:
	signal lock_target_changed(target: Node2D)

	var lock_target: Node2D = null

	func set_target(t: Node2D) -> void:
		lock_target = t
		lock_target_changed.emit(t)


@onready var hud: GameHud = $GameHud
@onready var player_health: Health = $PlayerDummy/Health
@onready var boss_health: Health = $BossDummy/Health
@onready var player_dummy: Node2D = $PlayerDummy
@onready var enemy_dummy: Node2D = $EnemyDummy
@onready var boss_dummy: Node2D = $BossDummy
@onready var status_label: Label = $UI/StatusLabel

var stamina_source: MockStaminaSource = MockStaminaSource.new()
var lock_source: MockLockSource = MockLockSource.new()
var _damage_cycle: int = 0
var _lock_cycle: int = 0


func _ready() -> void:
	_setup_actions()
	player_dummy.add_to_group(&"player")

	player_health.max_hp = 10
	player_health.reset()

	boss_health.max_hp = 60
	boss_health.reset()

	hud.bind_player(player_health, stamina_source)
	hud.bind_lock_source(lock_source)

	# เชื่อมปุ่มใน UI
	$UI/Buttons/BtnHurtPlayer.pressed.connect(hurt_player)
	$UI/Buttons/BtnUseStamina.pressed.connect(use_stamina)
	$UI/Buttons/BtnEngageBoss.pressed.connect(engage_boss)
	$UI/Buttons/BtnDamageDealt.pressed.connect(deal_damage)
	$UI/Buttons/BtnHurtBoss.pressed.connect(hurt_boss)
	var btn_lock: Button = $UI/Buttons.get_node_or_null("BtnLockTarget") as Button
	if btn_lock != null:
		btn_lock.pressed.connect(toggle_lock_target)
	$UI/Buttons/BtnReset.pressed.connect(reset_all)

	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shoot(arg.trim_prefix("--shot="))


func _process(delta: float) -> void:
	stamina_source.recover(18.0 * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"hud_test_1"):
		hurt_player()
	elif event.is_action_pressed(&"hud_test_2"):
		use_stamina()
	elif event.is_action_pressed(&"hud_test_3"):
		engage_boss()
	elif event.is_action_pressed(&"hud_test_4"):
		deal_damage()
	elif event.is_action_pressed(&"hud_test_5"):
		hurt_boss()
	elif event.is_action_pressed(&"hud_test_6"):
		toggle_lock_target()
	elif event.is_action_pressed(&"hud_test_r"):
		reset_all()


func hurt_player() -> void:
	if player_health.is_dead:
		player_health.reset()
	var dealt: int = player_health.take_damage(2)
	var info := DamageInfo.new()
	info.team = Combat.Team.ENEMY
	info.amount = 2
	EventBus.damage_dealt.emit(player_dummy, info, dealt)
	_update_status("Player hit -2 HP (เหลือ %d/%d)" % [player_health.hp, player_health.max_hp])


func use_stamina() -> void:
	stamina_source.use(25.0)
	_update_status("Used 25 Stamina (เหลือ %.0f/%.0f)" % [stamina_source.stamina, stamina_source.stamina_max])


func engage_boss() -> void:
	boss_health.reset()
	EventBus.boss_engaged.emit(boss_dummy, boss_health, "Stone Colossus")
	_update_status("Boss Engaged: Stone Colossus (HP %d/%d)" % [boss_health.hp, boss_health.max_hp])


func deal_damage() -> void:
	_damage_cycle = (_damage_cycle + 1) % 3
	var info := DamageInfo.new()
	match _damage_cycle:
		0:
			# ศัตรูโดนตีปกติ (สีเหลืองอ่อน)
			info.team = Combat.Team.PLAYER
			info.amount = 14
			info.is_crit = false
			EventBus.damage_dealt.emit(enemy_dummy, info, 14)
			_update_status("Enemy hit: 14 DMG (Normal)")
		1:
			# ศัตรูโดนตีคริติคอล (ขนาดใหญ่)
			info.team = Combat.Team.PLAYER
			info.amount = 42
			info.is_crit = true
			EventBus.damage_dealt.emit(enemy_dummy, info, 42)
			_update_status("Enemy hit: 42 DMG (CRITICAL!)")
		2:
			# ผู้เล่นโดนตี (สีแดง)
			info.team = Combat.Team.ENEMY
			info.amount = 8
			info.is_crit = false
			EventBus.damage_dealt.emit(player_dummy, info, 8)
			_update_status("Player hit: 8 DMG (Red text)")


func hurt_boss() -> void:
	if boss_health.is_dead:
		boss_health.reset()
		EventBus.boss_engaged.emit(boss_dummy, boss_health, "Stone Colossus")
	var dealt: int = boss_health.take_damage(15)
	var info := DamageInfo.new()
	info.team = Combat.Team.PLAYER
	info.amount = dealt
	EventBus.damage_dealt.emit(boss_dummy, info, dealt)
	_update_status("Boss hit -15 HP (เหลือ %d/%d)%s" % [
		boss_health.hp,
		boss_health.max_hp,
		"  — DEFEATED! (จะซ่อนใน 1.5 วิ)" if boss_health.is_dead else ""
	])


func toggle_lock_target() -> void:
	_lock_cycle = (_lock_cycle + 1) % 3
	match _lock_cycle:
		0:
			lock_source.set_target(null)
			_update_status("Lock Target: None (Unfocused)")
		1:
			lock_source.set_target(enemy_dummy)
			_update_status("Lock Target: ENEMY (Marker above enemy)")
		2:
			lock_source.set_target(boss_dummy)
			_update_status("Lock Target: BOSS (Marker above boss)")


func reset_all() -> void:
	player_health.reset()
	stamina_source.reset()
	boss_health.reset()
	lock_source.set_target(null)
	_lock_cycle = 0
	_update_status("Reset Player HP, Stamina & Lock Target")


func _update_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _setup_actions() -> void:
	_register_action(&"hud_test_1", KEY_1)
	_register_action(&"hud_test_2", KEY_2)
	_register_action(&"hud_test_3", KEY_3)
	_register_action(&"hud_test_4", KEY_4)
	_register_action(&"hud_test_5", KEY_5)
	_register_action(&"hud_test_6", KEY_6)
	_register_action(&"hud_test_r", KEY_R)


func _register_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(action, ev)


func _shoot(path: String) -> void:
	await get_tree().create_timer(float(OS.get_environment("SHOT_DELAY")) if OS.has_environment("SHOT_DELAY") else 1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
