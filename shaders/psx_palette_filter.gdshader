shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float color_levels : hint_range(2.0, 16.0, 1.0) = 6.0;
uniform float dither_strength : hint_range(0.0, 0.08, 0.005) = 0.025;
uniform float palette_mix : hint_range(0.0, 1.0, 0.01) = 0.65;
uniform float contrast : hint_range(0.5, 1.8, 0.01) = 1.12;
uniform float brightness : hint_range(-0.2, 0.2, 0.01) = -0.02;
uniform float fisheye_strength : hint_range(0.0, 0.2, 0.002) = 0.06;
uniform float chromatic_aberration_strength : hint_range(0.0, 0.02, 0.0005) = 0.0018;
uniform float vignette_strength : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float vignette_radius : hint_range(0.2, 1.5, 0.01) = 1.08;
uniform float vignette_softness : hint_range(0.05, 1.0, 0.01) = 0.72;
uniform float lens_dirt_strength : hint_range(0.0, 0.5, 0.01) = 0.05;
uniform float lens_aspect_ratio : hint_range(0.5, 3.0, 0.01) = 1.7778;
uniform vec3 tint_color = vec3(0.94, 0.92, 0.86);
uniform vec3 danger_color = vec3(0.85, 0.06, 0.035);

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

float hash_21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}

float soft_spot(vec2 uv, vec2 center, float radius, float softness) {
	float distance_to_center = length(uv - center);
	return 1.0 - smoothstep(radius, radius + softness, distance_to_center);
}

vec2 to_lens_space(vec2 screen_uv) {
	vec2 centered_uv = screen_uv * 2.0 - 1.0;
	centered_uv.x *= lens_aspect_ratio;
	return centered_uv;
}

vec2 from_lens_space(vec2 lens_uv) {
	vec2 centered_uv = lens_uv;
	centered_uv.x /= lens_aspect_ratio;
	return centered_uv * 0.5 + vec2(0.5);
}

vec2 sample_barrel_uv(vec2 screen_uv, float strength) {
	vec2 lens_uv = to_lens_space(screen_uv);
	float lens_distance = length(lens_uv);
	if (lens_distance < 0.0001) {
		return screen_uv;
	}

	float lens_distance_squared = lens_distance * lens_distance;
	float lens_distance_fourth = lens_distance_squared * lens_distance_squared;
	float distorted_distance = lens_distance * (1.0 + strength * lens_distance_squared + strength * 0.1 * lens_distance_fourth);
	vec2 distorted_lens_uv = lens_uv * (distorted_distance / lens_distance);
	return from_lens_space(distorted_lens_uv);
}

void fragment() {
	vec2 lens_space = to_lens_space(SCREEN_UV);
	float lens_distance = length(lens_space);
	float edge_mask = smoothstep(0.55, vignette_radius + vignette_softness, lens_distance);
	vec2 distorted_uv = sample_barrel_uv(SCREEN_UV, fisheye_strength);
	float sample_oob = max(
		max(max(0.0, -distorted_uv.x), max(0.0, -distorted_uv.y)),
		max(max(0.0, distorted_uv.x - 1.0), max(0.0, distorted_uv.y - 1.0))
	);
	float sample_valid = 1.0 - smoothstep(0.0, 0.08, sample_oob);
	distorted_uv = clamp(distorted_uv, vec2(0.001), vec2(0.999));

	vec2 centered_uv = SCREEN_UV * 2.0 - 1.0;
	vec2 aberration_offset = centered_uv * chromatic_aberration_strength * (0.2 + edge_mask * 1.1);
	float red_channel = texture(screen_texture, clamp(distorted_uv + aberration_offset, vec2(0.001), vec2(0.999))).r;
	float green_channel = texture(screen_texture, distorted_uv).g;
	float blue_channel = texture(screen_texture, clamp(distorted_uv - aberration_offset, vec2(0.001), vec2(0.999))).b;
	vec3 original_color = vec3(red_channel, green_channel, blue_channel);
	float dither = (bayer_4x4(FRAGCOORD.xy) - 0.5) * dither_strength;
	vec3 adjusted_color = original_color + vec3(dither);

	adjusted_color = (adjusted_color - vec3(0.5)) * contrast + vec3(0.5 + brightness);
	adjusted_color = clamp(adjusted_color, vec3(0.0), vec3(1.0));

	vec3 quantized_color = floor(adjusted_color * color_levels) / color_levels;
	float red_signal = smoothstep(0.35, 0.9, quantized_color.r - max(quantized_color.g, quantized_color.b));
	vec3 limited_palette_color = mix(quantized_color * tint_color, danger_color, red_signal * 0.32);
	float vignette_mask = smoothstep(vignette_radius, vignette_radius + vignette_softness, lens_distance);
	float vignette = 1.0 - vignette_mask * vignette_strength;
	vignette *= sample_valid;

	float scanline = sin(FRAGCOORD.y * 2.4) * 0.012;
	float grain = (hash_21(FRAGCOORD.xy) - 0.5) * 0.035;
	float lens_dirt = soft_spot(SCREEN_UV, vec2(0.18, 0.62), 0.045, 0.12);
	lens_dirt += soft_spot(SCREEN_UV, vec2(0.78, 0.66), 0.035, 0.10);
	lens_dirt += soft_spot(SCREEN_UV, vec2(0.88, 0.48), 0.018, 0.06);
	lens_dirt *= lens_dirt_strength * edge_mask;
	vec3 lens_bleed = vec3(0.42, 0.72, 1.0) * lens_dirt;

	vec3 final_color = mix(original_color, limited_palette_color, palette_mix);
	final_color = final_color * vignette + lens_bleed + vec3((scanline + grain) * edge_mask);
	COLOR = vec4(clamp(final_color, vec3(0.0), vec3(1.0)), 1.0);
}
