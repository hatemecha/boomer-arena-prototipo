shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(1.0, 0.12, 0.05, 1.0);
uniform float outline_width : hint_range(0.0, 0.12, 0.001) = 0.03;
uniform float outline_brightness : hint_range(0.5, 3.0, 0.05) = 1.35;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb * outline_brightness;
}
