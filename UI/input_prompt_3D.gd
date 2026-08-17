extends Node3D
## Shows a button prompt for an action, using the icon for the player's current input device.
## Uses Input.get_joy_name() to match the connected joypad, and falls back to the mobile
## control icons on mobile devices, or keyboard and mouse icons otherwise.
## The prompt only appears while the player is inside [area].

const MODE_JOYPAD := "Joypad"
const MODE_MOBILE := "Mobile"
const MODE_KEYBOARD_MOUSE := "KeyboardMouse"

const MOBILE_ICON_BASE := "res://addons/mobile-controls-1/Vector/Icons/"
const MOBILE_ICONS := {
	&"interact": "icon_search.svg",
	&"jump": "icon_star.svg",
	&"fire0": "icon_sword.svg",
	&"fire1": "icon_target.svg",
	&"fire3": "icon_crosshair.svg",
	&"pause": "icon_pause.svg",
}

## Name of the input action to show a prompt for.
@export var action_name: StringName = &"interact"
## Which input event of the action to display (0 = first).
@export var input_number: int = 0
## The Area3D that must contain the player for the prompt to be visible.
@export var area: Area3D
## How fast the prompt scales in when it appears.
@export_range(1.0, 30.0, 0.5) var appear_speed := 10.0
## How fast the prompt scales out when it hides.
@export_range(1.0, 30.0, 0.5) var disappear_speed := 10.0
## The scale the prompt grows to while the player is in range.
@export_range(0.1, 10.0, 0.1) var max_scale := 2.0

var _mode := MODE_KEYBOARD_MOUSE
var _player_in_range := false
var _show := false
var _z_targeted := false

@onready var sprite_3d: Sprite3D = $Sprite3D

func _ready() -> void:
	InputIcons.joypad_device_changed.connect(_refresh)
	if area:
		area.body_entered.connect(_on_area_body_entered)
		area.body_exited.connect(_on_area_body_exited)
	_refresh()
	if not _show:
		sprite_3d.scale = Vector3.ZERO
		sprite_3d.visible = false

func _process(delta: float) -> void:
	_player_in_range = _z_targeted or _any_player_in_area()
	_show = sprite_3d.texture != null and (area == null or _player_in_range)
	if _show:
		sprite_3d.visible = true
		var target := Vector3.ONE * max_scale
		sprite_3d.scale = sprite_3d.scale.lerp(target, minf(1.0, delta * appear_speed))
		if sprite_3d.scale.distance_to(target) < 0.001:
			sprite_3d.scale = target
	else:
		sprite_3d.scale = sprite_3d.scale.lerp(Vector3.ZERO, minf(1.0, delta * disappear_speed))
		if sprite_3d.scale.distance_to(Vector3.ZERO) < 0.001:
			sprite_3d.scale = Vector3.ZERO
			sprite_3d.visible = false

func set_z_targeted(active: bool) -> void:
	_z_targeted = active
	_refresh()

func _any_player_in_area() -> bool:
	if area == null:
		return false
	for body in area.get_overlapping_bodies():
		if _is_player(body):
			return true
	return false

func _input(event: InputEvent) -> void:
	var device := InputEventHelper.get_input_device_name(event)
	if device == InputEventHelper.DEVICE_KEYBOARD or device == InputEventHelper.DEVICE_MOUSE:
		if _mode != MODE_KEYBOARD_MOUSE:
			_refresh()

func _refresh() -> void:
	var texture := _get_action_icon()
	sprite_3d.texture = texture
	_show = texture != null and (area == null or _player_in_range)

func _is_player(body: Node3D) -> bool:
	return body is CharacterBody3D

func _on_area_body_entered(body: Node3D) -> void:
	if _is_player(body):
		_player_in_range = true
		_refresh()

func _on_area_body_exited(body: Node3D) -> void:
	if _is_player(body):
		_player_in_range = false
		_refresh()

func _get_action_icon() -> Texture2D:
	var joypads := Input.get_connected_joypads()
	if not joypads.is_empty():
		_mode = MODE_JOYPAD
		InputIcons.last_joypad_device = _match_joy_name(Input.get_joy_name(joypads[0]))
		var joypad_event := InputEventHelper.get_action_device_event(action_name, InputEventHelper.DEVICE_JOYPAD, input_number)
		return InputIcons.get_icon(joypad_event)
	if _is_mobile():
		_mode = MODE_MOBILE
		return _get_mobile_icon()
	_mode = MODE_KEYBOARD_MOUSE
	return _get_keyboard_mouse_icon()

func _match_joy_name(joy_name: String) -> String:
	for device in InputEventHelper.SDL_DEVICE_NAMES:
		for keyword in InputEventHelper.SDL_DEVICE_NAMES[device]:
			if joy_name.containsn(keyword):
				return device
	return InputEventHelper.DEVICE_GENERIC

func _is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")

func _get_mobile_icon() -> Texture2D:
	if action_name in MOBILE_ICONS:
		return load(MOBILE_ICON_BASE + MOBILE_ICONS[action_name])
	return null

func _get_keyboard_mouse_icon() -> Texture2D:
	var keyboard_event := InputEventHelper.get_action_device_event(action_name, InputEventHelper.DEVICE_KEYBOARD, input_number)
	if keyboard_event:
		var icon := InputIcons.get_icon(keyboard_event)
		if icon:
			return icon
	var mouse_event := InputEventHelper.get_action_device_event(action_name, InputEventHelper.DEVICE_MOUSE, input_number)
	return InputIcons.get_icon(mouse_event)
