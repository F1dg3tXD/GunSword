extends CanvasLayer

const PlayerScript := preload("res://player/player_top_down.gd")

const ORBIT_YAW_PER_PIXEL := 0.006
const ORBIT_PITCH_PER_PIXEL := 0.004

## Design resolution the controls were laid out against. Positions of the
## controls are redistributed proportionally to the actual device screen from
## here, so a wider screen spreads them further apart while their rendered size
## (and therefore the icons) stays unchanged.
const DESIGN_SIZE := Vector2(1152, 648)

@onready var cam_modifier: TouchScreenButton = $Control/HBoxContainer2/cam_modifier
@onready var root_control: Control = $Control

## design-space rect of each top-level control (captured once).
var _design_rects: Dictionary = {}
var _last_ratio := Vector2.ZERO

var _drag_index := -1


func _process(_delta: float) -> void:
	var on_mobile := OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")
	if not on_mobile:
		visible = false
		return

	var scene := get_tree().current_scene
	visible = scene != null and scene.scene_file_path.begins_with("res://maps/")
	if not visible:
		return

	_apply_layout()


## Moves each top-level control to the design-fraction of the current screen,
## leaving its size untouched so the icons are never stretched.
func _apply_layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	if screen.x <= 0.0 or screen.y <= 0.0:
		return
	var ratio := screen / DESIGN_SIZE
	if ratio.is_equal_approx(_last_ratio):
		return

	if _design_rects.is_empty():
		for child in root_control.get_children():
			if child is Control:
				_design_rects[child] = child.get_rect()

	for child in _design_rects:
		if not is_instance_valid(child):
			continue
		var design_rect: Rect2 = _design_rects[child]
		child.set_anchors_preset(Control.PRESET_TOP_LEFT)
		child.position = Vector2(design_rect.position.x * ratio.x, design_rect.position.y * ratio.y)
		child.size = design_rect.size

	_last_ratio = ratio


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _drag_index == -1 and cam_modifier.is_pressed():
				_drag_index = event.index
		elif event.index == _drag_index:
			_drag_index = -1
	elif event is InputEventScreenDrag:
		if event.index == _drag_index:
			_orbit(event.relative)
		elif _drag_index == -1 and cam_modifier.is_pressed():
			_drag_index = event.index
			_orbit(event.relative)


func _orbit(delta_px: Vector2) -> void:
	if get_tree().get_first_node_in_group("dialogue_balloon") != null:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var camera_rig: Node3D = player.get_node("CameraRig")
	var spring_arm: SpringArm3D = player.get_node("CameraRig/SpringArm3D")
	camera_rig.rotation.y += delta_px.x * ORBIT_YAW_PER_PIXEL
	spring_arm.rotation.x = clampf(spring_arm.rotation.x + delta_px.y * ORBIT_PITCH_PER_PIXEL, PlayerScript.CAM_PITCH_MIN, PlayerScript.CAM_PITCH_MAX)
