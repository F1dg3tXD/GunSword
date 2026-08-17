shader_type canvas_item;

uniform vec4 modulate_color : source_color = vec4(1.0);

void fragment() {
	COLOR = texture(TEXTURE, UV) * modulate_color;
}
