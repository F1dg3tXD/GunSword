@tool
extends CharacterBody3D
class_name PointDrag3D

signal drag_started
signal drag_moved(new_position: Vector3)
signal drag_ended

@export var gravity_enabled := false
@export var gravity_velocity := 500.0

var _dragging := false
var _drag_offset := Vector3.ZERO

const POINT_DRAG_LAYER := 1 << 1  # Layer 2

func _ready():
	if not has_node("CollisionShape3D") and not has_node("CollisionPolygon3D"):
		push_warning("⚠ PointDrag3D requires a CollisionShape3D or CollisionPolygon3D to detect dragging.")

	# Set to layer 2
	collision_layer = POINT_DRAG_LAYER

	# Mask excludes layer 2, includes everything else by default (just unset layer 2)
	collision_mask = 0xffffffff & ~POINT_DRAG_LAYER

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			var cam = get_viewport().get_camera_3d()
			if cam:
				var mouse_pos = get_viewport().get_mouse_position()
				var ray_origin = cam.project_ray_origin(mouse_pos)
				var ray_dir = cam.project_ray_direction(mouse_pos)
				var max_dist = 1000.0
				var hit_point = ray_origin + ray_dir * max_dist
				_drag_offset = hit_point - global_position
			else:
				_drag_offset = Vector3.ZERO
			velocity = Vector3.ZERO
			emit_signal("drag_started")
		elif _dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_dragging = false
			velocity = Vector3.ZERO
			emit_signal("drag_ended")

func _physics_process(delta):
	if _dragging:
		var cam = get_viewport().get_camera_3d()
		if cam:
			var mouse_pos = get_viewport().get_mouse_position()
			var ray_origin = cam.project_ray_origin(mouse_pos)
			var ray_dir = cam.project_ray_direction(mouse_pos)
			var max_dist = 1000.0
			var hit_point = ray_origin + ray_dir * max_dist
			var target: Vector3 = hit_point - _drag_offset
			var motion: Vector3 = target - global_position
			velocity = motion / delta
	else:
		if gravity_enabled:
			velocity.y += gravity_velocity * delta
		else:
			velocity = Vector3.ZERO

	move_and_slide()

	if _dragging:
		emit_signal("drag_moved", global_position)