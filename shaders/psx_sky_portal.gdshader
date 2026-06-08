shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform vec3 top_color = vec3(0.32, 0.48, 0.78);
uniform vec3 horizon_color = vec3(0.78, 0.84, 0.9);
uniform vec3 cloud_color = vec3(0.88, 0.9, 0.86);
uniform vec3 star_color = vec3(0.68, 0.76, 1.0);
uniform float cloud_amount : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float star_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float brightness : hint_range(0.1, 2.0, 0.01) = 1.0;

float hash(vec2 sample_position) {
	return fract(sin(dot(sample_position, vec2(127.1, 311.7))) * 43758.5453123);
}

float block_noise(vec2 sample_position) {
	vec2 cell = floor(sample_position);
	vec2 local = fract(sample_position);
	local = local * local * (vec2(3.0) - vec2(2.0) * local);
	float a = hash(cell);
	float b = hash(cell + vec2(1.0, 0.0));
	float c = hash(cell + vec2(0.0, 1.0));
	float d = hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

void fragment() {
	vec2 pixel_uv = floor(UV * vec2(48.0, 28.0)) / vec2(48.0, 28.0);
	float vertical = clamp(pixel_uv.y, 0.0, 1.0);
	vec3 sky_color = mix(horizon_color, top_color, vertical);

	float cloud_noise = block_noise(pixel_uv * vec2(5.0, 2.5) + vec2(0.7, 0.2));
	float cloud_band = smoothstep(0.18, 0.72, vertical) * (1.0 - smoothstep(0.92, 1.0, vertical));
	float cloud_mask = smoothstep(0.52, 0.74, cloud_noise + cloud_band * 0.16) * cloud_amount;
	sky_color = mix(sky_color, cloud_color, cloud_mask);

	float star_noise = hash(floor(pixel_uv * vec2(90.0, 46.0)));
	float star_mask = step(0.985, star_noise) * smoothstep(0.36, 1.0, vertical) * star_amount;
	sky_color = mix(sky_color, star_color, star_mask);

	ALBEDO = sky_color * brightness;
	EMISSION = sky_color * brightness;
	ALPHA = 1.0;
}
