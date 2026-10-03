shader_type canvas_item;

uniform vec4 silhouette_color : source_color = vec4(0.7843, 0.7216, 1.0, 0.55);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	COLOR = vec4(silhouette_color.rgb, tex_color.a * silhouette_color.a);
}
