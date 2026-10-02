extends RefCounted
## MOCKUP — helper เอฟเฟกต์ (flash shader, แสง)

const SHADER_CODE: String = """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
uniform float flash = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, tint.rgb, flash), c.a);
}
"""

static var _shader: Shader
static var _light_tex: Texture2D


static func flash_material() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var m := ShaderMaterial.new()
	m.shader = _shader
	return m


static func flash(mat: ShaderMaterial, node: Node, color: Color, duration: float = 0.12) -> void:
	mat.set_shader_parameter(&"tint", color)
	mat.set_shader_parameter(&"flash", 1.0)
	var tw: Tween = node.create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"flash", v), 1.0, 0.0, duration)


static func light(color: Color, energy: float, scale: float) -> PointLight2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 256
		t.height = 256
		_light_tex = t
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.color = color
	l.energy = energy
	l.texture_scale = scale
	return l


static func circle_shape(area: Node2D, radius: float, at: Vector2) -> void:
	var s := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	s.shape = c
	s.position = at
	area.add_child(s)
