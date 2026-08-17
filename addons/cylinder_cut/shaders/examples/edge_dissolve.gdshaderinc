// Edge: Dissolve — organic noise-based edge for a "dissolving" look.
// Uses a simple hash-based noise so no texture is required.

float _cylinder_dissolve_noise(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float cylinder_cut_edge(float norm_dist) {
	// Sample noise along the cylinder axis direction and the circumference.
	// We use norm_dist as one axis and a fixed seed for the other.
	float n = _cylinder_dissolve_noise(vec2(norm_dist * 8.0, 0.5));
	// Remap: noise < threshold → cut, noise ≥ threshold → opaque.
	float threshold = 0.3;
	float band = 0.15; // width of the dissolve border
	return smoothstep(threshold - band, threshold + band, n);
}
