// Cut-through — 3D receiver shader.
// Assign as the material shader of 3D geometry (walls, pillars, props, GridMaps)
// and enable `cylinder_cut_occlude` on those that should be cut through.
// Supports two cut modes driven by global uniforms:
//   - Cylinder: a cylinder between player_point → cam_point (legacy mode).
//   - Box volume: an oriented box centred on the raycast collision point.
// Works on both Forward+ and OpenGL Compatibility.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform bool cylinder_cut_occlude = false;
// Diffuse texture for the occluder. Assign the model's albedo map here.
uniform sampler2D albedo_texture : source_color, filter_linear;
// Tint multiplied over the albedo texture.
uniform vec4 albedo_color : source_color = vec4(1.0);
// Optional edge texture: maps normalised distance (0 = axis, 1 = radius) to alpha.
// Leave unassigned for the default soft/hard edge controlled by cylinder_cut_softness.
uniform sampler2D cylinder_cut_edge_texture : source_color, filter_linear, repeat_disable;

#include "cylinder_cut_common.gdshaderinc"

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb * albedo_color.rgb;
	ALPHA = 1.0;
	if (cylinder_cut_occlude) {
		vec3 world_pos = (INV_VIEW_MATRIX * vec4(VIEW, 1.0)).xyz;
		// Box volume takes priority when enabled; fall back to cylinder.
		if (cut_volume_enabled > 0.5) {
			ALPHA = cut_volume_alpha(world_pos);
		} else if (cylinder_cut_radius > 0.0) {
			ALPHA = cylinder_cut_alpha(world_pos, cylinder_cut_edge_texture);
		}
	}
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
