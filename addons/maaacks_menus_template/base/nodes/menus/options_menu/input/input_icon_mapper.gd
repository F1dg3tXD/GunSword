@tool
class_name InputIconMapper
extends FileLister

signal joypad_device_changed
signal input_map_changed

const COMMON_REPLACE_STRINGS: Dictionary = {
	"L 1": "Left Shoulder",
	"R 1": "Right Shoulder",
	"L 2": "Left Trigger",
	"R 2": "Right Trigger",
	"Lt": "Left Trigger",
	"Rt": "Right Trigger",
	"Lb": "Left Shoulder",
	"Rb": "Right Shoulder",
	"Zl": "Left Trigger",
	"Zr": "Right Trigger",
} # Dictionary[String, String]
## Gives priority to icons with occurrences of the provided strings.
@export var prioritized_strings : Array[String]
## Replaces the first occurence in icon names of the key with the value.
@export var replace_strings : Dictionary # Dictionary[String, String]
## Filters the icon names of the provided strings.
@export var filtered_strings : Array[String]
## Adds entries for "Up", "Down", "Left", "Right" to icon names ending with "Stick".
@export var add_stick_directions : bool = false
@export var intial_joypad_device : String = InputEventHelper.DEVICE_GENERIC
## Attempt to match the icon names to the input names based on the string rules.
@export var _match_icons_to_inputs_action : bool = false :
	set(value):
		if value and Engine.is_editor_hint():
			_match_icons_to_inputs()
# For Godot 4.4
# @export_tool_button("Match Icons to Inputs") var _match_icons_to_inputs_action = _match_icons_to_inputs
@export var matching_icons : Dictionary # Dictionary[String, Texture]
@export_group("Debug")
@export var all_icons : Dictionary # Dictionary[String, Texture]

@onready var last_joypad_device = intial_joypad_device

var _input_map_hash := 0

func _is_end_of_word(full_string : String, what : String) -> bool:
	var string_end_position = full_string.find(what) + what.length()
	var end_of_word : bool
	if string_end_position + 1 < full_string.length():
		var next_character = full_string.substr(string_end_position, 1)
		end_of_word = next_character == " "
	return full_string.ends_with(what) or end_of_word

func _get_standard_joy_name(joy_name : String) -> String:
	var all_replace_strings := replace_strings.duplicate()
	all_replace_strings.merge(COMMON_REPLACE_STRINGS)
	for what in all_replace_strings:
		if joy_name.contains(what) and _is_end_of_word(joy_name, what):
			var position = joy_name.find(what)
			joy_name = joy_name.erase(position, what.length())
			joy_name = joy_name.insert(position, all_replace_strings[what])
	var combined_joystick_name : Array[String] = []
	for part in joy_name.split(" "):
		if part.to_lower() in filtered_strings:
			continue
		if not part.is_empty():
			combined_joystick_name.append(part)
	joy_name = " ".join(combined_joystick_name)
	joy_name = joy_name.strip_edges()
	return joy_name

func _match_icon_to_file(file : String) -> void:
	var matching_string : String = file.get_file().get_basename()
	var icon : Texture = load(file)
	if not icon:
		return
	all_icons[matching_string] = icon
	matching_string = matching_string.capitalize()
	matching_string = _get_standard_joy_name(matching_string)
	matching_string = matching_string.strip_edges()
	if add_stick_directions and matching_string.ends_with("Stick"):
		for direction in [" Up", " Down", " Left", " Right"]:
			var direction_key : String = matching_string + direction
			if not direction_key in matching_icons:
				matching_icons[direction_key] = icon
		return
	if matching_string in matching_icons:
		return
	matching_icons[matching_string] = icon

func _prioritized_files() -> Array[String]:
	var priority_levels : Dictionary # Dictionary[String, int]
	var priortized_files : Array[String]
	for prioritized_string in prioritized_strings:
		for file in files:
			if file.containsn(prioritized_string):
				if file in priority_levels:
					priority_levels[file] += 1
				else:
					priority_levels[file] = 1
	var priority_file_map : Dictionary # Dictionary[int, Array]
	var max_priority_level : int = 0
	for file in priority_levels:
		var priority_level = priority_levels[file]
		max_priority_level = max(priority_level, max_priority_level)
		if priority_level in priority_file_map:
			priority_file_map[priority_level].append(file)
		else:
			priority_file_map[priority_level] = [file]
	while max_priority_level > 0:
		for priority_file in priority_file_map[max_priority_level]:
			priortized_files.append(priority_file)
		max_priority_level -= 1
	return priortized_files

func _match_icons_to_inputs() -> void:
	matching_icons.clear()
	all_icons.clear()
	for prioritized_file in _prioritized_files():
		_match_icon_to_file(prioritized_file)
	var sorted_files : Array[String] = files.duplicate()
	sorted_files.sort_custom(_is_direction_variant_first)
	for file in sorted_files:
		_match_icon_to_file(file)

## Directional stick icons should take priority over the undirected stick icon.
func _is_direction_variant_first(a : String, b : String) -> bool:
	return _is_direction_variant(a) and not _is_direction_variant(b)

func _is_direction_variant(file : String) -> bool:
	var name : String = file.get_file().get_basename().to_lower()
	return name.contains("stick") and (name.ends_with("_up") or name.ends_with("_down") or name.ends_with("_left") or name.ends_with("_right"))

func get_icon(input_event : InputEvent) -> Texture:
	## Generic controllers follow the Xbox 360 layout, so use the Xbox icons for them.
	var device_name : String = last_joypad_device
	if device_name == InputEventHelper.DEVICE_GENERIC:
		device_name = InputEventHelper.DEVICE_XBOX_CONTROLLER
	var device_text = InputEventHelper.get_event_device_text(input_event, device_name)
	if device_text in matching_icons:
		return matching_icons[device_text]
	## Fall back to the generic icons for anything the Xbox set does not cover.
	if device_name != last_joypad_device:
		var generic_text = InputEventHelper.get_event_device_text(input_event, last_joypad_device)
		if generic_text in matching_icons:
			return matching_icons[generic_text]
	return null

func _assign_joypad_0_to_last() -> void:
	if last_joypad_device != intial_joypad_device : return
	var connected_joypads := Input.get_connected_joypads()
	if connected_joypads.is_empty(): return
	last_joypad_device = InputEventHelper.get_joypad_device_name_by_id(connected_joypads[0])

func _input(event : InputEvent) -> void:
	var joypad_device_name = InputEventHelper.get_joypad_device_name(event)
	if joypad_device_name != InputEventHelper.DEVICE_GENERIC and joypad_device_name != last_joypad_device:
		last_joypad_device = joypad_device_name
		joypad_device_changed.emit()

func _ready() -> void:
	_assign_joypad_0_to_last()
	if files.size() == 0:
		_refresh_files()
	if matching_icons.size() == 0:
		_match_icons_to_inputs()
	_input_map_hash = _compute_input_map_hash()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		var current_hash := _compute_input_map_hash()
		if current_hash != _input_map_hash:
			_input_map_hash = current_hash
			_match_icons_to_inputs()
			input_map_changed.emit()


func _compute_input_map_hash() -> int:
	var hash_val := 0
	for action in InputMap.get_actions():
		var action_events := InputMap.action_get_events(action)
		for event in action_events:
			hash_val = hash_val * 31 + hash(action)
			if event is InputEventKey:
				hash_val = hash_val * 31 + event.physical_keycode
			elif event is InputEventJoypadButton:
				hash_val = hash_val * 31 + event.button_index
			elif event is InputEventMouse:
				hash_val = hash_val * 31 + event.button_mask
	return hash_val
