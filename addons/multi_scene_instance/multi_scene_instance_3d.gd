@tool
extends Node3D
class_name MultiSceneInstance3D
## Instances a collection of PackedScenes into frustum-culled MultiMeshes.
##
## The root node is a plain container. Each entry in [member scenes] is baked
## into its own MultiMeshInstance3D child (one multimesh per scene). Every
## child Node3D marker placed under this node becomes one instance rendered by
## the multimesh. Off-screen scene collections are therefore culled as a single
## draw call rather than as many individual scene instances.

## The collection of scenes to repeat. One MultiMeshInstance3D is built per scene.
@export var scenes: Array[PackedScene] = []:
	set(value):
		scenes = value
		_refresh()

@export var cast_shadow: int = 0:
	# 0 == GeometryInstance3D.SHADOW_CASTING_OFF
	set(value):
		cast_shadow = value
		_apply_shadow_settings()

var multimesh_instances: Array[MultiMeshInstance3D] = []


func _ready() -> void:
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_refresh()


func _refresh() -> void:
	_clear_multimeshes()
	if scenes.is_empty():
		return

	var place_transforms := _get_placements()
	if place_transforms.is_empty():
		return

	for scene in scenes:
		if scene == null:
			continue
		var mesh := _bake_scene_mesh(scene)
		if mesh == null:
			continue

		var mmi := MultiMeshInstance3D.new()
		mmi.name = &"MultiMesh_%s" % scene.resource_path.get_file().get_basename()
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = place_transforms.size()
		mmi.multimesh = multimesh
		mmi.cast_shadow = cast_shadow
		add_child(mmi)
		multimesh_instances.append(mmi)

		for i in place_transforms.size():
			multimesh.set_instance_transform(i, place_transforms[i])
		if Engine.is_editor_hint():
			mmi.owner = get_tree().edited_scene_root


func _clear_multimeshes() -> void:
	for mmi in multimesh_instances:
		if is_instance_valid(mmi):
			mmi.queue_free()
	multimesh_instances.clear()


func _apply_shadow_settings() -> void:
	for mmi in multimesh_instances:
		if is_instance_valid(mmi):
			mmi.cast_shadow = cast_shadow


## Returns the transforms of all child Node3D markers used as placements.
func _get_placements() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for child in get_children():
		if child is Node3D and not (child is MultiMeshInstance3D):
			transforms.append((child as Node3D).transform)
	return transforms


## Flattens all mesh and sprite geometry in a packed scene into a single ArrayMesh.
func _bake_scene_mesh(scene: PackedScene) -> ArrayMesh:
	var root: Node = scene.instantiate()
	var mesh := ArrayMesh.new()
	var added_surface := false

	var stack: Array[Node] = [root]
	var guard := 0
	while not stack.is_empty() and guard < 100000:
		guard += 1
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi: MeshInstance3D = node as MeshInstance3D
			if mi.mesh != null:
				_append_mesh(mesh, mi.mesh, mi.global_transform)
				added_surface = true
		elif node is Sprite3D:
			var quad := _sprite_quad(node as Sprite3D)
			if quad != null:
				_append_mesh(mesh, quad, (node as Sprite3D).global_transform)
				added_surface = true
		for c in node.get_children():
			stack.append(c)

	root.free()

	if not added_surface:
		return null
	return mesh


func _append_mesh(target: ArrayMesh, source: Mesh, transform: Transform3D) -> void:
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var vtx: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if vtx.is_empty():
			continue
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			idx = PackedInt32Array()
			idx.resize(vtx.size())
			for i in vtx.size():
				idx[i] = i
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]

		var new_vtx := PackedVector3Array()
		new_vtx.resize(vtx.size())
		for i in vtx.size():
			new_vtx[i] = transform * vtx[i]
		var new_normals := PackedVector3Array()
		if normals.size() == vtx.size():
			new_normals.resize(normals.size())
			var basis := transform.basis
			for i in normals.size():
				new_normals[i] = (basis * normals[i]).normalized()
		var new_uvs := PackedVector2Array(uvs) if uvs.size() == vtx.size() else PackedVector2Array()
		var new_colors := PackedColorArray(colors) if colors.size() == vtx.size() else PackedColorArray()

		var new_arrays := []
		new_arrays.resize(Mesh.ARRAY_MAX)
		new_arrays[Mesh.ARRAY_VERTEX] = new_vtx
		new_arrays[Mesh.ARRAY_INDEX] = idx
		if not new_normals.is_empty():
			new_arrays[Mesh.ARRAY_NORMAL] = new_normals
		if not new_uvs.is_empty():
			new_arrays[Mesh.ARRAY_TEX_UV] = new_uvs
		if not new_colors.is_empty():
			new_arrays[Mesh.ARRAY_COLOR] = new_colors
		target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)


## Builds a camera-facing quad mesh for a Sprite3D from its texture.
func _sprite_quad(spr: Sprite3D) -> ArrayMesh:
	var tex := spr.texture
	if tex == null:
		return null
	var size := spr.get_item_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(Vector3(-size.x * 0.5, -size.y * 0.5, 0.0))
	st.set_uv(Vector2(1, 0))
	st.add_vertex(Vector3(size.x * 0.5, -size.y * 0.5, 0.0))
	st.set_uv(Vector2(1, 1))
	st.add_vertex(Vector3(size.x * 0.5, size.y * 0.5, 0.0))
	st.set_uv(Vector2(0, 1))
	st.add_vertex(Vector3(-size.x * 0.5, size.y * 0.5, 0.0))
	st.add_index(0)
	st.add_index(1)
	st.add_index(2)
	st.add_index(0)
	st.add_index(2)
	st.add_index(3)
	return st.commit()
