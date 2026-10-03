extends RefCounted
## ฉากรวม GameRun — game/systems/ui/run/ · Issue #64


func _make() -> GameRun:
	var run: GameRun = (load("res://systems/ui/run/game_run.tscn") as PackedScene).instantiate()
	run.setup()
	return run


func test_builds_all_parts_and_spawns_at_marker() -> bool:
	var run: GameRun = _make()
	var expected: Vector2 = GameRun.find_spawn(run.level)
	var ok: bool = run.player != null and run.camera != null and run.hud != null and run.pause_menu != null \
		and run.camera.target == run.player and expected != Vector2.ZERO \
		and run.player.position == expected
	run.free()
	return ok


func test_find_spawn_sums_parent_offsets() -> bool:
	var root := Node2D.new()
	var mid := Node2D.new()
	mid.position = Vector2(100, 50)
	root.add_child(mid)
	var m := Marker2D.new()
	m.position = Vector2(10, 5)
	m.add_to_group(&"player_spawn")
	mid.add_child(m)
	var ok: bool = GameRun.find_spawn(root) == Vector2(110, 55) and GameRun.find_spawn(Node2D.new()) == Vector2.ZERO
	root.free()
	return ok


func test_respawn_handler_detection() -> bool:
	var root := Node2D.new()
	var no_handler: bool = not GameRun.level_handles_respawn(root)
	var d := Node.new()
	d.add_to_group(&"respawn_handler")
	root.add_child(d)
	var ok: bool = no_handler and GameRun.level_handles_respawn(root)
	root.free()
	return ok


## ด่านไม่มี respawn_handler → GameRun ฟื้นผู้เล่นที่จุดเกิดเอง
func test_self_respawn_revives_at_spawn() -> bool:
	var run: GameRun = _make()
	var hit := DamageInfo.new()
	hit.team = Combat.Team.ENEMY
	hit.amount = 999
	run.player.position = Vector2(5, 5)
	run.player.hurtbox.receive(hit)
	var dead: bool = run.player.is_dead()
	run._respawn_here()
	var ok: bool = dead and not run.player.is_dead() and run.player.global_position == GameRun.find_spawn(run.level)
	run.free()
	return ok
