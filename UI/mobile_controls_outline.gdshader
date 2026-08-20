shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int outline_size : hint_range(1, 5) = 2;

void fragment() {
	vec2 ps = 1.0 / vec2(textureSize(TEXTURE, 0));
	vec4 tex = texture(TEXTURE, UV);

	float outer_alpha = 0.0;

	for (int x = -outline_size; x <= outline_size; x++) {
		for (int y = -outline_size; y <= outline_size; y++) {
			vec2 offset = vec2(float(x), float(y)) * ps;
			float a = texture(TEXTURE, UV + offset).a;
			outer_alpha = max(outer_alpha, a);
		}
	}

	if (tex.a < 0.5 && outer_alpha > 0.5) {
		COLOR = vec4(outline_color.rgb, outline_color.a);
	} else {
		COLOR = tex;
	}
}
