extends CanvasLayer
## MOCKUP HUD — HP / stamina / หลอดบอส (จาก EventBus.boss_engaged) / gold

var root: Control
var hp_bar: ProgressBar
var st_bar: ProgressBar
var boss_box: Control
var boss_bar: ProgressBar
var boss_name: Label
var gold_label: Label
var hint: Label
var st_fill: StyleBoxFlat


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	hp_bar = _bar(Vector2(160, 10), Color(0.85, 0.2, 0.22))
	st_bar = _bar(Vector2(160, 6), Color(0.35, 0.85, 0.4))
	st_fill = st_bar.get_theme_stylebox(&"fill")
	boss_box = Control.new()
	root.add_child(boss_box)
	boss_name = _label("", 12, Color(1.0, 0.85, 0.6))
	boss_name.reparent(boss_box)
	boss_bar = _bar(Vector2(420, 8), Color(0.95, 0.5, 0.15))
	boss_bar.reparent(boss_box)
	boss_box.visible = false
	gold_label = _label("GOLD 0", 12, Color(1.0, 0.85, 0.3))
	hint = _label("WASD move  ·  mouse aim  ·  LMB / J slash  ·  Space dodge (i-frames)  ·  R restart", 9, Color(0.8, 0.85, 0.9, 0.8))
	EventBus.boss_engaged.connect(_on_boss_engaged)
	get_viewport().size_changed.connect(_layout)
	_layout()


func bind_player(p: Node) -> void:
	var h: Health = p.health
	h.changed.connect(func(c: int, m: int) -> void:
		hp_bar.max_value = m
		hp_bar.value = c)
	hp_bar.max_value = h.max_hp
	hp_bar.value = h.hp
	p.stamina_changed.connect(func(c: float, m: float) -> void:
		st_bar.max_value = m
		st_bar.value = c)
	st_bar.max_value = p.STAMINA_MAX
	st_bar.value = p.stamina
	p.stamina_empty.connect(_flash_stamina)
	if p.autoplay:
		hint.text = "AUTOPLAY DEMO  ·  mockup (art: Higgsfield)"


func set_gold(g: int) -> void:
	gold_label.text = "GOLD %d" % g


func _layout() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	hp_bar.position = Vector2(16, s.y - 34)
	st_bar.position = Vector2(16, s.y - 20)
	boss_box.position = Vector2((s.x - 420.0) / 2.0, 14)
	boss_name.position = Vector2(0, 0)
	boss_bar.position = Vector2(0, 18)
	gold_label.position = Vector2(s.x - 90, 12)
	hint.position = Vector2(s.x - 470, s.y - 20)


func _on_boss_engaged(_boss: Node, health: Health, display_name: String) -> void:
	boss_box.visible = true
	boss_name.text = display_name
	boss_bar.max_value = health.max_hp
	boss_bar.value = health.hp
	health.changed.connect(func(c: int, _m: int) -> void: boss_bar.value = c)
	health.died.connect(func() -> void: boss_name.text = display_name + "  —  DEFEATED")


func _flash_stamina() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(st_fill, "bg_color", Color(1.0, 0.25, 0.2), 0.05)
	tw.tween_property(st_fill, "bg_color", Color(0.35, 0.85, 0.4), 0.3)


func _bar(size: Vector2, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.size = size
	b.custom_minimum_size = size
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	bg.border_color = Color(0.0, 0.0, 0.0)
	bg.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	b.add_theme_stylebox_override(&"background", bg)
	b.add_theme_stylebox_override(&"fill", fill)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(b)
	return b


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_constant_override(&"outline_size", 3)
	l.add_theme_color_override(&"font_outline_color", Color.BLACK)
	root.add_child(l)
	return l
