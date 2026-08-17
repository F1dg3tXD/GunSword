// Edge: Soft — smooth gradient falloff from fully cut to fully opaque.
// Drop-in replacement for the default edge function in cylinder_cut_receiver.
// Adjust the curve by modifying the smoothstep parameters below.
float cylinder_cut_edge(float norm_dist) {
	// Smooth 4th-power falloff for a gentle gradient.
	float x = clamp(norm_dist, 0.0, 1.0);
	return x * x * x * x;
}
