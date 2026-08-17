@icon("res://addons/cylinder_cut/icon.svg")
class_name CylinderCutNode
extends Node3D

## Dynamic cut-through system. Supports two modes:
##
## [b]CYLINDER[/b] — legacy mode. Mount on the player and point [member player_point]
## and [member cam_point] at the two ends of the visible "tunnel" through geometry.
##
## [b]RAYCAST[/b] — box-cut-volume mode. Point [member raycast_path] at a
## [RayCast3D] that fires from the camera toward the player. The collision point
## becomes the centre of an oriented box that punches through the wall at that
## location, avoiding the "whole map invisible" problem of the global cylinder.
##
## When [member auto_window_geometry] is enabled the node periodically scans the scene
## tree and converts every opaque StandardMaterial3D / ORMMaterial3D to the built-in
## receiver shader (preserving albedo texture and colour), so walls, pillars and props
## cut through automatically with no per-material setup.

enum CUT_MODE { CYLINDER, RAYCAST }

## Cut-through algorithm.
@export var cut_mode: CUT_MODE = CUT_MODE.RAYCAST

## ── Cylinder mode ───────────────────────────────────────────────────────────

## Start point of the cylinder (e.g. the character's body anchor).
@export var player_point: Node3D

## End point of the cylinder (e.g. the camera anchor).
@export var cam_point: Node3D

## Cylinder radius in world units (metres).
@export_range(0.1, 50.0) var radius := 2.0

## Edge blend width as a fraction of the radius.
## 0 = hard boolean cut, 1 = fully soft gradient. Override with an edge_texture for
## custom patterns (dissolve, rings, etc.).
@export_range(0.0, 1.0) var softness := 0.3

## Optional edge texture. Maps normalised distance (0 = axis, 1 = radius) to alpha.
## Leave empty to use the [member softness] uniform with the built-in smoothstep edge.
@export var edge_texture: Texture2D

## ── Raycast mode ────────────────────────────────────────────────────────────

## Half-extents of the box cut volume (width, height, depth) in metres.
## Width = perpendicular to ray (horizontal), height = perpendicular (vertical),
## depth = along the ray direction (through the wall).
@export var cut_size := Vector3(1.5, 3.0, 1.0)

## Edge blend for the box volume as a fraction of the smallest half-extent.
@export_range(0.0, 1.0) var cut_softness := 0.3

## ── Shared ──────────────────────────────────────────────────────────────────

## Automatically scan the tree and convert qualifying materials to the receiver shader
## so they cut through with no per-material setup.
@export var auto_window_geometry := true

## How often (seconds) the auto-apply pass re-scans the tree to catch late-added
## geometry.
@export_range(0.1, 5.0, 0.1) var auto_scan_interval := 0.5

## Node paths resolved at runtime when the corresponding @export Node3D fields are
## left empty (useful when the node is added programmatically).
@export var player_point_path: NodePath
@export var cam_point_path: NodePath
@export var raycast_path: NodePath

var _auto_material_cache := {}
var _gridmap_library_cache := {}
var _auto_timer := 0.0
var _shader: Shader
var _raycast: RayCast3D


func _ready() -> void:
	if player_point == null and not player_point_path.is_empty():
		player_point = get_node_or_null(player_point_path)
	if cam_point == null and not cam_point_path.is_empty():
		cam_point = get_node_or_null(cam_point_path)
	if not raycast_path.is_empty():
		_raycast = get_node_or_null(raycast_path) as RayCast3D


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update()
	if auto_window_geometry:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			_auto_timer = auto_scan_interval
			_auto_scan()


func _update() -> void:
	if cut_mode == CUT_MODE.RAYCAST:
		_update_raycast()
	else:
		_update_cylinder()


func _update_raycast() -> void:
	if _raycast == null:
		_disable_cut_volume()
		return
	_raycast.force_raycast_update()
	if _raycast.is_colliding():
		var center: Vector3 = _raycast.get_collision_point()
		var forward: Vector3 = -_raycast.global_transform.basis.z
		RenderingServer.global_shader_parameter_set("cut_volume_enabled", 1.0)
		RenderingServer.global_shader_parameter_set("cut_volume_center", center)
		RenderingServer.global_shader_parameter_set("cut_volume_forward", forward)
		RenderingServer.global_shader_parameter_set("cut_volume_size", cut_size)
		RenderingServer.global_shader_parameter_set("cut_volume_softness", cut_softness)
		# Ensure cylinder mode is off.
		RenderingServer.global_shader_parameter_set("cylinder_cut_radius", 0.0)
	else:
		_disable_cut_volume()


func _disable_cut_volume() -> void:
	RenderingServer.global_shader_parameter_set("cut_volume_enabled", 0.0)


func _update_cylinder() -> void:
	if player_point == null or cam_point == null:
		_disable_cylinder()
		_disable_cut_volume()
		return
	var a := player_point.global_position
	var b := cam_point.global_position
	RenderingServer.global_shader_parameter_set("cylinder_cut_a", a)
	RenderingServer.global_shader_parameter_set("cylinder_cut_b", b)
	RenderingServer.global_shader_parameter_set("cylinder_cut_radius", radius)
	RenderingServer.global_shader_parameter_set("cylinder_cut_softness", softness)
	RenderingServer.global_shader_parameter_set("cylinder_cut_edge_tex_on",
			1.0 if edge_texture != null else 0.0)
	# Ensure box mode is off.
	_disable_cut_volume()


func _disable_cylinder() -> void:
	RenderingServer.global_shader_parameter_set("cylinder_cut_radius", 0.0)


# ── Auto-apply ──────────────────────────────────────────────────────────────

func _auto_scan() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_auto_scan_node(tree.root)


func _auto_scan_node(node: Node) -> void:
	if node is Sprite3D or node is AnimatedSprite3D:
		return
	if _in_excluded_tree(node):
		return
	if node is MeshInstance3D:
		_auto_apply_to_mesh(node)
	elif node is GridMap:
		_auto_apply_to_gridmap(node)
	for child in node.get_children():
		_auto_scan_node(child)


func _in_excluded_tree(node: Node) -> bool:
	if node == self or node.is_in_group("cylinder_cut_exclude"):
		return true
	var current: Node = node
	while current != null:
		if current == player_point or current == cam_point:
			return true
		current = current.get_parent()
	return false


func _auto_apply_to_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.has_meta("cylinder_cut_applied"):
		return
	var material := _effective_material(mesh_instance)
	if material == null or material is ShaderMaterial:
		return
	if not (material is StandardMaterial3D or material is ORMMaterial3D):
		return
	var base := material as BaseMaterial3D
	var converted := _converted_material(base)
	if converted == null:
		return
	mesh_instance.material_override = converted
	mesh_instance.set_meta("cylinder_cut_applied", true)


func _effective_material(mesh_instance: MeshInstance3D) -> Material:
	if mesh_instance.material_override != null:
		return mesh_instance.material_override
	var mesh := mesh_instance.mesh
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	return mesh.surface_get_material(0)


func _converted_material(base: BaseMaterial3D) -> ShaderMaterial:
	var key := [base.albedo_texture, base.albedo_color]
	if _auto_material_cache.has(key):
		return _auto_material_cache[key]
	var material := ShaderMaterial.new()
	material.shader = _receiver_shader()
	material.set_shader_parameter("albedo_texture", base.albedo_texture)
	material.set_shader_parameter("albedo_color", base.albedo_color)
	material.set_shader_parameter("cylinder_cut_occlude", true)
	material.set_shader_parameter("cylinder_cut_edge_texture",
			edge_texture if edge_texture != null else Texture2D.new())
	_auto_material_cache[key] = material
	return material


func _auto_apply_to_gridmap(grid_map: GridMap) -> void:
	if grid_map.has_meta("cylinder_cut_applied"):
		return
	var library := grid_map.mesh_library
	if library == null:
		return
	var converted := _converted_library(library)
	grid_map.mesh_library = converted
	grid_map.set_meta("cylinder_cut_applied", true)


func _converted_library(library: MeshLibrary) -> MeshLibrary:
	var key := [library]
	if _gridmap_library_cache.has(key):
		return _gridmap_library_cache[key]
	var converted := library.duplicate(true) as MeshLibrary
	for id in converted.get_item_list():
		var mesh: Mesh = converted.get_item_mesh(id)
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface)
			if material == null or material is ShaderMaterial:
				continue
			if not (material is StandardMaterial3D or material is ORMMaterial3D):
				continue
			var converted_material := _converted_material(material as BaseMaterial3D)
			mesh.surface_set_material(surface, converted_material)
	_gridmap_library_cache[key] = converted
	return converted


func _receiver_shader() -> Shader:
	if _shader == null:
		_shader = load("res://addons/cylinder_cut/shaders/cylinder_cut_receiver.gdshader")
	return _shader
