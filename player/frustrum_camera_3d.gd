@tool
extends Camera3D

@export var update_interval: float = 0.1
@export var margin: float = 1.0
@export var enabled: bool = true

var _cullables: Array[VisualInstance3D] = []
var _timer: float = 0.0


func _ready() -> void:
	refresh_cullables()


func _process(delta: float) -> void:
	if not enabled:
		return
	_timer += delta
	if _timer >= update_interval:
		_timer = 0.0
		_perform_frustum_cull()


func refresh_cullables() -> void:
	_cullables.clear()
	_find_cullables(get_tree().root)


func _find_cullables(node: Node) -> void:
	if node is GeometryInstance3D and node != self:
		_cullables.append(node)
	for child in node.get_children():
		_find_cullables(child)


func _perform_frustum_cull() -> void:
	var frustum := get_frustum()
	var cam_pos := global_position

	for vi in _cullables:
		if not is_instance_valid(vi):
			continue
		if not vi.has_method("get_global_aabb"):
			continue

		var aabb: AABB = vi.get_global_aabb()

		if aabb == AABB():
			continue

		aabb = aabb.grow(margin)

		if aabb.has_point(cam_pos):
			vi.visible = true
			continue

		var outside := false
		for plane in frustum:
			if _is_aabb_outside_plane(aabb, plane):
				outside = true
				break

		vi.visible = not outside


func _is_aabb_outside_plane(aabb: AABB, plane: Plane) -> bool:
	var positive := Vector3(
		aabb.position.x if plane.normal.x >= 0 else aabb.end.x,
		aabb.position.y if plane.normal.y >= 0 else aabb.end.y,
		aabb.position.z if plane.normal.z >= 0 else aabb.end.z
	)
	return plane.distance_to(positive) < 0
