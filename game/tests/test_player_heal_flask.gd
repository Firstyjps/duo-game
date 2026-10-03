extends RefCounted
## เทสต์ฟีเจอร์ขวดชาฟื้นพลัง (Heal Flask) ของผู้เล่น — game/systems/player/ · issue #54
## docs/GLOSSARY.md · game/systems/player/CLAUDE.md

const PLAYER_SCENE: PackedScene = preload("res://systems/player/player.tscn")


func _spawn() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.setup()
	return player


## input action `heal` (คีย์ R / จอย Y) ลงทะเบียนใน ensure_input_actions()
func test_input_action_heal_registered() -> bool:
	Player.ensure_input_actions()
	if not InputMap.has_action(&"heal"):
		return false
	var events: Array[InputEvent] = InputMap.action_get_events(&"heal")
	var has_r_key: bool = false
	var has_y_joy: bool = false
	for ev: InputEvent in events:
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_R:
			has_r_key = true
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == JOY_BUTTON_Y:
			has_y_joy = true
	return has_r_key and has_y_joy


## ดื่มครบฟื้น HP + ขวดลด
func test_drink_heals_hp_and_reduces_flask() -> bool:
	var player: Player = _spawn()
	player.health.take_damage(6)
	var hp_before: int = player.health.hp  # 6 / 12
	var flasks_before: int = player.flasks  # 3

	# เริ่มดื่ม (ป้อน intent heal)
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false, false, false, false, true)
	player.tick(0.0)

	var in_drink: bool = player.state == Player.State.DRINK
	var flask_spent: bool = player.flasks == (flasks_before - 1)  # 2
	var hp_not_yet_healed: bool = player.health.hp == hp_before

	# สเต็ปเวลาไป 0.3 วิ (ยังไม่ถึง heal_at 0.6 วิ) -> เลือดยังไม่เพิ่ม
	player.tick(0.3)
	var still_not_healed: bool = player.health.hp == hp_before and player.state == Player.State.DRINK

	# สเต็ปเวลาอีก 0.3 วิ (รวม 0.6 วิ = heal_at) -> เลือดเพิ่มจริงตาม flask_heal (5)
	player.tick(0.3)
	var healed_at_target: bool = player.health.hp == (hp_before + player.flask_heal)  # 6 + 5 = 11

	# สเต็ปเวลาอีก 0.3 วิ (รวม 0.9 วิ = drink_time) -> จบ DRINK กลับสู่ MOVE
	player.tick(0.3)
	var finished_to_move: bool = player.state == Player.State.MOVE \
		and player.health.hp == (hp_before + player.flask_heal) \
		and player.flasks == (flasks_before - 1)

	player.free()
	return in_drink and flask_spent and hp_not_yet_healed and still_not_healed and healed_at_target and finished_to_move


## โดนตีก่อน heal_at ขวดหายไม่ฟื้น
func test_hit_before_heal_at_cancels_heal_and_loses_flask() -> bool:
	var player: Player = _spawn()
	player.health.take_damage(4)
	var hp_before: int = player.health.hp  # 8 / 12
	var flasks_before: int = player.flasks  # 3

	# เริ่มดื่ม
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false, false, false, false, true)
	player.tick(0.0)

	var in_drink: bool = player.state == Player.State.DRINK and player.flasks == (flasks_before - 1)

	# สเต็ปไป 0.2 วิ (< heal_at 0.6) แล้วโดนโจมตี 3 ดาเมจ
	player.tick(0.2)
	var hit := DamageInfo.new()
	hit.team = Combat.Team.ENEMY
	hit.amount = 3
	player.hurtbox.receive(hit)

	var hurt_ok: bool = player.state == Player.State.HURT and player.health.hp == (hp_before - 3)  # 8 - 3 = 5

	# สเต็ปเวลาผ่านช่วง hurt และเกิน heal_at เดิม (เช่น 0.6 วิ) -> กลับสู่ MOVE โดยไม่ได้รับการฟื้นฟูเลือด
	player.tick(0.6)
	var back_to_move_unhealed: bool = player.state == Player.State.MOVE \
		and player.health.hp == 5 \
		and player.flasks == (flasks_before - 1)

	player.free()
	return in_drink and hurt_ok and back_to_move_unhealed


## dodge ยกเลิกได้ก่อน heal_at = เสียขวดฟรี
func test_dodge_cancels_drink_before_heal_at_wastes_flask() -> bool:
	var player: Player = _spawn()
	player.health.take_damage(4)
	var hp_before: int = player.health.hp  # 8 / 12
	var flasks_before: int = player.flasks  # 3

	# เริ่มดื่ม
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false, false, false, false, true)
	player.tick(0.0)

	var in_drink: bool = player.state == Player.State.DRINK

	# สเต็ปไป 0.2 วิ (< heal_at 0.6) แล้วสั่ง Dodge
	player.tick(0.2)
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, true, false, false, false, false)
	player.tick(0.0)

	var cancelled_into_dodge: bool = player.state == Player.State.DODGE \
		and player.health.hp == hp_before \
		and player.flasks == (flasks_before - 1)

	# สเต็ปจนจบ dodge -> กลับสู่ MOVE เลือดยังคงเดิม ขวดเสียฟรี
	player.tick(player.dodge_time)
	var back_to_move: bool = player.state == Player.State.MOVE \
		and player.health.hp == hp_before \
		and player.flasks == (flasks_before - 1)

	player.free()
	return in_drink and cancelled_into_dodge and back_to_move


## HP เต็ม กดดื่มไม่ได้
func test_cannot_drink_when_full_hp() -> bool:
	var player: Player = _spawn()
	var full_hp: int = player.health.max_hp
	var flasks_before: int = player.flasks

	# เลือดเต็ม กดดื่ม
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false, false, false, false, true)
	player.tick(0.0)

	var not_drank: bool = player.state == Player.State.MOVE \
		and player.flasks == flasks_before \
		and player.health.hp == full_hp

	player.free()
	return not_drank


## ขวดหมด กดดื่มไม่ได้
func test_cannot_drink_when_no_flasks() -> bool:
	var player: Player = _spawn()
	player.health.take_damage(6)
	var damaged_hp: int = player.health.hp
	player.flasks = 0

	# ขวดหมด กดดื่ม
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false, false, false, false, true)
	player.tick(0.0)

	var not_drank: bool = player.state == Player.State.MOVE \
		and player.flasks == 0 \
		and player.health.hp == damaged_hp

	player.free()
	return not_drank


## revive เติมขวดชาเต็ม
func test_revive_refills_flasks() -> bool:
	var player: Player = _spawn()
	player.health.take_damage(6)
	player.flasks = 1

	player.revive(Vector2(80, 80))

	var ok: bool = player.flasks == player.flask_max \
		and player.health.hp == player.health.max_hp \
		and player.state == Player.State.MOVE \
		and player.global_position == Vector2(80, 80)

	player.free()
	return ok


## refill_flasks() เป็น public method เติมเต็มตาม flask_max
func test_refill_flasks_public_method() -> bool:
	var player: Player = _spawn()
	player.flasks = 0
	player.refill_flasks()
	var ok: bool = player.flasks == player.flask_max
	player.free()
	return ok


## flasks_changed emit ถูกจังหวะ (ตอน setup, ตอนเริ่มดื่ม, ตอน refill)
func test_flasks_changed_emitted_at_correct_timing() -> bool:
	var player: Player = _spawn()
	player.health.take_damage(6)

	var emissions: Array[Dictionary] = []
	var cb := func(cur: int, max_val: int) -> void:
		emissions.append({"current": cur, "maximum": max_val})
	player.flasks_changed.connect(cb)

	# 1. เริ่มดื่ม -> ต้อง emit ทันทีที่เริ่ม DRINK
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false, false, false, false, true)
	player.tick(0.0)

	var drink_start_ok: bool = emissions.size() == 1 \
		and emissions[0]["current"] == 2 \
		and emissions[0]["maximum"] == player.flask_max

	# สเต็ปจนจบการดื่ม ไม่ควร emit ซ้ำระหว่างดื่มหรือจบ
	player.tick(player.drink_time)
	var during_drink_ok: bool = emissions.size() == 1

	# 2. refill_flasks() -> ต้อง emit
	player.refill_flasks()
	var refill_ok: bool = emissions.size() == 2 \
		and emissions[1]["current"] == player.flask_max \
		and emissions[1]["maximum"] == player.flask_max

	player.flasks_changed.disconnect(cb)
	player.free()
	return drink_start_ok and during_drink_ok and refill_ok


## ระหว่าง DRINK เดินช้าลงเหลือ 0.3x
func test_drink_movement_speed_slowed() -> bool:
	var player: Player = _spawn()
	player.health.take_damage(6)

	# กดเดินขวาพร้อมดื่ม
	player.set_intent(Vector2.RIGHT, Vector2.RIGHT, false, false, false, false, false, true)
	player.tick(0.0)

	var in_drink: bool = player.state == Player.State.DRINK
	var expected_velocity: Vector2 = Vector2.RIGHT * player.speed * 0.3
	var initial_speed_ok: bool = player.velocity.is_equal_approx(expected_velocity)

	# เดินลงระหว่างดื่ม
	player.set_intent(Vector2.DOWN, Vector2.RIGHT, false, false, false, false, false, false)
	player.tick(0.1)
	var expected_down: Vector2 = Vector2.DOWN * player.speed * 0.3
	var down_speed_ok: bool = player.velocity.is_equal_approx(expected_down)

	player.free()
	return in_drink and initial_speed_ok and down_speed_ok


## ระหว่าง DRINK ไม่สามารถโจมตีหรือ parry ได้
func test_drink_cannot_attack_or_parry() -> bool:
	var player: Player = _spawn()
	player.health.take_damage(6)

	# เริ่มดื่ม
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false, false, false, false, true)
	player.tick(0.0)
	var in_drink: bool = player.state == Player.State.DRINK

	# กด attack ระหว่างดื่ม
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, true, false, false, false, false, false)
	player.tick(0.1)
	var attack_ignored: bool = player.state == Player.State.DRINK and not player.hitbox.monitoring

	# กด parry ระหว่างดื่ม
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false, true, false, false, false)
	player.tick(0.1)
	var parry_ignored: bool = player.state == Player.State.DRINK and not player.hurtbox.deflecting

	player.free()
	return in_drink and attack_ignored and parry_ignored


## การฟื้นพลังไม่เกิน max_hp
func test_heal_capped_at_max_hp() -> bool:
	var player: Player = _spawn()
	player.health.take_damage(2)  # HP = 10 / 12
	# flask_heal = 5 -> ถ้าไม่ clamp จะเป็น 15 แต่ต้อง clamp ที่ 12

	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false, false, false, false, true)
	player.tick(0.0)
	player.tick(player.drink_time)

	var ok: bool = player.health.hp == player.health.max_hp
	player.free()
	return ok


## DirSprite ระหว่าง DRINK ใช้ท่า idle
func test_dir_sprite_idle_during_drink() -> bool:
	var player: Player = _spawn()
	player.health.take_damage(6)

	player.set_intent(Vector2.RIGHT, Vector2.RIGHT, false, false, false, false, false, true)
	player.tick(0.0)

	var ok: bool = true
	if player.dir_sprite != null:
		player._animate_dir_sprite(true)
		ok = player.dir_sprite.action == &"idle"

	player.free()
	return ok
