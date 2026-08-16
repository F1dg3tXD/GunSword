@icon("res://addons/occlusion_window/icon.svg")
class_name OcclusionWindow2D
extends Node2D

## 2D reveal-window component. Mount one as a child of the 2D camera and/or on the
## character: each punches a soft-edged circular window through every occluder that opts
## in (occlusion_window_occlude = true on its material) and is drawn IN FRONT of the
## target's y-sort depth line. A character hidden by a tile layer, building or tree stays
## visible through the hole, with a vignette fading back to the occluder.
##
## The window is a screen-space effect: the receiver shader shipped in this addon
## (addons/occlusion_window/shaders/occlusion_window_2D.gdshader) reads a set of global
## uniforms (the occlusion_window_a_* / occlusion_window_b_* slots) and fades its alpha
## out at the target's SCREEN position. Because the cut is per fragment and screen-based
## it applies to sprites, plain nodes AND TileMapLayer tiles alike, and works on both the
## Forward+ and the OpenGL/Compatibility renderers. The addon is self-contained; it has
## no dependency on any external lighting addon.
##
## Two slots exist so the two typical mounts don't fight over one global uniform set:
## set window_slot to "A (camera)" on the camera mount and "B (character)" on the
## character mount (either order; a scene with a single component can use either slot).
##
## Cutting rule (y-sort convention: larger Y is drawn in front):
##     cut = receiver opted in AND receiver_depth > target_depth
## The window is centered on the target's anchor and its radius grows from zero at the
## depth line to full `fade_distance` world px below it, so occluders just in front of
## the character barely thin while deeper ones open fully. The player's own sprite sits
## exactly on the depth line and is never cut; base/floor layers need only
## occlusion_window_occlude left off to stay untouched.

## Which global shader slot this component drives: "A (camera)" or "B (character)".
## The slots are independent, so a camera-mounted and a character-mounted window can be
## active at the same time.
@export_enum("A (camera)", "B (character)") var window_slot := 0

## The character to reveal. Empty (the default) falls back to the first node in the
## "player" group, then to this component's parent (handy when mounted on the
## character itself).
@export var target: Node2D = null

## Window radius in world pixels (the fully-transparent core).
@export_range(1.0, 1000.0) var window_radius := 70.0

## Fraction of the radius used for the vignette edge: 0 is a hard cut, 1 is a fully
## soft gradient back to the occluder.
@export_range(0.0, 1.0) var vignette_softness := 0.35

## World pixels past the depth line the window needs to reach full radius. Larger eases
## the window in/out as the character crosses under occluders; 0 pops instantly.
@export_range(0.0, 500.0) var fade_distance := 40.0

## The point on the target the window follows: local to the target, and the point that
## must stay visible. Defaults a little above the origin so the window frames the
## character's body rather than their feet.
@export var target_anchor := Vector2(0.0, -40.0)

var _prefix := "occlusion_window_a_"


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_prefix = "occlusion_window_b_" if window_slot == 1 else "occlusion_window_a_"
	_update()


func _update() -> void:
	var target_node := _resolve_target()
	if target_node == null:
		_disable()
		return
	var viewport := get_viewport()
	if viewport == null:
		_disable()
		return
	var canvas_transform := viewport.get_canvas_transform()
	var viewport_size := viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		_disable()
		return

	var anchor_world := target_node.to_global(target_anchor)
	var center_px := canvas_transform * anchor_world
	var center_uv := Vector2(center_px.x / viewport_size.x, center_px.y / viewport_size.y)
	var zoom := absf(canvas_transform.get_scale().x)
	var radius_uv := Vector2(window_radius * zoom / viewport_size.x,
			window_radius * zoom / viewport_size.y)
	var depth := target_node.global_position.y

	RenderingServer.global_shader_parameter_set(_prefix + "center", center_uv)
	RenderingServer.global_shader_parameter_set(_prefix + "radius", radius_uv)
	RenderingServer.global_shader_parameter_set(_prefix + "softness", vignette_softness)
	RenderingServer.global_shader_parameter_set(_prefix + "depth", depth)
	RenderingServer.global_shader_parameter_set(_prefix + "fade", fade_distance)


func _disable() -> void:
	RenderingServer.global_shader_parameter_set(_prefix + "radius", Vector2.ZERO)


func _resolve_target() -> Node2D:
	if target != null and is_instance_valid(target):
		return target
	var found := get_tree().get_first_node_in_group("player")
	if found is Node2D:
		return found
	var parent := get_parent()
	return parent as Node2D
