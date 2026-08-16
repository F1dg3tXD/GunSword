// Occlusion Window — shared receiver cut math.
// Included by occlusion_window_2D.gdshader (canvas items) and
// occlusion_window_3D.gdshader (spatial geometry). Uses only features that work on
// both the Forward+ and the OpenGL Compatibility renderers.

// The two screen-space slots driven each frame by OcclusionWindow2D / OcclusionWindow3D.
// A slot is active only while its radius is greater than zero (the components zero it to
// disable the window).
global uniform vec2 occlusion_window_a_center;
global uniform vec2 occlusion_window_a_radius;
global uniform float occlusion_window_a_softness;
global uniform float occlusion_window_a_depth;
global uniform float occlusion_window_a_fade;
global uniform vec2 occlusion_window_b_center;
global uniform vec2 occlusion_window_b_radius;
global uniform float occlusion_window_b_softness;
global uniform float occlusion_window_b_depth;
global uniform float occlusion_window_b_fade;

// 2D y-sort convention (larger canvas Y is drawn in front): the reveal grows from 0 at
// `depth` to full at `depth + fade` canvas units, and the window's radius scales with it,
// so occluders just in front of the character barely thin while deeper ones open fully.
float _occlusion_window_slot_2d(vec2 uv, float item_y,
		vec2 center, vec2 radius, float softness, float depth, float fade) {
	if (radius.x <= 0.0) {
		return 0.0;
	}
	float reveal = clamp((item_y - depth) / max(fade, 0.0001), 0.0, 1.0);
	if (reveal <= 0.0) {
		return 0.0;
	}
	vec2 effective_radius = radius * reveal;
	float dist = length((uv - center) / max(effective_radius, vec2(0.0001)));
	float cut = 1.0 - smoothstep(max(1.0 - softness, 0.0001), 1.0, dist);
	return cut;
}

float occlusion_window_cut_2d(vec2 uv, float item_y) {
	float cut = _occlusion_window_slot_2d(uv, item_y,
			occlusion_window_a_center, occlusion_window_a_radius,
			occlusion_window_a_softness, occlusion_window_a_depth, occlusion_window_a_fade);
	cut += _occlusion_window_slot_2d(uv, item_y,
			occlusion_window_b_center, occlusion_window_b_radius,
			occlusion_window_b_softness, occlusion_window_b_depth, occlusion_window_b_fade);
	return clamp(cut, 0.0, 1.0);
}

// 3D camera-relative convention (view depth = positive distance from the camera plane):
// a fragment in front of the target (smaller view depth) is revealed; the reveal grows
// from 0 at `depth` to full at `depth - fade` (fade units closer to the camera).
float _occlusion_window_slot_3d(vec2 uv, float view_depth,
		vec2 center, vec2 radius, float softness, float depth, float fade) {
	if (radius.x <= 0.0) {
		return 0.0;
	}
	float reveal = clamp((depth - view_depth) / max(fade, 0.0001), 0.0, 1.0);
	if (reveal <= 0.0) {
		return 0.0;
	}
	vec2 effective_radius = radius * reveal;
	float dist = length((uv - center) / max(effective_radius, vec2(0.0001)));
	float cut = 1.0 - smoothstep(max(1.0 - softness, 0.0001), 1.0, dist);
	return cut;
}

float occlusion_window_cut_3d(vec2 uv, float view_depth) {
	float cut = _occlusion_window_slot_3d(uv, view_depth,
			occlusion_window_a_center, occlusion_window_a_radius,
			occlusion_window_a_softness, occlusion_window_a_depth, occlusion_window_a_fade);
	cut += _occlusion_window_slot_3d(uv, view_depth,
			occlusion_window_b_center, occlusion_window_b_radius,
			occlusion_window_b_softness, occlusion_window_b_depth, occlusion_window_b_fade);
	return clamp(cut, 0.0, 1.0);
}
