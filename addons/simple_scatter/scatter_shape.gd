@tool
extends CollisionShape3D

signal changed()

var randomGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	if shape:
		shape.changed.connect(changed.emit)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		changed.emit()


func get_random_position() -> Vector3:
	if not shape:
		return global_position

	var local_point := Vector3.ZERO

	if shape is CylinderShape3D:
		var cyl := shape as CylinderShape3D
		var angle := randomGenerator.randf_range(0.0, TAU)
		var r: float = cyl.radius * sqrt(randomGenerator.randf())
		local_point = Vector3(cos(angle) * r, 0.0, sin(angle) * r)

	elif shape is BoxShape3D:
		var box := shape as BoxShape3D
		var ext: Vector3 = box.size * 0.5
		local_point = Vector3(
			randomGenerator.randf_range(-ext.x, ext.x),
			randomGenerator.randf_range(-ext.y, ext.y),
			randomGenerator.randf_range(-ext.z, ext.z)
		)

	elif shape is SphereShape3D:
		var sph := shape as SphereShape3D
		var theta := randomGenerator.randf_range(0.0, TAU)
		var phi := acos(randomGenerator.randf_range(-1.0, 1.0))
		var r: float = sph.radius * pow(randomGenerator.randf(), 1.0 / 3.0)
		local_point = Vector3(
			r * sin(phi) * cos(theta),
			r * sin(phi) * sin(theta),
			r * cos(phi)
		)

	else:
		return global_position

	return global_transform * local_point


func get_vertical_half_extent() -> float:
	if not shape:
		return 50.0

	if shape is BoxShape3D:
		return (shape as BoxShape3D).size.y * 0.5

	if shape is CylinderShape3D:
		return (shape as CylinderShape3D).height * 0.5

	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius

	return 50.0
