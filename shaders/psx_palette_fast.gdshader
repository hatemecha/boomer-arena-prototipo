shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float color_levels : hint_range(2.0, 16.0, 1.0) = 6.0;
uniform float dither_strength : hint_range(0.0, 0.08, 0.005) = 0.025;
uniform float palette_mix : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float contrast : hint_range(0.5, 1.8, 0.01) = 1.16;
uniform float brightness : hint_range(-0.2, 0.2, 0.01) = -0.04;
uniform float vignette_strength : hint_range(0.0, 1.0, 0.005) = 0.035;
uniform float vignette_radius : hint_range(0.4, 1.8, 0.01) = 1.35;
uniform float vignette_softness : hint_range(0.05, 1.0, 0.01) = 0.35;
uniform vec3 tint_color = vec3(0.62, 0.78, 0.82);
uniform vec3 danger_color = vec3(0.74, 0.025, 0.02);

float bayer_4x4(vec2 screen_position) {
	int x = int(mod(screen_position.x, 4.0));
	int y = int(mod(screen_position.y, 4.0));
	int index = x + y * 4;
	float value = 0.0;

	if (index == 0) value = 0.0;
	else if (index == 1) value = 8.0;
	else if (index == 2) value = 2.0;
	else if (index == 3) value = 10.0;
	else if (index == 4) value = 12.0;
	else if (index == 5) value = 4.0;
	else if (index == 6) value = 14.0;
	else if (index == 7) value = 6.0;
	else if (index == 8) value = 3.0;
	else if (index == 9) value = 11.0;
	else if (index == 10) value = 1.0;
	else if (index == 11) value = 9.0;
	else if (index == 12) value = 15.0;
	else if (index == 13) value = 7.0;
	else if (index == 14) value = 13.0;
	else value = 5.0;

	return value / 15.0;
}

void fragment() {
	vec3 original_color = texture(screen_texture, SCREEN_UV).rgb;
	float dither = (bayer_4x4(FRAGCOORD.xy) - 0.5) * dither_strength;
	vec3 adjusted_color = original_color + vec3(dither);

	adjusted_color = (adjusted_color - vec3(0.5)) * contrast + vec3(0.5 + brightness);
	adjusted_color = clamp(adjusted_color, vec3(0.0), vec3(1.0));

	vec3 quantized_color = floor(adjusted_color * color_levels) / color_levels;
	float red_signal = smoothstep(0.35, 0.9, quantized_color.r - max(quantized_color.g, quantized_color.b));
	vec3 limited_palette_color = mix(quantized_color * tint_color, danger_color, red_signal * 0.32);
	vec3 final_color = mix(original_color, limited_palette_color, palette_mix);

	vec2 centered_uv = SCREEN_UV * 2.0 - 1.0;
	float lens_radius = length(centered_uv);
	float vignette_mask = smoothstep(vignette_radius, vignette_radius + max(vignette_softness, 0.001), lens_radius);
	final_color *= 1.0 - vignette_mask * vignette_strength;

	COLOR = vec4(clamp(final_color, vec3(0.0), vec3(1.0)), 1.0);
}
