// Edge: Hard — sharp boolean cut with no blending.
// Geometry is either fully transparent (inside) or fully opaque (outside).
// The optional `hard_edge_width` controls a thin anti-aliased border (0 = pixel-perfect).
float cylinder_cut_edge(float norm_dist) {
	const float hard_edge_width = 0.02;
	return smoothstep(1.0 - hard_edge_width, 1.0, norm_dist);
}
