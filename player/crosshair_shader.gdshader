shader_type canvas_item;

uniform vec4 modulate_color : source_color = vec4(1.0);
uniform float outline_width : hint_range(0.0, 4.0, 1.0) = 1.0;

void fragment() {
	vec4 center = texture(TEXTURE, UV);
	vec2 px = 1.0 / vec2(textureSize(TEXTURE, 0));
	float max_alpha = center.a;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			if (x == 0 && y == 0) continue;
			max_alpha = max(max_alpha, texture(TEXTURE, UV + vec2(float(x), float(y)) * px * outline_width).a);
		}
	}
	if (max_alpha > 0.0 && center.a < 0.01) {
		COLOR = vec4(0.0, 0.0, 0.0, max_alpha);
	} else {
		COLOR = center * modulate_color;
	}
}
