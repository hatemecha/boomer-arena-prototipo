shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 1.0;

void fragment() {
	vec4 mask = texture(TEXTURE, UV);
	if (mask.a < 0.01) {
		discard;
	}

	vec3 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	COLOR = vec4(1.0 - screen_color, mask.a * opacity);
}
