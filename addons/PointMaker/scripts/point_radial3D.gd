@tool
extends Area3D
class_name PointRadial3D

signal value_changed(value: float)
signal value_set(value: float)

@export var knob_path: NodePath
@export var min_angle: float = -135.0
@export var max_angle: float = 135.0
@export var use_limits: bool = true
@export var start_value: float = 0.5
@export var step: float = 0.0  # Set to > 0.0 for snapping (e.g. 0.1 for 10 steps)

var _dragging := false
var _value := start_value

func _ready():
	input_pickable = true
	_value = _apply_step(clamp(start_value, 0.0, 1.0))
	_update_knob_angle()

	if not has_node("CollisionShape3D") and not has_node("CollisionPolygon3D"):
		push_warning("⚠ PointRadial3D requires a CollisionShape3D or CollisionPolygon3D to detect mouse interaction.")

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			get_viewport().set_input_as_handled()
		else:
			if _dragging:
				_dragging = false
				emit_signal("value_set", _value)

func _process(delta):
	if _dragging:
		var cam = get_viewport().get_camera_3d()
		if cam:
			var mouse_pos = get_viewport().get_mouse_position()
			var ray_origin = cam.project_ray_origin(mouse_pos)
			var ray_dir = cam.project_ray_direction(mouse_pos)
			# Project onto XZ plane (y = body's y)
			var hit_point = ray_origin + ray_dir * 1000.0
			hit_point.y = global_position.y
			var dir = global_position.direction_to(hit_point)
			var deg = dir.angle_to(Vector3(1, 0, 0))
			if deg < 0.0:
				deg += 2 * PI
			
			var new_value: float
			if use_limits:
				var clamped = clamp(deg, rad_to_deg(min_angle), rad_to_deg(max_angle))
				new_value = inverse_lerp(rad_to_deg(min_angle), rad_to_deg(max_angle), clamped)
			else:
				new_value = deg / (2 * PI)
			
			new_value = _apply_step(clamp(new_value, 0.0, 1.0))
			
			if not is_equal_approx(new_value, _value):
				_value = new_value
				_update_knob_angle()
				emit_signal("value_changed", _value)

func _apply_step(v: float) -> float:
	return round(v / step) * step if step > 0.0 else v

func _update_knob_angle():
	var knob = get_node_or_null(knob_path)
	if knob:
		var angle_deg = lerp(min_angle, max_angle, _value) if use_limits else _value * 360.0
		knob.rotation_degrees = Vector3.UP * angle_deg