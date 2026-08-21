@tool
extends AnimatedSprite3D
class_name MultiViewAnimatedSprite3D


# ============================================================
# Direction
# ============================================================

@export_category("Direction")

## The direction the sprite faces in LOCAL space.
## Godot's default forward direction is -Z.
@export var forward_dir: Vector3 = Vector3(0, 0, -1)

## The up axis in LOCAL space.
@export var up_dir: Vector3 = Vector3(0, 1, 0)

## Above this elevation angle, top/bottom animations are used.
@export_range(0.0, 90.0, 0.1)
var elevation_threshold: float = 60.0


# ============================================================
# Directional Animation Setup
# ============================================================

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


# ============================================================
# Discovered Animations
# ============================================================

@export_category("Animations")

## Automatically populated with the logical animation names.
@export var animations: Array[String] = []


# ============================================================
# Internal State
# ============================================================

## Base animation -> direction -> actual animation name.
var _groups: Dictionary = {}

var _base_animation: StringName = &""
var _current_suffix: String = ""

var _is_base_playing: bool = false


# ============================================================
# Vertical Billboard State
# ============================================================

## Whether we are currently manually orienting the sprite for
## a top/bottom view.
var _vertical_view_active: bool = false

## The local transform the sprite had before we took control
## of its orientation.
var _normal_local_transform: Transform3D

## Reference world basis used for directional calculations.
##
## IMPORTANT:
## This does not change when we manually rotate the sprite
## for top/bottom views.
var _reference_world_basis: Basis

var _reference_initialized: bool = false


# ============================================================
# Godot
# ============================================================

func _ready() -> void:
	_initialize_reference_transform()
	_scan_animations()


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


# ============================================================
# Animation Scanning
# ============================================================

func _scan_animations() -> void:
	if not sprite_frames:
		return

	_groups.clear()

	var suffix_map := _get_suffix_map()

	var suffixes: Array[String] = []

	for suffix in suffix_map.values():
		if suffix != "":
			suffixes.append(suffix)

	# Longest first.
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


# ============================================================
# Public Playback API
# ============================================================

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

		var full_name := _get_full_name(
			_base_animation,
			suffix
		)

		if full_name == "":
			full_name = _get_fallback_animation(
				_base_animation
			)

		if full_name != "":
			super.play(
				full_name,
				custom_speed,
				from_end
			)

			if random_start and sprite_frames:
				var frame_count := sprite_frames.get_frame_count(
					full_name
				)

				if frame_count > 0:
					frame = randi_range(
						0,
						frame_count - 1
					)

					frame_progress = randf()

		_update_vertical_orientation(suffix)

		return

	# Normal non-directional animation.
	_is_base_playing = false
	_base_animation = &""
	_current_suffix = ""

	super.play(
		anim_name,
		custom_speed,
		from_end
	)

	if random_start and sprite_frames:
		var frame_count := sprite_frames.get_frame_count(
			anim_name
		)

		if frame_count > 0:
			frame = randi_range(
				0,
				frame_count - 1
			)

			frame_progress = randf()


func stop3d() -> void:
	_is_base_playing = false
	_base_animation = &""
	_current_suffix = ""

	_leave_vertical_view()

	super.stop()


# ============================================================
# Direction Switching
# ============================================================

func _switch_direction(new_suffix: String) -> void:
	if _base_animation == &"":
		return

	var new_animation := _get_full_name(
		_base_animation,
		new_suffix
	)

	if new_animation == "":
		new_animation = _get_fallback_animation(
			_base_animation
		)

	if new_animation == "":
		return

	var old_animation := String(get_animation())

	if old_animation == new_animation:
		return

	# --------------------------------------------------------
	# Save current playback state.
	# --------------------------------------------------------

	var old_frame := frame
	var old_frame_progress := frame_progress

	var old_frame_count := 1
	var new_frame_count := 1

	if sprite_frames:
		old_frame_count = sprite_frames.get_frame_count(
			old_animation
		)

		new_frame_count = sprite_frames.get_frame_count(
			new_animation
		)

	old_frame_count = maxi(old_frame_count, 1)
	new_frame_count = maxi(new_frame_count, 1)

	# --------------------------------------------------------
	# Preserve animation position.
	# --------------------------------------------------------

	var normalized_position := 0.0

	if old_frame_count > 1:
		normalized_position = (
			float(old_frame) + old_frame_progress
		) / float(old_frame_count - 1)

	normalized_position = clamp(
		normalized_position,
		0.0,
		1.0
	)

	var was_playing := is_playing()

	super.play(new_animation)

	# --------------------------------------------------------
	# Restore animation position.
	# --------------------------------------------------------

	var new_frame := 0

	if new_frame_count > 1:
		new_frame = roundi(
			normalized_position *
			float(new_frame_count - 1)
		)

	new_frame = clamp(
		new_frame,
		0,
		new_frame_count - 1
	)

	frame = new_frame
	frame_progress = 0.0

	if not was_playing:
		pause()

	_current_suffix = new_suffix


# ============================================================
# Vertical Orientation
# ============================================================

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

	# --------------------------------------------------------
	# Enter manual orientation mode.
	# --------------------------------------------------------

	if not _vertical_view_active:
		_vertical_view_active = true

		# Disable Godot's billboard.
		#
		# From this point onward we control the sprite's
		# orientation ourselves.
		billboard = BaseMaterial3D.BILLBOARD_DISABLED

	# --------------------------------------------------------
	# Fixed world-space sprite axes.
	#
	# These come from the ORIGINAL orientation of the sprite,
	# not from its current transform.
	# --------------------------------------------------------

	var local_forward := forward_dir.normalized()
	var local_up := up_dir.normalized()

	if local_forward.length_squared() < 0.000001:
		local_forward = Vector3(0, 0, -1)

	if local_up.length_squared() < 0.000001:
		local_up = Vector3.UP

	var world_forward := (
		_reference_world_basis *
		local_forward
	).normalized()

	var world_up := (
		_reference_world_basis *
		local_up
	).normalized()

	# --------------------------------------------------------
	# Direction from sprite to camera.
	# --------------------------------------------------------

	var to_camera := (
		camera.global_position -
		global_position
	).normalized()

	if to_camera.length_squared() < 0.000001:
		return

	# --------------------------------------------------------
	# We need the sprite to face the camera, but its image
	# orientation must remain tied to world_forward.
	#
	# Project the sprite's fixed forward direction onto the
	# camera-facing plane.
	#
	# This gives us the "up" direction of the top/bottom
	# texture on screen.
	# --------------------------------------------------------

	var image_up := (
		world_forward -
		to_camera * world_forward.dot(to_camera)
	)

	# If the camera is almost exactly along the sprite's
	# forward axis, the projection becomes too small.
	#
	# Use world_up as a stable fallback.
	if image_up.length_squared() < 0.000001:
		image_up = (
			world_up -
			to_camera * world_up.dot(to_camera)
		)

	if image_up.length_squared() < 0.000001:
		return

	image_up = image_up.normalized()

	# --------------------------------------------------------
	# Build the camera-facing basis.
	#
	# X = right
	# Y = fixed sprite-forward projected onto screen
	# Z = camera-facing normal
	# --------------------------------------------------------

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

	# --------------------------------------------------------
	# Convert from world space back into the parent's local
	# space.
	#
	# Crucially, this uses the PARENT's transform, not our
	# current transform. Therefore changing our rotation
	# cannot affect the next calculation.
	# --------------------------------------------------------

	var parent := get_parent_node_3d()

	if parent:
		var parent_basis := (
			parent.global_transform.basis
		)

		var local_basis := (
			parent_basis.inverse() *
			target_world_basis
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

	# Restore the original transform.
	transform = _normal_local_transform

	# Give control back to AnimatedSprite3D's billboard.
	billboard = BaseMaterial3D.BILLBOARD_ENABLED


# ============================================================
# Animation Lookup
# ============================================================

func _get_full_name(
	base: StringName,
	direction: String
) -> String:

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


# ============================================================
# Camera Direction
# ============================================================

func _compute_suffix() -> String:
	var camera := get_viewport().get_camera_3d()

	if camera == null:
		return "front"

	# --------------------------------------------------------
	# Convert camera direction into the sprite's ORIGINAL
	# local coordinate system.
	#
	# We use the stored reference basis because the sprite may
	# currently be manually rotated for a top/bottom view.
	# --------------------------------------------------------

	var world_to_camera := (
		camera.global_position -
		global_position
	)

	if world_to_camera.length_squared() < 0.000001:
		return "front"

	var to_camera_world := world_to_camera.normalized()

	var local_to_world_basis := _reference_world_basis

	var to_camera_local := (
		local_to_world_basis.inverse() *
		to_camera_world
	).normalized()

	if to_camera_local.length_squared() < 0.000001:
		return "front"

	# --------------------------------------------------------
	# Local axes.
	# --------------------------------------------------------

	var local_forward := forward_dir.normalized()
	var local_up := up_dir.normalized()

	if local_forward.length_squared() < 0.000001:
		local_forward = Vector3(0, 0, -1)

	if local_up.length_squared() < 0.000001:
		local_up = Vector3.UP

	# Make forward perpendicular to up.
	local_forward = (
		local_forward -
		local_up * local_forward.dot(local_up)
	).normalized()

	if local_forward.length_squared() < 0.000001:
		local_forward = Vector3(0, 0, -1)

	# --------------------------------------------------------
	# Vertical component.
	# --------------------------------------------------------

	var vertical := to_camera_local.dot(local_up)

	var horizontal_vector := (
		to_camera_local -
		local_up * vertical
	)

	var horizontal_length := horizontal_vector.length()

	# --------------------------------------------------------
	# Top / bottom.
	# --------------------------------------------------------

	if horizontal_length > 0.000001:
		var elevation := rad_to_deg(
			atan2(
				abs(vertical),
				horizontal_length
			)
		)

		if elevation > elevation_threshold:
			if vertical > 0.0:
				return "top"
			else:
				return "bottom"

	# --------------------------------------------------------
	# Horizontal.
	# --------------------------------------------------------

	if horizontal_length < 0.000001:
		return "front"

	var horizontal := horizontal_vector.normalized()

	var signed_angle := rad_to_deg(
		atan2(
			local_forward.cross(horizontal).dot(local_up),
			local_forward.dot(horizontal)
		)
	)

	signed_angle = fmod(
		signed_angle + 360.0,
		360.0
	)

	if signed_angle >= 180.0:
		signed_angle -= 360.0

	# --------------------------------------------------------
	# 8-way.
	# --------------------------------------------------------

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

	# --------------------------------------------------------
	# 4-way.
	# --------------------------------------------------------

	if signed_angle < -135.0 or signed_angle >= 135.0:
		return "front"

	elif signed_angle < -45.0:
		return "right"

	elif signed_angle < 45.0:
		return "back"

	else:
		return "left"
