// Edge: Ring — concentric sine-wave rings along the cut distance.
// Creates a scanner / ripple effect at the cylinder boundary.
// Adjust `ring_count` and `ring_width` to taste.

float cylinder_cut_edge(float norm_dist) {
	const float ring_count = 6.0;   // number of rings
	const float ring_width = 0.12;  // softness of each ring
	float x = clamp(norm_dist, 0.0, 1.0);
	// Base smoothstep fade from center to edge.
	float base = smoothstep(0.7, 1.0, x);
	// Sine-wave modulation at the boundary.
	float wave = sin(x * ring_count * 6.2832) * 0.5 + 0.5;
	// Only modulate near the edge (0.5..1.0 range).
	float edge_zone = smoothstep(0.5, 0.8, x);
	return mix(base, base * wave, edge_zone * ring_width);
}
