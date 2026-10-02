extends SceneTree
## แปลงภาพ concept (art/concept/*.png) → sprite ใน res://mockup/assets/
## godot --headless --path game --script res://mockup/tools/import_concept.gd

const SPRITES: Dictionary = {"knight": 56, "skeleton": 52, "golem": 112}  ## ชื่อ → ความสูง (px)


func _init() -> void:
	var src: String = ProjectSettings.globalize_path("res://").path_join("../art/concept")
	for name: String in SPRITES:
		var img := Image.load_from_file(src.path_join(name + ".png"))
		img.convert(Image.FORMAT_RGBA8)
		_key_magenta(img)
		var used: Rect2i = img.get_used_rect()
		img = img.get_region(used)
		var h: int = SPRITES[name]
		var w: int = maxi(1, roundi(float(img.get_width()) * h / img.get_height()))
		img.resize(w, h, Image.INTERPOLATE_NEAREST)
		img.save_png("res://mockup/assets/%s.png" % name)
		print(name, " ", used.size, " -> ", Vector2i(w, h))
	var arena := Image.load_from_file(src.path_join("arena.png"))
	arena.resize(960, 536, Image.INTERPOLATE_BILINEAR)
	arena.save_png("res://mockup/assets/arena.png")
	print("arena -> 960x536")
	quit()


## พื้น magenta → โปร่งใส (เผื่อสีเพี้ยนจากการ gen)
func _key_magenta(img: Image) -> void:
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.75 and c.b > 0.75 and c.g < 0.35:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
