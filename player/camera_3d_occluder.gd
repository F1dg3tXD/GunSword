extends Camera3D


@export_category("Player Reveal")

@export var player: Node3D

@export var reveal_viewport: SubViewport

@export var reveal_camera: Camera3D

@export var reveal_plane: MeshInstance3D


@export_category("Reveal Settings")

@export_range(0.0, 10.0, 0.01)
var reveal_radius: float = 1.25

@export_range(0.0, 5.0, 0.01)
var reveal_softness: float = 0.75

@export_range(0.0, 1.0, 0.001)
var reveal_opacity: float = 1.0

@export_range(0.0, 1.0, 0.001)
var depth_epsilon: float = 0.05


var reveal_material: ShaderMaterial


func _ready() -> void:
	_setup_reveal_viewport()
	_setup_reveal_material()


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return

	_sync_reveal_camera()
	_update_shader()


func _setup_reveal_viewport() -> void:
	if reveal_viewport == null:
		push_error(
            "Player reveal viewport is not assigned."
		)
		return

	reveal_viewport.transparent_bg = true

	reveal_viewport.render_target_update_mode = \
		SubViewport.UPDATE_ALWAYS


func _setup_reveal_material() -> void:
	if reveal_plane == null:
		push_error(
            "Reveal plane is not assigned."
		)
		return

	var material := \
		reveal_plane.get_surface_override_material(0)

	if material is ShaderMaterial:
		reveal_material = material
	else:
		push_error(
            "Reveal plane needs a ShaderMaterial."
		)
		return

	if reveal_viewport != null:
		reveal_material.set_shader_parameter(
			"player_texture",
			reveal_viewport.get_texture()
		)


func _sync_reveal_camera() -> void:
	if reveal_camera == null:
		return

	# Match the main camera transform.
	reveal_camera.global_transform = \
		global_transform


	# Match projection settings.
	reveal_camera.projection = projection

	reveal_camera.fov = fov
	reveal_camera.size = size

	reveal_camera.near = near
	reveal_camera.far = far

	reveal_camera.frustum_offset = \
		frustum_offset


func _update_shader() -> void:
	if reveal_material == null:
		return

	reveal_material.set_shader_parameter(
		"player_position_world",
		player.global_position
	)

	reveal_material.set_shader_parameter(
		"reveal_radius",
		reveal_radius
	)

	reveal_material.set_shader_parameter(
		"reveal_softness",
		reveal_softness
	)

	reveal_material.set_shader_parameter(
		"depth_epsilon",
		depth_epsilon
	)

	reveal_material.set_shader_parameter(
		"opacity",
		reveal_opacity
	)
