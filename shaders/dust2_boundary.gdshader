shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_disable;
uniform vec4 atlas_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 tile_scale = vec2(8.0);
uniform vec3 color_tint : source_color = vec3(1.0);


void fragment() {
	vec2 atlas_uv = atlas_region.xy + fract(UV * tile_scale) * atlas_region.zw;
	ALBEDO = texture(atlas_texture, atlas_uv).rgb * color_tint;
	ROUGHNESS = 1.0;
}
