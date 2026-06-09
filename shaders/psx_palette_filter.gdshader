shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float color_levels : hint_range(2.0, 16.0, 1.0) = 6.0;
uniform float dither_strength : hint_range(0.0, 0.08, 0.005) = 0.025;
uniform float palette_mix : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float contrast : hint_range(0.5, 1.8, 0.01) = 1.16;
uniform float brightness : hint_range(-0.2, 0.2, 0.01) = -0.04;
uniform float fisheye_strength : hint_range(0.0, 0.35, 0.001) = 0.018;
uniform float fisheye_center_flatness : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float lens_zoom_compensation : hint_range(0.9, 1.2, 0.001) = 1.015;
uniform float chromatic_aberration_strength : hint_range(0.0, 0.02, 0.00025) = 0.0006;
uniform float chromatic_edge_start : hint_range(0.0, 1.2, 0.01) = 0.70;
uniform float vignette_strength : hint_range(0.0, 1.0, 0.005) = 0.035;
uniform float vignette_radius : hint_range(0.4, 1.8, 0.01) = 1.35;
uniform float vignette_softness : hint_range(0.05, 1.0, 0.01) = 0.35;
uniform float circular_mask_strength : hint_range(0.0, 1.0, 0.005) = 0.0;
uniform float circular_mask_radius : hint_range(0.4, 1.8, 0.01) = 1.20;
uniform float circular_mask_softness : hint_range(0.01, 0.8, 0.01) = 0.25;
uniform float film_grain_strength : hint_range(0.0, 0.12, 0.001) = 0.010;
uniform float film_grain_speed : hint_range(0.0, 60.0, 0.1) = 14.0;
uniform float film_grain_scale : hint_range(20.0, 500.0, 1.0) = 180.0;
uniform float lens_dirt_strength : hint_range(0.0, 0.2, 0.005) = 0.0;
uniform float lens_aspect_ratio : hint_range(0.5, 3.0, 0.01) = 1.7778;
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

float hash_21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}

float soft_spot(vec2 uv, vec2 center, float radius, float softness) {
	float distance_to_center = length(uv - center);
	return 1.0 - smoothstep(radius, radius + softness, distance_to_center);
}

float get_aspect_mix() {
	return mix(1.0, lens_aspect_ratio, 0.38);
}

vec2 to_distortion_space(vec2 screen_uv) {
	vec2 centered_uv = screen_uv * 2.0 - 1.0;
	centered_uv.x *= get_aspect_mix();
	return centered_uv;
}

vec2 from_distortion_space(vec2 lens_uv) {
	vec2 centered_uv = lens_uv;
	centered_uv.x /= get_aspect_mix();
	return centered_uv * 0.5 + vec2(0.5);
}

vec2 sample_barrel_distortion_uv(vec2 screen_uv) {
	vec2 lens_uv = to_distortion_space(screen_uv);
	float radius = length(lens_uv);
	float radius_squared = radius * radius;
	float edge_mask = smoothstep(fisheye_center_flatness, 1.25, radius);
	float distortion = 1.0 + fisheye_strength * radius_squared * edge_mask;
	vec2 distorted_lens_uv = lens_uv / max(distortion, 0.0001);
	distorted_lens_uv *= lens_zoom_compensation;
	return from_distortion_space(distorted_lens_uv);
}

vec2 chromatic_offset(vec2 lens_uv, float radius) {
	float chroma_mask = smoothstep(chromatic_edge_start, 1.25, radius);
	vec2 offset = lens_uv * chromatic_aberration_strength * chroma_mask;
	offset.x /= get_aspect_mix();
	return offset;
}

float film_grain(vec2 screen_position) {
	float time_slice = floor(TIME * film_grain_speed);
	vec2 grain_cell = floor(screen_position * max(film_grain_scale, 1.0) / 240.0);
	grain_cell += vec2(time_slice, time_slice * 1.37);
	return (hash_21(grain_cell) - 0.5) * film_grain_strength;
}

void fragment() {
	vec2 lens_uv = to_distortion_space(SCREEN_UV);
	float lens_radius = length(lens_uv);
	vec2 distorted_uv = sample_barrel_distortion_uv(SCREEN_UV);
	distorted_uv = clamp(distorted_uv, vec2(0.001), vec2(0.999));

	vec2 chroma_offset = chromatic_offset(lens_uv, lens_radius);
	float red_channel = texture(screen_texture, clamp(distorted_uv + chroma_offset, vec2(0.001), vec2(0.999))).r;
	float green_channel = texture(screen_texture, distorted_uv).g;
	float blue_channel = texture(screen_texture, clamp(distorted_uv - chroma_offset, vec2(0.001), vec2(0.999))).b;
	vec3 original_color = vec3(red_channel, green_channel, blue_channel);
	float dither = (bayer_4x4(FRAGCOORD.xy) - 0.5) * dither_strength;
	vec3 adjusted_color = original_color + vec3(dither);

	adjusted_color = (adjusted_color - vec3(0.5)) * contrast + vec3(0.5 + brightness);
	adjusted_color = clamp(adjusted_color, vec3(0.0), vec3(1.0));

	vec3 quantized_color = floor(adjusted_color * color_levels) / color_levels;
	float red_signal = smoothstep(0.35, 0.9, quantized_color.r - max(quantized_color.g, quantized_color.b));
	vec3 limited_palette_color = mix(quantized_color * tint_color, danger_color, red_signal * 0.32);
	vec3 final_color = mix(original_color, limited_palette_color, palette_mix);

	float vignette_mask = smoothstep(vignette_radius, vignette_radius + max(vignette_softness, 0.001), lens_radius);
	final_color *= 1.0 - vignette_mask * vignette_strength;

	float scanline = sin(FRAGCOORD.y * 2.4) * 0.004;
	float lens_dirt_mask = smoothstep(0.54, 1.18, lens_radius);
	float lens_dirt = soft_spot(SCREEN_UV, vec2(0.18, 0.62), 0.045, 0.12);
	lens_dirt += soft_spot(SCREEN_UV, vec2(0.78, 0.66), 0.035, 0.10);
	lens_dirt += soft_spot(SCREEN_UV, vec2(0.88, 0.48), 0.018, 0.06);
	lens_dirt *= lens_dirt_strength * lens_dirt_mask;

	final_color += vec3(scanline * 0.35 + film_grain(FRAGCOORD.xy) + lens_dirt * 0.08);

	float circular_mask = smoothstep(
		circular_mask_radius,
		circular_mask_radius + max(circular_mask_softness, 0.001),
		lens_radius
	);
	final_color = mix(final_color, vec3(0.0, 0.001, 0.004), circular_mask * circular_mask_strength);

	COLOR = vec4(clamp(final_color, vec3(0.0), vec3(1.0)), 1.0);
}
