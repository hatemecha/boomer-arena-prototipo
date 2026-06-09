shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform vec3 top_color = vec3(0.035, 0.055, 0.13);
uniform vec3 horizon_color = vec3(0.16, 0.19, 0.3);
uniform vec3 cloud_color = vec3(0.22, 0.26, 0.4);
uniform vec3 star_color = vec3(0.68, 0.76, 1.0);
uniform float cloud_amount : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float star_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float brightness : hint_range(0.1, 2.5, 0.01) = 1.0;
uniform float cloud_speed : hint_range(0.0, 0.08, 0.001) = 0.010;
uniform float cloud_shadow : hint_range(0.0, 1.0, 0.01) = 0.55;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// FBM: 3 octaves for organic clouds
float fbm(vec2 p) {
	float v = 0.0;
	v += 0.56 * vnoise(p);
	v += 0.28 * vnoise(p * 2.2 + vec2(1.72, 9.38));
	v += 0.16 * vnoise(p * 4.8 + vec2(5.13, 3.81));
	return v;
}

void fragment() {
	// PSX pixelation grid
	vec2 pix = floor(UV * vec2(48.0, 28.0)) / vec2(48.0, 28.0);
	float vert = pix.y;

	// Sky gradient — non-linear curve to push colour to horizon
	float grad = pow(clamp(vert, 0.0, 1.0), 0.55);
	vec3 sky = mix(horizon_color, top_color, grad);

	// Horizon atmospheric glow
	float glow = (1.0 - smoothstep(0.0, 0.28, vert)) * 0.38;
	sky += horizon_color * glow;

	// Clouds — FBM with slow horizontal drift
	// Scale tuned for 240×120m backdrop planes viewed from ~35m distance
	vec2 drift = pix * vec2(8.0, 5.0) + vec2(TIME * cloud_speed, 0.0);
	float cloud_fbm = fbm(drift);

	// Clouds live mostly in the middle-upper sky
	float cloud_band = smoothstep(0.04, 0.50, vert) * (1.0 - smoothstep(0.90, 1.0, vert));
	float cloud_shape = smoothstep(0.38, 0.65, cloud_fbm) * cloud_band;
	float cloud_mask = cloud_shape * cloud_amount;

	// Cloud depth: lit top, shadowed underside
	float cloud_top  = smoothstep(0.45, 0.65, cloud_fbm);
	float cloud_base = smoothstep(0.38, 0.50, cloud_fbm);
	vec3  cloud_lit  = mix(cloud_color * (1.0 - cloud_shadow * 0.55), cloud_color, cloud_top);

	// Slight darkening at the very bottom edge of each cloud mass
	float cloud_under = (1.0 - cloud_base) * cloud_shape;
	cloud_lit -= vec3(cloud_shadow * 0.18) * cloud_under;

	sky = mix(sky, clamp(cloud_lit, vec3(0.0), vec3(1.0)), cloud_mask);

	// Stars — upper portion, hidden by clouds
	float star_field = hash(floor(pix * vec2(110.0, 58.0)));
	float star_mask = step(0.986, star_field)
		* smoothstep(0.28, 0.85, vert)
		* (1.0 - cloud_mask)
		* star_amount;
	sky = mix(sky, star_color, star_mask);

	ALBEDO   = sky * brightness;
	EMISSION = sky * brightness;
	ALPHA = 1.0;
}
