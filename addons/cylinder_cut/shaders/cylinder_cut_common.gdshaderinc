// Cut-through — shared receiver cut math.
// Included by cylinder_cut_receiver.gdshader.
// Uses only features that work on both Forward+ and OpenGL Compatibility.
// Supports two cut modes: cylinder (legacy) and box volume (raycast-driven).

// ── Cylinder mode globals (legacy) ──────────────────────────────────────────
global uniform vec3 cylinder_cut_a;
global uniform vec3 cylinder_cut_b;
global uniform float cylinder_cut_radius;
global uniform float cylinder_cut_softness;
global uniform float cylinder_cut_edge_tex_on;

// ── Box cut-volume globals (raycast-driven) ─────────────────────────────────
// cut_volume_enabled > 0.5 activates the box volume check.
global uniform float cut_volume_enabled;
global uniform vec3  cut_volume_center;
global uniform vec3  cut_volume_forward;
global uniform vec3  cut_volume_size;   // half-extents (width, height, depth)
global uniform float cut_volume_softness;

// ── Cylinder edge ───────────────────────────────────────────────────────────
float cylinder_cut_edge(float norm_dist) {
	return smoothstep(max(1.0 - cylinder_cut_softness, 0.0001), 1.0, norm_dist);
}

float cylinder_cut_alpha(vec3 world_pos, sampler2D edge_tex) {
	if (cylinder_cut_radius <= 0.0) {
		return 1.0;
	}
	vec3 ab = cylinder_cut_b - cylinder_cut_a;
	float ab_len_sq = dot(ab, ab);
	if (ab_len_sq < 0.0001) {
		return 1.0;
	}
	vec3 ap = world_pos - cylinder_cut_a;
	float t = clamp(dot(ap, ab) / ab_len_sq, 0.0, 1.0);
	vec3 closest = cylinder_cut_a + t * ab;
	float dist = length(world_pos - closest);
	float norm_dist = dist / cylinder_cut_radius;

	float alpha;
	if (cylinder_cut_edge_tex_on > 0.5) {
		alpha = texture(edge_tex, vec2(clamp(norm_dist, 0.0, 1.0), 0.0)).r;
	} else {
		alpha = cylinder_cut_edge(norm_dist);
	}
	return clamp(alpha, 0.0, 1.0);
}

// ── Box cut-volume ──────────────────────────────────────────────────────────
// Returns 0.0 for fully cut (inside box), 1.0 for fully opaque (outside).
// The box is oriented along `cut_volume_forward` with half-extents stored in
// `cut_volume_size` as (width, height, depth) where width is along the
// right axis, height along up, and depth along forward.
float cut_volume_alpha(vec3 world_pos) {
	if (cut_volume_enabled < 0.5) {
		return 1.0;
	}
	vec3 fwd = normalize(cut_volume_forward);
	// Build an orthonormal basis from forward + world-up.
	vec3 world_up = vec3(0.0, 1.0, 0.0);
	// If forward is nearly parallel to world-up, use world-z instead.
	vec3 right = normalize(cross(fwd, world_up));
	if (length(right) < 0.001) {
		right = normalize(cross(fwd, vec3(0.0, 0.0, 1.0)));
	}
	vec3 up = normalize(cross(right, fwd));

	vec3 to_frag = world_pos - cut_volume_center;
	// Project into box-local axes.
	float r = dot(to_frag, right);
	float h = dot(to_frag, up);
	float d = dot(to_frag, fwd);

	vec3 half_ext = cut_volume_size;
	vec3 abs_local = vec3(abs(r), abs(h), abs(d));

	// Signed distance from box surface (negative = inside).
	vec3 sd = half_ext - abs_local;
	float min_sd = min(sd.x, min(sd.y, sd.z));

	// Smooth transition across the softness width.
	float blend = cut_volume_softness * min(half_ext.x, min(half_ext.y, half_ext.z));
	blend = max(blend, 0.001);
	return clamp(smoothstep(-blend, blend, min_sd), 0.0, 1.0);
}
