@tool
extends AnimatedSprite3D
class_name MultiViewAnimatedSprite3D

# SpriteFrames as Layers

@export_category("Layers")

## SpriteFrames resources stacked as visual layers (back to front).
## Layer 0 uses this node's own sprite_frames.
## Layers 1+ automatically create child Sprite3D nodes synced to this sprite.
@export var sprite_layer_frames: Array[SpriteFrames] = []:
	set(value):
		sprite_layer_frames = value
		if is_inside_tree():
			_setup_layer_nodes()

## Per-layer visibility. Index matches layers array.
@export var layer_visible: Array[bool] = []:
	set(value):
		layer_visible = value
		if is_inside_tree():
			_sync_layers()

## Per-layer modulate (tint). Index matches layers array.
@export var layer_modulate: Array[Color] = []:
	set(value):
		layer_modulate = value
		if is_inside_tree():
			_sync_layers()

## SpriteFrames for normal maps. Animations must share names with the base SpriteFrames.
@export var normal_frames: SpriteFrames = null:
	set(value):
		normal_frames = value
		if is_inside_tree():
			_sync_shader_pbr()

## SpriteFrames for roughness maps (grayscale). Animations must share names with the base SpriteFrames.
@export var roughness_frames: SpriteFrames = null:
	set(value):
		roughness_frames = value
		if is_inside_tree():
			_sync_shader_pbr()

## SpriteFrames for depth/parallax maps (grayscale). Animations must share names with the base SpriteFrames.
@export var depth_frames: SpriteFrames = null:
	set(value):
		depth_frames = value
		if is_inside_tree():
			_sync_shader_pbr()

## SpriteFrames for emission maps (color). Animations must share names with the base SpriteFrames.
@export var emission_frames: SpriteFrames = null:
	set(value):
		emission_frames = value
		if is_inside_tree():
			_sync_shader_pbr()

## Range of the OmniLight3D spawned to cast emission light onto surroundings.
@export var emission_light_range: float = 5.0:
	set(value):
		emission_light_range = value
		_update_emission_light()

@export_category("Shadow Billboard")

## When enabled, a duplicate AnimatedSprite3D is spawned (as a child) with
## [member GeometryInstance3D.cast_shadow] set to SHADOWS_ONLY, and is
## billboarded to face opposite the environment directional light so it casts
## a drop shadow onto the scene.
@export var cast_shadow_billboard: bool = false:
	set(value):
		cast_shadow_billboard = value
		if is_inside_tree():
			_setup_shadow_billboard()

## NodePath to the sun. When empty, the first DirectionalLight3D exposed by an
## [code]env.gd[/code] node (its [member sun]) in the scene is used.
@export var sun_node_path: NodePath = NodePath():
	set(value):
		sun_node_path = value
		if is_inside_tree():
			_setup_shadow_billboard()

# Direction

@export_category("Direction")

## The direction the sprite faces in LOCAL space.
## Godot's default forward direction is -Z.
@export var forward_dir: Vector3 = Vector3(0, 0, -1)

## The up axis in LOCAL space.
@export var up_dir: Vector3 = Vector3(0, 1, 0)

## Above this elevation angle, top/bottom animations are used.
@export_range(0.0, 90.0, 0.1)
var elevation_threshold: float = 60.0

# Directional Animation Setup

@export_category("Directional Animations")

## Enables the four diagonal directions.
@export var use_8_way: bool = false:
	set(value):
		use_8_way = value
		if is_inside_tree():
			_scan_animations()

@export_group("Suffixes")

## The suffix used by the forward-facing animation.
@export var forward_suffix: String = "_front"

## The suffix used by the backward-facing animation.
@export var back_suffix: String = "_back"

## The suffix used by the left-facing animation.
@export var left_suffix: String = "_left"

## The suffix used by the right-facing animation.
@export var right_suffix: String = "_right"

## 8-way diagonal suffixes.
@export var front_left_suffix: String = "_front_left"
@export var front_right_suffix: String = "_front_right"
@export var back_left_suffix: String = "_back_left"
@export var back_right_suffix: String = "_back_right"

## Vertical suffixes.
@export var top_suffix: String = "_top"
@export var bottom_suffix: String = "_bottom"

# Discovered Animations

@export_category("Animations")

## Automatically populated with the logical animation names.
@export var animations: Array[String] = []

# Internal State

## Base animation -> direction -> actual animation name.
var _groups: Dictionary = {}
var _base_animation: StringName = &""
var _current_suffix: String = ""
var _is_base_playing: bool = false

# Layer Internal State

## Child Sprite3D nodes for layers 1..N.
var _layer_nodes: Array[Sprite3D] = []

# Emission Light State

var _emission_light: OmniLight3D = null

# Shadow Billboard State

## The duplicate AnimatedSprite3D used to cast a shadow-only billboard.
var _shadow_sprite: AnimatedSprite3D = null

# Vertical Billboard State

## Whether we are currently manually orienting the sprite for
## a top/bottom view.
var _vertical_view_active: bool = false

## The local transform the sprite had before we took control
## of its orientation.
var _normal_local_transform: Transform3D

## Reference world basis used for directional calculations.
## This does not change when we manually rotate the sprite
## for top/bottom views.
var _reference_world_basis: Basis
var _reference_initialized: bool = false

# Godot Lifecycle

func _ready() -> void:
	_initialize_reference_transform()
	_scan_animations()
	_setup_layer_nodes()
	_setup_shadow_billboard()
	frame_changed.connect(_on_frame_changed)


func _initialize_reference_transform() -> void:
	_normal_local_transform = transform

	if get_parent_node_3d():
		_reference_world_basis = (
			get_parent_node_3d().global_transform.basis *
			transform.basis
		).orthonormalized()
	else:
		_reference_world_basis = (
			global_transform.basis
		).orthonormalized()

	_reference_initialized = true


func _process(_delta: float) -> void:
	if cast_shadow_billboard:
		_sync_shadow_billboard()
		_update_shadow_billboard_orientation()

	if not _is_base_playing:
		return

	if _base_animation == &"":
		return

	if not _groups.has(_base_animation):
		return

	var new_suffix := _compute_suffix()

	if new_suffix != _current_suffix:
		_switch_direction(new_suffix)

	_update_vertical_orientation(new_suffix)

# Animation Scanning

func _scan_animations() -> void:
	if not sprite_frames:
		return

	_groups.clear()

	var suffix_map := _get_suffix_map()
	var suffixes: Array[String] = []

	for suffix in suffix_map.values():
		if suffix != "":
			suffixes.append(suffix)

	# Longest first so "front_left" matches before "front".
	suffixes.sort_custom(
		func(a: String, b: String) -> bool:
			return a.length() > b.length()
	)

	var all_names := sprite_frames.get_animation_names()
	var found_bases: Array[String] = []

	for anim_name_sn in all_names:
		var anim_name := String(anim_name_sn)

		for suffix in suffixes:
			if not anim_name.ends_with(suffix):
				continue

			var base := anim_name.left(
				anim_name.length() - suffix.length()
			)

			if base.is_empty():
				continue

			if not _groups.has(base):
				_groups[base] = {}
				found_bases.append(base)

			var direction := _get_direction_from_suffix(suffix)

			if direction != "":
				_groups[base][direction] = anim_name

			break

	animations = found_bases


func _get_suffix_map() -> Dictionary:
	return {
		"front": forward_suffix,
		"back": back_suffix,
		"left": left_suffix,
		"right": right_suffix,
		"front_left": front_left_suffix,
		"front_right": front_right_suffix,
		"back_left": back_left_suffix,
		"back_right": back_right_suffix,
		"top": top_suffix,
		"bottom": bottom_suffix
	}


func _get_direction_from_suffix(suffix: String) -> String:
	var suffix_map := _get_suffix_map()

	for direction in suffix_map:
		if suffix_map[direction] == suffix:
			return direction

	return ""

# Public Playback API

func play3d(
	anim_name: StringName,
	custom_speed: float = 1.0,
	from_end: bool = false,
	random_start: bool = false
) -> void:
	_scan_animations()

	if _groups.has(anim_name):
		_base_animation = anim_name
		_is_base_playing = true

		var suffix := _compute_suffix()
		_current_suffix = suffix

		var full_name := _get_full_name(_base_animation, suffix)

		if full_name == "":
			full_name = _get_fallback_animation(_base_animation)

		if full_name != "":
			super.play(full_name, custom_speed, from_end)

			if random_start and sprite_frames:
				var frame_count := sprite_frames.get_frame_count(full_name)

				if frame_count > 0:
					frame = randi_range(0, frame_count - 1)
					frame_progress = randf()

		_update_vertical_orientation(suffix)
		return

	# Normal non-directional animation.
	_is_base_playing = false
	_base_animation = &""
	_current_suffix = ""

	super.play(anim_name, custom_speed, from_end)

	if random_start and sprite_frames:
		var frame_count := sprite_frames.get_frame_count(anim_name)

		if frame_count > 0:
			frame = randi_range(0, frame_count - 1)
			frame_progress = randf()


func stop3d() -> void:
	_is_base_playing = false
	_base_animation = &""
	_current_suffix = ""

	_leave_vertical_view()
	super.stop()
	_sync_layers()

# Direction Switching

func _switch_direction(new_suffix: String) -> void:
	if _base_animation == &"":
		return

	var new_animation := _get_full_name(_base_animation, new_suffix)

	if new_animation == "":
		new_animation = _get_fallback_animation(_base_animation)

	if new_animation == "":
		return

	var old_animation := String(get_animation())

	if old_animation == new_animation:
		return

	# Save current playback state.
	var old_frame := frame
	var old_frame_progress := frame_progress
	var old_frame_count := 1
	var new_frame_count := 1

	if sprite_frames:
		old_frame_count = sprite_frames.get_frame_count(old_animation)
		new_frame_count = sprite_frames.get_frame_count(new_animation)

	old_frame_count = maxi(old_frame_count, 1)
	new_frame_count = maxi(new_frame_count, 1)

	# Preserve animation position.
	var normalized_position := 0.0

	if old_frame_count > 1:
		normalized_position = (
			float(old_frame) + old_frame_progress
		) / float(old_frame_count - 1)

	normalized_position = clamp(normalized_position, 0.0, 1.0)

	var was_playing := is_playing()

	super.play(new_animation)

	# Restore animation position.
	var new_frame := 0

	if new_frame_count > 1:
		new_frame = roundi(
			normalized_position * float(new_frame_count - 1)
		)

	new_frame = clamp(new_frame, 0, new_frame_count - 1)

	frame = new_frame
	frame_progress = 0.0

	if not was_playing:
		pause()

	_current_suffix = new_suffix
	_sync_layers()

# Vertical Orientation

func _update_vertical_orientation(suffix: String) -> void:
	var vertical := (
		suffix == "top" or
		suffix == "bottom"
	)

	if not vertical:
		_leave_vertical_view()
		return

	if not _reference_initialized:
		_initialize_reference_transform()

	var camera := get_viewport().get_camera_3d()

	if camera == null:
		return

	# Enter manual orientation mode.
	if not _vertical_view_active:
		_vertical_view_active = true
		billboard = BaseMaterial3D.BILLBOARD_DISABLED

	# Fixed world-space sprite axes from the ORIGINAL orientation.
	var local_forward := forward_dir.normalized()
	var local_up := up_dir.normalized()

	if local_forward.length_squared() < 0.000001:
		local_forward = Vector3(0, 0, -1)

	if local_up.length_squared() < 0.000001:
		local_up = Vector3.UP

	var world_forward := (
		_reference_world_basis * local_forward
	).normalized()

	var world_up := (
		_reference_world_basis * local_up
	).normalized()

	# Direction from sprite to camera.
	var to_camera := (
		camera.global_position - global_position
	).normalized()

	if to_camera.length_squared() < 0.000001:
		return

	# Project the sprite's fixed forward direction onto the
	# camera-facing plane to get the image "up" direction.
	var image_up := (
		world_forward -
		to_camera * world_forward.dot(to_camera)
	)

	if image_up.length_squared() < 0.000001:
		image_up = (
			world_up -
			to_camera * world_up.dot(to_camera)
		)

	if image_up.length_squared() < 0.000001:
		return

	image_up = image_up.normalized()

	# Build the camera-facing basis.
	var image_right := (
		image_up.cross(to_camera)
	).normalized()

	if image_right.length_squared() < 0.000001:
		return

	image_up = (
		to_camera.cross(image_right)
	).normalized()

	var target_world_basis := Basis(
		image_right,
		image_up,
		to_camera
	).orthonormalized()

	# Convert from world space back into the parent's local space.
	var parent := get_parent_node_3d()

	if parent:
		var parent_basis := parent.global_transform.basis

		var local_basis := (
			parent_basis.inverse() * target_world_basis
		).orthonormalized()

		transform = Transform3D(
			local_basis,
			_normal_local_transform.origin
		)
	else:
		global_transform = Transform3D(
			target_world_basis,
			global_position
		)


func _leave_vertical_view() -> void:
	if not _vertical_view_active:
		return

	_vertical_view_active = false
	transform = _normal_local_transform
	billboard = BaseMaterial3D.BILLBOARD_ENABLED

# Animation Lookup

func _get_full_name(base: StringName, direction: String) -> String:
	if not _groups.has(base):
		return ""

	var group: Dictionary = _groups[base]

	if group.has(direction):
		return String(group[direction])

	return ""


func _get_fallback_animation(base: StringName) -> String:
	if not _groups.has(base):
		return ""

	var group: Dictionary = _groups[base]

	var fallback_order := [
		"front",
		"back",
		"left",
		"right",
		"front_left",
		"front_right",
		"back_left",
		"back_right",
		"top",
		"bottom"
	]

	for direction in fallback_order:
		if group.has(direction):
			return String(group[direction])

	return ""

# Camera Direction

func _compute_suffix() -> String:
	var camera := get_viewport().get_camera_3d()

	if camera == null:
		return "front"

	# Convert camera direction into the sprite's ORIGINAL local
	# coordinate system using the stored reference basis.
	var world_to_camera := (
		camera.global_position - global_position
	)

	if world_to_camera.length_squared() < 0.000001:
		return "front"

	var to_camera_world := world_to_camera.normalized()
	var local_to_world_basis := _reference_world_basis

	var to_camera_local := (
		local_to_world_basis.inverse() * to_camera_world
	).normalized()

	if to_camera_local.length_squared() < 0.000001:
		return "front"

	# Local axes.
	var local_forward := forward_dir.normalized()
	var local_up := up_dir.normalized()

	if local_forward.length_squared() < 0.000001:
		local_forward = Vector3(0, 0, -1)

	if local_up.length_squared() < 0.000001:
		local_up = Vector3.UP

	# Make forward perpendicular to up.
	local_forward = (
		local_forward - local_up * local_forward.dot(local_up)
	).normalized()

	if local_forward.length_squared() < 0.000001:
		local_forward = Vector3(0, 0, -1)

	# Vertical component.
	var vertical := to_camera_local.dot(local_up)

	var horizontal_vector := (
		to_camera_local - local_up * vertical
	)

	var horizontal_length := horizontal_vector.length()

	# Top / bottom.
	if horizontal_length > 0.000001:
		var elevation := rad_to_deg(
			atan2(abs(vertical), horizontal_length)
		)

		if elevation > elevation_threshold:
			if vertical > 0.0:
				return "top"
			else:
				return "bottom"

	# Horizontal.
	if horizontal_length < 0.000001:
		return "front"

	var horizontal := horizontal_vector.normalized()

	var signed_angle := rad_to_deg(
		atan2(
			local_forward.cross(horizontal).dot(local_up),
			local_forward.dot(horizontal)
		)
	)

	signed_angle = fmod(signed_angle + 360.0, 360.0)

	if signed_angle >= 180.0:
		signed_angle -= 360.0

	# 8-way.
	if use_8_way:
		if signed_angle < -157.5 or signed_angle >= 157.5:
			return "front"
		elif signed_angle < -112.5:
			return "front_right"
		elif signed_angle < -67.5:
			return "right"
		elif signed_angle < -22.5:
			return "back_right"
		elif signed_angle < 22.5:
			return "back"
		elif signed_angle < 67.5:
			return "back_left"
		elif signed_angle < 112.5:
			return "left"
		else:
			return "front_left"

	# 4-way.
	if signed_angle < -135.0 or signed_angle >= 135.0:
		return "front"
	elif signed_angle < -45.0:
		return "right"
	elif signed_angle < 45.0:
		return "back"
	else:
		return "left"

# Layer System

func _setup_layer_nodes() -> void:
	for node in _layer_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_layer_nodes.clear()

	_sync_export_arrays()

	for i in range(1, sprite_layer_frames.size()):
		var sprite := Sprite3D.new()
		sprite.name = &"_layer_%d" % i
		add_child(sprite)
		if Engine.is_editor_hint():
			sprite.owner = get_tree().edited_scene_root
		_layer_nodes.append(sprite)
		_configure_layer_sprite(sprite)

	_sync_layers()


func _configure_layer_sprite(sprite: Sprite3D) -> void:
	sprite.pixel_size = pixel_size
	sprite.offset = offset
	sprite.flip_h = flip_h
	sprite.flip_v = flip_v
	sprite.billboard = billboard
	sprite.alpha_cut = alpha_cut
	sprite.alpha_scissor_threshold = alpha_scissor_threshold
	sprite.render_priority = render_priority
	sprite.shaded = shaded


func _sync_export_arrays() -> void:
	while layer_visible.size() < sprite_layer_frames.size():
		layer_visible.append(true)
	while layer_visible.size() > sprite_layer_frames.size():
		layer_visible.pop_back()

	while layer_modulate.size() < sprite_layer_frames.size():
		layer_modulate.append(Color.WHITE)
	while layer_modulate.size() > sprite_layer_frames.size():
		layer_modulate.pop_back()


func _on_frame_changed() -> void:
	_sync_layers()


func _sync_layers() -> void:
	var anim := get_animation()
	var f := frame

	for i in range(_layer_nodes.size()):
		var layer_idx := i + 1
		var node: Sprite3D = _layer_nodes[i]

		if layer_idx >= sprite_layer_frames.size():
			node.visible = false
			continue

		if not layer_visible[layer_idx]:
			node.visible = false
			continue

		var sf: SpriteFrames = sprite_layer_frames[layer_idx]
		if sf == null or not sf.has_animation(anim):
			node.visible = false
			continue

		if f >= sf.get_frame_count(anim):
			node.visible = false
			continue

		node.texture = sf.get_frame_texture(anim, f)
		node.modulate = layer_modulate[layer_idx]
		node.visible = true

	if sprite_layer_frames.size() > 0 and layer_visible[0]:
		modulate = layer_modulate[0] if layer_modulate.size() > 0 else Color.WHITE
	elif sprite_layer_frames.size() > 0:
		modulate = Color(1, 1, 1, 0)

	_sync_shader_pbr()
	_sync_shadow_billboard()

# Shader PBR Sync

func _sync_shader_pbr() -> void:
	if not material_override is ShaderMaterial:
		return

	var shader_mat := material_override as ShaderMaterial
	var anim := get_animation()
	var f := frame

	# Albedo — always update from the current frame.
	if sprite_frames != null and sprite_frames.has_animation(anim):
		if f < sprite_frames.get_frame_count(anim):
			shader_mat.set_shader_parameter("albedo_texture", sprite_frames.get_frame_texture(anim, f))

	# Normal map
	if normal_frames != null and normal_frames.has_animation(anim):
		if f < normal_frames.get_frame_count(anim):
			shader_mat.set_shader_parameter("normal_texture", normal_frames.get_frame_texture(anim, f))

	# Roughness map
	if roughness_frames != null and roughness_frames.has_animation(anim):
		if f < roughness_frames.get_frame_count(anim):
			shader_mat.set_shader_parameter("roughness_texture", roughness_frames.get_frame_texture(anim, f))

	# Depth map
	if depth_frames != null and depth_frames.has_animation(anim):
		if f < depth_frames.get_frame_count(anim):
			shader_mat.set_shader_parameter("depth_texture", depth_frames.get_frame_texture(anim, f))

	# Emission map
	if emission_frames != null and emission_frames.has_animation(anim):
		if f < emission_frames.get_frame_count(anim):
			shader_mat.set_shader_parameter("emission_texture", emission_frames.get_frame_texture(anim, f))

	_update_emission_light()


func _update_emission_light() -> void:
	if not material_override is ShaderMaterial:
		_hide_emission_light()
		return

	var shader_mat := material_override as ShaderMaterial
	var strength: float = shader_mat.get_shader_parameter("emission_strength")
	var color: Color = shader_mat.get_shader_parameter("emission_color")

	if strength <= 0.0:
		_hide_emission_light()
		return

	if _emission_light == null:
		_emission_light = OmniLight3D.new()
		_emission_light.name = &"_emission_light"
		_emission_light.omni_range = emission_light_range
		add_child(_emission_light)
		if Engine.is_editor_hint():
			_emission_light.owner = get_tree().edited_scene_root

	_emission_light.light_color = color
	_emission_light.light_energy = strength
	_emission_light.omni_range = emission_light_range
	_emission_light.visible = true


func _hide_emission_light() -> void:
	if _emission_light != null:
		_emission_light.visible = false

# Shadow Billboard

func _setup_shadow_billboard() -> void:
	if not cast_shadow_billboard:
		if is_instance_valid(_shadow_sprite):
			_shadow_sprite.queue_free()
		_shadow_sprite = null
		return

	if _shadow_sprite == null or not is_instance_valid(_shadow_sprite):
		_shadow_sprite = AnimatedSprite3D.new()
		_shadow_sprite.name = &"_shadow_billboard"
		_shadow_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		add_child(_shadow_sprite)
		if Engine.is_editor_hint():
			_shadow_sprite.owner = get_tree().edited_scene_root

	_shadow_sprite.sprite_frames = sprite_frames
	_shadow_sprite.pixel_size = pixel_size
	_shadow_sprite.offset = offset
	_shadow_sprite.flip_h = flip_h
	_shadow_sprite.flip_v = flip_v
	_shadow_sprite.alpha_cut = alpha_cut
	_shadow_sprite.alpha_scissor_threshold = alpha_scissor_threshold

	_sync_shadow_billboard()
	_update_shadow_billboard_orientation()


func _sync_shadow_billboard() -> void:
	if not cast_shadow_billboard:
		return
	if _shadow_sprite == null or not is_instance_valid(_shadow_sprite):
		return

	_shadow_sprite.sprite_frames = sprite_frames
	_shadow_sprite.flip_h = flip_h
	_shadow_sprite.flip_v = flip_v

	var anim := get_animation()
	if anim != "" and sprite_frames != null and sprite_frames.has_animation(anim):
		if _shadow_sprite.animation != anim:
			_shadow_sprite.play(anim)
		_shadow_sprite.frame = frame
		_shadow_sprite.visible = is_visible_in_tree()
	else:
		_shadow_sprite.visible = false


func _get_sun() -> DirectionalLight3D:
	if sun_node_path != NodePath():
		var node := get_node_or_null(sun_node_path)
		if node is DirectionalLight3D:
			return node

	# Fall back to an env.gd node's `sun` in the scene, or any directional light.
	var root := get_tree().current_scene if get_tree() else null
	if root == null:
		root = get_tree().root

	return _find_sun(root)


func _find_sun(node: Node) -> DirectionalLight3D:
	if node is DirectionalLight3D:
		return node

	if "sun" in node:
		var s = node.get("sun")
		if s is DirectionalLight3D:
			return s

	for child in node.get_children():
		var found := _find_sun(child)
		if found != null:
			return found

	return null


func _update_shadow_billboard_orientation() -> void:
	if not cast_shadow_billboard:
		return
	if _shadow_sprite == null or not is_instance_valid(_shadow_sprite):
		return

	var sun := _get_sun()
	if sun == null:
		return

	# Direction the light travels (Godot directional lights face -Z).
	var light_dir := (-sun.global_transform.basis.z).normalized()
	# Face the plane opposite the light's travel direction (back toward the sun).
	var face_normal := -light_dir

	var up := Vector3.UP
	if up.cross(face_normal).length_squared() < 0.000001:
		up = Vector3.RIGHT

	# Basis.looking_at orients -Z toward the target; the sprite faces +Z, so
	# point -Z toward the light's travel direction to face opposite it.
	var target_dir := light_dir

	_shadow_sprite.global_transform = Transform3D(
		Basis.looking_at(target_dir, up),
		global_position
	)

# Layer Public API

func set_layer(index: int, sprite_frames: SpriteFrames) -> void:
	if index < 0 or index >= sprite_layer_frames.size():
		return
	sprite_layer_frames[index] = sprite_frames
	_sync_layers()


func add_layer(sprite_frames: SpriteFrames, at_index: int = -1) -> int:
	if at_index < 0 or at_index >= sprite_layer_frames.size():
		sprite_layer_frames.append(sprite_frames)
		_setup_layer_nodes()
		return sprite_layer_frames.size() - 1
	sprite_layer_frames.insert(at_index, sprite_frames)
	_setup_layer_nodes()
	return at_index


func remove_layer(index: int) -> void:
	if index < 0 or index >= sprite_layer_frames.size():
		return
	sprite_layer_frames.remove_at(index)
	_setup_layer_nodes()


func enable_layer(index: int) -> void:
	if index < 0 or index >= layer_visible.size():
		return
	layer_visible[index] = true
	_sync_layers()


func disable_layer(index: int) -> void:
	if index < 0 or index >= layer_visible.size():
		return
	layer_visible[index] = false
	_sync_layers()


func is_layer_enabled(index: int) -> bool:
	if index < 0 or index >= layer_visible.size():
		return false
	return layer_visible[index]


func set_layer_visible(index: int, vis: bool) -> void:
	if vis:
		enable_layer(index)
	else:
		disable_layer(index)


func set_layer_modulate(index: int, color: Color) -> void:
	if index < 0 or index >= layer_modulate.size():
		return
	layer_modulate[index] = color
	_sync_layers()


func get_layer_modulate(index: int) -> Color:
	if index < 0 or index >= layer_modulate.size():
		return Color.WHITE
	return layer_modulate[index]


func get_layer_count() -> int:
	return sprite_layer_frames.size()
