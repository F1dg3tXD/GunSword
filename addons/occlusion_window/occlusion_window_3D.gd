@icon("res://addons/occlusion_window/icon.svg")
class_name OcclusionWindow3D
extends Node3D

## 3D reveal-window component. Mount one as a child of a Camera3D (or its rig/pivot)
## and/or on the 3D character: each punches a soft-edged circular window through every
## occluder that opts in (occlusion_window_occlude = true on its material) and is drawn
## IN FRONT of the target from the camera's point of view. A character hidden behind a
## wall, pillar or other geometry stays visible through the hole, with a vignette fading
## back to the occluder.
##
## The window is a screen-space effect: the receiver shader shipped in this addon
## (addons/occlusion_window/shaders/occlusion_window_3D.gdshader) reads a set of global
## uniforms (the occlusion_window_a_* / occlusion_window_b_* slots) and fades its alpha
## out at the target's projected SCREEN position. Because the cut is per fragment and
## screen-based it applies to anything the receiver shader draws. The addon is
## self-contained; it has no dependency on any external lighting addon.
##
## Two slots exist so the two typical mounts don't fight over one global uniform set:
## set window_slot to "A (camera)" on the camera mount and "B (character)" on the
## character mount (either order; a scene with a single component can use either slot).
##
## Cutting rule (view depth = positive distance from the camera plane along the camera's
## forward axis):
##     cut = receiver opted in AND receiver_view_depth < target_view_depth
## The window is centered on the target's projected anchor and its radius grows from zero
## at the target's depth to full `fade_distance` world units closer to the camera, so
## occluders just in front of the character barely thin while closer ones open fully.
## The player's own body sits exactly on the depth line and is never cut; floor/base
## geometry needs only occlusion_window_occlude left off to stay untouched.

## Which global shader slot this component drives: "A (camera)" or "B (character)".
## The slots are independent, so a camera-mounted and a character-mounted window can be
## active at the same time.
@export_enum("A (camera)", "B (character)") var window_slot := 0

## The character to reveal. Empty (the default) falls back to the first node in the
## "player" group, then to this component's parent (handy when mounted on the
## character itself).
@export var target: Node3D = null

## Window radius in world units (metres, the fully-transparent core). It is projected
## from the target's view depth, so the window frames the same world area around the
## character regardless of how far the camera is.
@export_range(0.1, 100.0) var window_radius := 1.5

## Fraction of the radius used for the vignette edge: 0 is a hard cut, 1 is a fully
## soft gradient back to the occluder.
@export_range(0.0, 1.0) var vignette_softness := 0.35

## World units of view depth closer to the camera the window needs to reach full radius.
## Larger eases the window in/out as the character crosses in front of occluders;
## 0 pops instantly.
@export_range(0.0, 50.0) var fade_distance := 3.0

## The point on the target the window follows: local to the target, and the point that
## must stay visible. Defaults a little above the origin so the window frames the
## character's body rather than their feet.
@export var target_anchor := Vector3(0.0, 1.0, 0.0)

## Treat ANY 3D geometry between the target and the camera as something to look through.
## While enabled, this component periodically converts every opaque StandardMaterial3D /
## ORMMaterial3D mesh in the scene to the receiver shader (preserving its albedo
## texture/color and opting it in), so walls, pillars and props window automatically with
## no per-material setup. Other 3D sprites (Sprite3D / AnimatedSprite3D), the target's
## own subtree, custom-shader materials and anything in the "occlusion_window_exclude"
## group are left untouched. The receiver shader only cuts roughly-vertical surfaces by
## default, so floors and roof tops stay solid.
@export var auto_window_geometry := false

## How often (seconds) the auto-apply pass re-scans the tree to catch late-added geometry.
@export_range(0.1, 5.0, 0.1) var auto_scan_interval := 0.5

## When auto-windowing a GridMap, only cut roughly-vertical surfaces (walls, pillars).
## GridMaps have no per-cell material override, so this single toggle governs the whole
## library: the receiver shader leaves flat up-facing ground solid when enabled, and also
## cuts roof tops when disabled (at the cost of cutting flat floor tiles too).
@export var gridmap_vertical_only := true

var _prefix := "occlusion_window_a_"
var _shader: Shader
var _auto_material_cache := {}
var _gridmap_library_cache := {}
var _auto_timer := 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_prefix = "occlusion_window_b_" if window_slot == 1 else "occlusion_window_a_"
	_update()
	if auto_window_geometry:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			_auto_timer = auto_scan_interval
			_auto_scan()


func _update() -> void:
	var target_node := _resolve_target()
	if target_node == null:
		_disable()
		return
	var viewport := get_viewport()
	if viewport == null:
		_disable()
		return
	var camera := viewport.get_camera_3d()
	if camera == null:
		_disable()
		return
	var viewport_size := viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		_disable()
		return

	var anchor_world := target_node.to_global(target_anchor)
	var view_depth := _view_depth(camera, anchor_world)
	if camera.is_position_behind(anchor_world) or view_depth <= 0.0:
		_disable()
		return
	var center_px := camera.unproject_position(anchor_world)
	var center_uv := Vector2(center_px.x / viewport_size.x, center_px.y / viewport_size.y)
	var visible_height := _visible_height_at(camera, view_depth)
	if visible_height <= 0.0:
		_disable()
		return
	var radius_px := window_radius * viewport_size.y / visible_height
	var radius_uv := Vector2(radius_px / viewport_size.x, radius_px / viewport_size.y)

	RenderingServer.global_shader_parameter_set(_prefix + "center", center_uv)
	RenderingServer.global_shader_parameter_set(_prefix + "radius", radius_uv)
	RenderingServer.global_shader_parameter_set(_prefix + "softness", vignette_softness)
	RenderingServer.global_shader_parameter_set(_prefix + "depth", view_depth)
	RenderingServer.global_shader_parameter_set(_prefix + "fade", fade_distance)


## Positive distance from the camera plane along the camera's forward (-Z) axis.
func _view_depth(camera: Camera3D, world_pos: Vector3) -> float:
	return -camera.global_basis.z.dot(world_pos - camera.global_position)


## World-space height of the camera frustum at the given view depth. Derived from the
## camera's own projection matrix so keep_aspect, ortho and frustum modes all work.
func _visible_height_at(camera: Camera3D, view_depth: float) -> float:
	var y_scale := absf(camera.get_camera_projection().y.y)
	if y_scale == 0.0:
		return 0.0
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return 2.0 / y_scale
	return view_depth * 2.0 / y_scale


func _disable() -> void:
	RenderingServer.global_shader_parameter_set(_prefix + "radius", Vector2.ZERO)


func _resolve_target() -> Node3D:
	if target != null and is_instance_valid(target):
		return target
	var found := get_tree().get_first_node_in_group("player")
	if found is Node3D:
		return found
	var parent := get_parent()
	return parent as Node3D


func _auto_scan() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_auto_scan_node(tree.root)


func _auto_scan_node(node: Node) -> void:
	# Other 3D sprites (billboards, characters) are NOT occluders: never window them.
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
	if node == self or node.is_in_group("occlusion_window_exclude"):
		return true
	var target_node := _resolve_target()
	var current: Node = node
	while current != null:
		if current == target_node:
			return true
		current = current.get_parent()
	return false


func _auto_apply_to_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.has_meta("occlusion_window_applied"):
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
	mesh_instance.set_meta("occlusion_window_applied", true)


func _effective_material(mesh_instance: MeshInstance3D) -> Material:
	if mesh_instance.material_override != null:
		return mesh_instance.material_override
	var mesh := mesh_instance.mesh
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	return mesh.surface_get_material(0)


func _converted_material(base: BaseMaterial3D, vertical_only := true) -> ShaderMaterial:
	var key := [base.albedo_texture, base.albedo_color, vertical_only]
	if _auto_material_cache.has(key):
		return _auto_material_cache[key]
	var material := ShaderMaterial.new()
	material.shader = _receiver_shader()
	material.set_shader_parameter("albedo_texture", base.albedo_texture)
	material.set_shader_parameter("albedo_color", base.albedo_color)
	material.set_shader_parameter("occlusion_window_occlude", true)
	material.set_shader_parameter("occlusion_window_vertical_only", vertical_only)
	_auto_material_cache[key] = material
	return material


## GridMap cells are not scene-tree MeshInstance3D nodes and GridMap has no material
## override, so the auto pass duplicates the node's MeshLibrary and swaps every item's
## surface material for the receiver shader (preserving the kit's albedo texture/color).
## The duplicate is cached per source library so shared libraries are converted once, and
## the original resource is never mutated.
func _auto_apply_to_gridmap(grid_map: GridMap) -> void:
	if grid_map.has_meta("occlusion_window_applied"):
		return
	var library := grid_map.mesh_library
	if library == null:
		return
	var converted := _converted_library(library, gridmap_vertical_only)
	grid_map.mesh_library = converted
	grid_map.set_meta("occlusion_window_applied", true)


func _converted_library(library: MeshLibrary, vertical_only: bool) -> MeshLibrary:
	var key := [library, vertical_only]
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
			var converted_material := _converted_material(material as BaseMaterial3D, vertical_only)
			mesh.surface_set_material(surface, converted_material)
	_gridmap_library_cache[key] = converted
	return converted


func _receiver_shader() -> Shader:
	if _shader == null:
		_shader = load("res://addons/occlusion_window/shaders/occlusion_window_3D.gdshader")
	return _shader
