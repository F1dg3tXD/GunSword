extends AreaLight3D

const LASER_RADIUS := 0.6


func update_light(length: float, start_pos: Vector3, direction: Vector3) -> void:
	if length < 0.01 or direction.length_squared() < 0.001:
		visible = false
		return

	visible = true
	area_size = Vector2(LASER_RADIUS, length)

	# Local X = vertical (thickness), local Y = beam direction (length),
	# local Z = horizontal perpendicular (emission outward, not into ground).
	var beam := direction.normalized()
	var right := beam.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.001:
		right = beam.cross(Vector3.FORWARD).normalized()
	var up := right.cross(beam).normalized()
	global_transform.basis = Basis(up, beam, right)

	# area_size extends from (0,0) to (size.x, size.y) in local space,
	# so its center is at (size.x/2, size.y/2, 0).  Offset the node
	# origin so that the area's visual center lands on the beam midpoint.
	var local_center := Vector3(area_size.x * 0.5, area_size.y * 0.5, 0.0)
	global_position = (start_pos + beam * length * 0.5) - (global_transform.basis * local_center)
