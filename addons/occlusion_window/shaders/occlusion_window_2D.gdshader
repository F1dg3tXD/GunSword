// Occlusion Window — 2D receiver shader.
// Assign as the material shader of 2D occluders (Sprite2D, AnimatedSprite2D,
// TileMapLayer cells, ...) and enable the `occlusion_window_occlude` uniform on those
// that should thin out in front of the player. The cut is per fragment in screen space,
// so it applies to any canvas item this material is used on. Works on both the Forward+
// and the OpenGL Compatibility renderers.
shader_type canvas_item;

uniform bool occlusion_window_occlude = false;

varying float window_item_y;

#include "occlusion_window_common.gdshaderinc"

void vertex() {
	// This item's y-sort depth line: its origin in canvas space. Computed in vertex()
	// because MODEL_MATRIX is not exposed to fragment() on the Compatibility renderer.
	window_item_y = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).y;
}

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	if (occlusion_window_occlude) {
		color.a *= 1.0 - occlusion_window_cut_2d(SCREEN_UV, window_item_y);
	}
	COLOR = color;
}
