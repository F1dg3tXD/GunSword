// Occlusion Window — 3D receiver shader.
// Assign as the material shader of 3D occluders (walls, pillars, props) and enable the
// `occlusion_window_occlude` uniform on those that should thin out in front of the
// player. The cut is per fragment in screen space, using each fragment's view depth
// compared against the target's, and it works on both the Forward+ and the OpenGL
// Compatibility renderers. The material is blended so the windowed region shows whatever
// sits behind the occluder; opaque pixels outside the window still write depth.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform bool occlusion_window_occlude = false;
// Diffuse texture for the occluder. Assign the model's albedo map to the material's
// "Albedo Texture" slot; unassigned it samples as white.
uniform sampler2D albedo_texture : source_color, filter_linear;
// Tint multiplied over the albedo texture (the auto-apply pass copies it from the
// original StandardMaterial3D so converted walls look identical).
uniform vec4 albedo_color : source_color = vec4(1.0);
// Only cut roughly-vertical surfaces (walls, pillars, props, roof undersides). Flat
// up-facing ground and roof tops are not occluders and stay solid; disable to window
// any surface that sits between the target and the camera.
uniform bool occlusion_window_vertical_only = true;

#include "occlusion_window_common.gdshaderinc"

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb * albedo_color.rgb;
	if (occlusion_window_occlude) {
		vec3 world_normal = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
		bool vertical = !occlusion_window_vertical_only || abs(world_normal.y) < 0.5;
		if (vertical) {
			// View depth of this fragment (positive distance from the camera plane).
			float view_depth = -VIEW.z;
			ALPHA = 1.0 - occlusion_window_cut_3d(SCREEN_UV, view_depth);
		}
	}
}
