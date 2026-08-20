extends CanvasLayer

const PlayerScript := preload("res://player/player_top_down.gd")

const ORBIT_YAW_PER_PIXEL := 0.006
const ORBIT_PITCH_PER_PIXEL := 0.004

@onready var cam_modifier: TouchScreenButton = $Control/HBoxContainer2/cam_modifier

var _drag_index := -1


func _process(_delta: float) -> void:
	var on_mobile := OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")
	if not on_mobile:
		visible = false
		return

	var scene := get_tree().current_scene
	visible = scene != null and scene.scene_file_path.begins_with("res://maps/")


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
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var camera_rig: Node3D = player.get_node("CameraRig")
	var spring_arm: SpringArm3D = player.get_node("CameraRig/SpringArm3D")
	camera_rig.rotation.y += delta_px.x * ORBIT_YAW_PER_PIXEL
	spring_arm.rotation.x = clampf(spring_arm.rotation.x + delta_px.y * ORBIT_PITCH_PER_PIXEL, PlayerScript.CAM_PITCH_MIN, PlayerScript.CAM_PITCH_MAX)
