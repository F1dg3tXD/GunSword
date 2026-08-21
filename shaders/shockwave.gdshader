shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

uniform vec4 color_center : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_edge : source_color = vec4(0.0, 0.5, 1.0, 0.0);
uniform int ripple_count : hint_range(1, 8) = 3;
uniform float ripple_width : hint_range(0.01, 0.5) = 0.12;
uniform float band_width : hint_range(0.0, 1.0) = 0.3;
uniform float fade_start_radius : hint_range(0.0, 20.0) = 2.0;
uniform float fade_end_radius : hint_range(0.0, 20.0) = 4.0;

void fragment() {
	vec3 local = VERTEX;
	float dist = length(local);

	float world_scale = length(MODEL_MATRIX[0].xyz);

	float y_norm = dist > 0.001 ? abs(local.y) / dist : 0.0;
	float band = 1.0 - smoothstep(band_width, band_width + 0.05, y_norm);

	float norm_dist = dist / max(world_scale, 0.001);
	float ripple = 0.0;
	for (int i = 0; i < ripple_count; i++) {
		float phase = float(i) * 6.28318 / float(ripple_count);
		float wave = sin(norm_dist * 6.28318 * float(ripple_count) - TIME * 10.0 + phase);
		ripple += smoothstep(1.0 - ripple_width, 1.0, wave);
	}
	ripple = clamp(ripple, 0.0, 1.0);

	vec4 col = mix(color_edge, color_center, ripple);
	col.a *= band;

	float fade = 1.0 - clamp((world_scale - fade_start_radius) / (fade_end_radius - fade_start_radius), 0.0, 1.0);
	col.a *= fade;

	ALBEDO = col.rgb;
	ALPHA = col.a;
}
