@tool
extends Node3D
class_name Scatter

@export var objects: Array[PackedScene]:
	set(value):
		objects = value
		_refresh()

@export var amount := 10:
	set(value):
		amount = value
		_refresh()

@export_range(0.0, 1.0) var randomScale := 0.0:
	set(value):
		randomScale = value
		_refresh()

@export var scatterSeed := 0:
	set(value):
		scatterSeed = value
		_refresh()

@export var use_all_normals := false:
	set(value):
		use_all_normals = value
		_refresh()

@export_range(0.0, TAU) var random_rotation_delta := 0.0:
	set(value):
		random_rotation_delta = value
		_refresh()

var objects_container: Node3D
var collision_shape: CollisionShape3D
var random_generator := RandomNumberGenerator.new()


func _ready() -> void:
	_ensure_container()
	_find_collision_shape()
	child_entered_tree.connect(_on_child_entered_tree)
	_refresh()


func _ensure_container() -> void:
	objects_container = get_node_or_null("objectsContainer") as Node3D
	if not objects_container:
		objects_container = Node3D.new()
		objects_container.name = &"objectsContainer"
		add_child(objects_container)
		if Engine.is_editor_hint():
			objects_container.owner = get_tree().edited_scene_root


func _find_collision_shape() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			collision_shape = child as CollisionShape3D
			return


func _on_child_entered_tree(node: Node) -> void:
	if node is CollisionShape3D:
		collision_shape = node as CollisionShape3D


func _refresh() -> void:
	if not is_node_ready():
		return

	if not objects_container:
		return

	for child in objects_container.get_children():
		child.queue_free()

	if not collision_shape:
		return

	if not collision_shape.shape:
		return

	if objects.is_empty():
		return

	_set_random_seed()
	_set_objects()


func _set_random_seed() -> void:
	seed(scatterSeed)
	random_generator.set_seed(scatterSeed)


func _set_objects() -> void:
	for i in amount:
		if objects.is_empty():
			break

		var scene: PackedScene = objects.pick_random()
		if not scene:
			continue

		var random_object = scene.instantiate()
		var random_position = collision_shape.get_random_position()
		var hit = _get_surface_position(random_position)

		if not hit:
			random_object.queue_free()
			continue

		var pos: Vector3 = hit.position
		var normal: Vector3 = hit.normal

		if not use_all_normals and normal.dot(Vector3.UP) < 0.5:
			random_object.queue_free()
			continue

		objects_container.add_child(random_object)
		random_object.global_position = pos

		if random_rotation_delta > 0.0:
			var angle := random_generator.randf_range(-random_rotation_delta, random_rotation_delta)
			random_object.rotate(normal.normalized(), angle)

		if randomScale > 0.0:
			var s := random_generator.randf_range(1.0 - randomScale, 1.0)
			random_object.scale = Vector3.ONE * s

		if Engine.is_editor_hint():
			random_object.owner = get_tree().edited_scene_root


func _get_surface_position(origin: Vector3) -> Variant:
	var half_ext: float = collision_shape.get_vertical_half_extent()
	var params := PhysicsRayQueryParameters3D.new()
	params.from = Vector3(origin.x, origin.y + half_ext, origin.z)
	params.to = Vector3(origin.x, origin.y - half_ext, origin.z)

	var space_state := get_world_3d().direct_space_state
	var result := space_state.intersect_ray(params)

	if result:
		return {"position": result.position, "normal": result.normal}
	return null
