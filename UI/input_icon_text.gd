class_name InputIconText
## Replaces [input_<action>] tokens in text with inline icons for the player's
## current input device. Used by the dialogue balloon to show button prompts.
## On mobile, icons are pulled live from the TouchScreenButton nodes so they
## always match whatever the on-screen controls are set to.

const ICON_DEFAULT_SIZE := 24

static var _mobile_button_cache: Dictionary = {}
static var _connected := false


static func _ensure_connected() -> void:
	if _connected:
		return
	_connected = true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	# Connect to InputIcons singleton to invalidate cache on input map changes.
	var icons := tree.root.get_node_or_null("InputIcons")
	if icons and icons.has_signal("input_map_changed"):
		icons.input_map_changed.connect(_on_input_map_changed)


static func _on_input_map_changed() -> void:
	_mobile_button_cache.clear()


static func process(text: String, icon_size: int = ICON_DEFAULT_SIZE) -> String:
	_ensure_connected()
	if not "[input_" in text:
		return text
	var regex := RegEx.create_from_string(r"\[input_([A-Za-z0-9_]+)\]")
	var result := text
	for match in regex.search_all(text):
		result = result.replace(match.get_string(), _icon_bbcode(match.get_string(1), icon_size))
	return result


static func _icon_bbcode(action: String, icon_size: int) -> String:
	var icon := _get_action_icon(StringName(action))
	if icon == null:
		return action
	var path := icon.resource_path
	if path.is_empty():
		return action
	return "[img width=%d height=%d]%s[/img]" % [icon_size, icon_size, path]


static func _get_action_icon(action_name: StringName) -> Texture2D:
	var joypads := Input.get_connected_joypads()
	if not joypads.is_empty():
		InputIcons.last_joypad_device = _match_joy_name(Input.get_joy_name(joypads[0]))
		var joypad_event := InputEventHelper.get_action_device_event(action_name, InputEventHelper.DEVICE_JOYPAD, 0)
		if joypad_event:
			var icon := InputIcons.get_icon(joypad_event)
			if icon:
				return icon
	if _is_mobile():
		return _get_mobile_icon(action_name)
	var keyboard_event := InputEventHelper.get_action_device_event(action_name, InputEventHelper.DEVICE_KEYBOARD, 0)
	if keyboard_event:
		var icon := InputIcons.get_icon(keyboard_event)
		if icon:
			return icon
	var mouse_event := InputEventHelper.get_action_device_event(action_name, InputEventHelper.DEVICE_MOUSE, 0)
	return InputIcons.get_icon(mouse_event)


static func _match_joy_name(joy_name: String) -> String:
	for device in InputEventHelper.SDL_DEVICE_NAMES:
		for keyword in InputEventHelper.SDL_DEVICE_NAMES[device]:
			if joy_name.containsn(keyword):
				return device
	return InputEventHelper.DEVICE_GENERIC


static func _is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")


static func _get_mobile_icon(action_name: StringName) -> Texture2D:
	# Invalidate cache if any entry became freed (scene change, etc.)
	if not _mobile_button_cache.is_empty():
		var first_key: StringName = _mobile_button_cache.keys()[0]
		if not is_instance_valid(_mobile_button_cache[first_key]):
			_mobile_button_cache.clear()

	if _mobile_button_cache.is_empty():
		_build_mobile_cache()

	if action_name in _mobile_button_cache:
		var btn: TouchScreenButton = _mobile_button_cache[action_name]
		if is_instance_valid(btn):
			return btn.texture_normal
		_mobile_button_cache.erase(action_name)
	return null


static func _build_mobile_cache() -> void:
	_mobile_button_cache.clear()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_collect_touch_buttons(tree.root)


static func _collect_touch_buttons(node: Node) -> void:
	if node is TouchScreenButton and not node.action.is_empty():
		_mobile_button_cache[node.action] = node
	for child in node.get_children():
		_collect_touch_buttons(child)
