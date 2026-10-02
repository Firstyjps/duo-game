extends RefCounted
## กันค่าหน้าจอ pixel art ถูกเปลี่ยนโดยไม่ตั้งใจ — เปลี่ยนจริงต้องตกลงกันก่อน (docs/DECISIONS.md)

func _setting(key: String) -> Variant:
	return ProjectSettings.get_setting(key)

func test_base_resolution_960x540() -> bool:
	return _setting("display/window/size/viewport_width") == 960 \
		and _setting("display/window/size/viewport_height") == 540

func test_stretch_viewport_expand_integer() -> bool:
	return _setting("display/window/stretch/mode") == "viewport" \
		and _setting("display/window/stretch/aspect") == "expand" \
		and _setting("display/window/stretch/scale_mode") == "integer"

func test_pixel_crisp() -> bool:
	return _setting("rendering/textures/canvas_textures/default_texture_filter") == 0 \
		and _setting("rendering/2d/snap/snap_2d_transforms_to_pixel") == true
