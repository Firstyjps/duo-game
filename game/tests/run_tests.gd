extends SceneTree
## รันทุกไฟล์ res://tests/test_*.gd — ทุก method ที่ขึ้นต้นด้วย test_ ต้อง return true
## godot --headless --path game --script res://tests/run_tests.gd

## รันใน _initialize() ไม่ใช่ _init() — autoload (EventBus) ถูกเพิ่มเข้า root หลัง _init ทำให้ script ที่ใช้ EventBus compile ไม่ผ่าน
func _initialize() -> void:
	var passed: int = 0
	var failed: Array[String] = []
	for file: String in DirAccess.get_files_at("res://tests"):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			failed.append("%s (โหลด script ไม่ได้)" % file)
			continue
		var suite: Object = script.new()
		for m: Dictionary in suite.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var res: Variant = suite.call(name)
			if res is Object and res.has_signal("completed"):
				res = await res.completed
			elif res is Signal:
				res = await res
			if res == true:
				passed += 1
			else:
				failed.append("%s::%s" % [file, name])
		if suite is Node:
			suite.free()
	for f: String in failed:
		printerr("FAIL ", f)
	print("tests: %d passed, %d failed" % [passed, failed.size()])
	quit(1 if failed.size() > 0 else 0)
