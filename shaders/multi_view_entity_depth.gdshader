shader_type spatial;
render_mode blend_mix, depth_draw_always, depth_prepass_alpha, cull_disabled;

/**
 * Multi-View Entity PBR Shader
 *
 * Designed for AnimatedSprite3D with layer-based PBR support.
 * Alpha is inherited from the albedo_texture (the sprite's current frame).
 * Normal, roughness, and depth maps are optional additional SpriteFrames layers.
 *
 * Compatible with the OpenGL Compatibility renderer.
 */

// Required albedo from SpriteFrames (current frame texture).
uniform sampler2D albedo_texture : source_color;

// Optional PBR maps — SpriteFrames resources sharing the same animation names.
uniform sampler2D normal_texture : hint_normal;
uniform sampler2D roughness_texture : hint_default_white;
uniform sampler2D depth_texture : hint_default_black;
uniform sampler2D emission_texture : source_color, hint_default_black;

// PBR controls
uniform float normal_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.5;
uniform float roughness_mix : hint_range(0.0, 1.0) = 0.0;
uniform float depth_scale : hint_range(0.0, 1.0) = 0.0;
uniform float emission_strength : hint_range(0.0, 16.0) = 0.0;
uniform vec4 modulate_color : source_color = vec4(1.0);
uniform vec4 emission_color : source_color = vec4(1.0);

void fragment() {
	vec2 uv = UV;

	// Parallax depth offset — computed first so all subsequent
	// texture lookups use the shifted UVs.
	if (depth_scale > 0.0) {
		float depth_val = texture(depth_texture, uv).r;
		vec3 view_dir = normalize(VIEW);
		vec3 tangent_view = normalize(
			TANGENT * view_dir.x +
			BINORMAL * view_dir.y +
			NORMAL * view_dir.z
		);
		uv += tangent_view.xy * depth_val * depth_scale * 0.1;
	}

	// Albedo + alpha
	vec4 albedo_sample = texture(albedo_texture, uv);
	ALBEDO = albedo_sample.rgb * modulate_color.rgb;
	ALPHA = albedo_sample.a;
	ALPHA_SCISSOR_THRESHOLD = 0.1;

	// Normal map (tangent space)
	vec3 normal_sample = texture(normal_texture, uv).rgb;
	normal_sample = normal_sample * 2.0 - 1.0;
	NORMAL_MAP = normal_sample;
	NORMAL_MAP_DEPTH = normal_intensity;

	// Roughness
	float rough_sample = texture(roughness_texture, uv).r;
	ROUGHNESS = mix(roughness_value, rough_sample, roughness_mix);

	// Emission
	vec3 emis_sample = texture(emission_texture, uv).rgb;
	EMISSION = emis_sample * emission_color.rgb * emission_strength;
}
