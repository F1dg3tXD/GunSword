class_name DialogueIconLabel extends DialogueLabel
## A DialogueLabel that replaces [input_<action>] tokens in dialogue lines with
## the icon for the player's current input device.

var _input_map_connected := false


func _update_text() -> void:
	_ensure_input_map_listener()
	if Engine.is_editor_hint():
		super._update_text()
		return
	if is_instance_valid(dialogue_line):
		var font_size := get_theme_font_size("normal_font_size")
		if font_size <= 0:
			font_size = 16
		text = InputIconText.process(dialogue_line.text, font_size * 1.5)
	else:
		text = ""


func _ensure_input_map_listener() -> void:
	if _input_map_connected:
		return
	_input_map_connected = true
	var icons := get_tree().root.get_node_or_null("InputIcons")
	if icons and icons.has_signal("input_map_changed"):
		icons.input_map_changed.connect(_on_input_map_changed)


func _on_input_map_changed() -> void:
	_update_text()
