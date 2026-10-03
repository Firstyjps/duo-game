extends SceneTree
## Runner ทดสอบการ teardown dungeon ใน SceneTree จริง (issue #39, Item 3)
## godot --headless --path game --script res://systems/dungeon/tools/test_teardown_runner.gd

var _frame: int = 0
var _cleared_emitted: bool = false


func _initialize() -> void:
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	if _frame == 1:
		_setup_and_teardown()
	elif _frame >= 3:
		if not _cleared_emitted:
			print("PASS: Teardown locked dungeon in real tree emitted NO fake room_cleared")
			quit(0)
		else:
			printerr("FAIL: Teardown locked dungeon emitted fake room_cleared!")
			quit(1)


func _setup_and_teardown() -> void:
	var dungeon_scene: PackedScene = load("res://systems/dungeon/dungeon.tscn")
	var dungeon: Node2D = dungeon_scene.instantiate()
	root.add_child(dungeon)
	dungeon.call("setup")
	
	var rooms: Array = dungeon.get("rooms") as Array
	var r0: Node2D = rooms[0]
	r0.call("start_room")
	
	if r0.get("state") != 1 or r0.call("get_remaining_enemies_count") == 0:
		printerr("FAIL: Room 0 did not lock properly before teardown")
		quit(1)
		return
	
	if not r0.is_inside_tree():
		printerr("FAIL: Room 0 is not inside tree")
		quit(1)
		return
	
	var on_cleared := func(_r: Variant = null) -> void:
		_cleared_emitted = true
	
	r0.connect("room_cleared", on_cleared)
	var event_bus: Node = root.get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.connect("room_cleared", on_cleared)
	
	# Free parent (dungeon) ขณะห้อง LOCKED อยู่ใน tree จริง
	dungeon.free()
