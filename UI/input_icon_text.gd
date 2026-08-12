class_name InputIconText
## Replaces [input_<action>] tokens in text with inline icons for the player's
## current input device. Used by the dialogue balloon to show button prompts.

const MOBILE_ICON_BASE := "res://addons/mobile-controls-1/Vector/Icons/"
const MOBILE_ICONS := {
	&"interact": "icon_search.svg",
	&"jump": "icon_star.svg",
	&"fire0": "icon_sword.svg",
	&"fire1": "icon_target.svg",
	&"fire3": "icon_crosshair.svg",
	&"pause": "icon_pause.svg",
}

const ICON_WIDTH := 24
const ICON_HEIGHT := 24


static func process(text: String) -> String:
	if not "[input_" in text:
		return text
	var regex := RegEx.create_from_string(r"\[input_([A-Za-z0-9_]+)\]")
	var result := text
	for match in regex.search_all(text):
		result = result.replace(match.get_string(), _icon_bbcode(match.get_string(1)))
	return result


static func _icon_bbcode(action: String) -> String:
	var icon := _get_action_icon(StringName(action))
	if icon == null:
		return action
	var path := icon.resource_path
	if path.is_empty():
		return action
	return "[img width=%d height=%d]%s[/img]" % [ICON_WIDTH, ICON_HEIGHT, path]


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
	if action_name in MOBILE_ICONS:
		return load(MOBILE_ICON_BASE + MOBILE_ICONS[action_name])
	return null
