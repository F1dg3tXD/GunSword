extends Node3D

@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
@onready var transition: CanvasLayer = $"../transition"
@onready var player_move_in_location: Node3D = $"../player_move_in_location"
@onready var player_move_out_location: Node3D = $"../player_move_out_location"
@onready var level_transition: Area3D = $".."
@onready var color_rect: ColorRect = $"../transition/ColorRect"

var _camera: Camera3D


func _ready() -> void:
	level_transition.set_deferred("monitoring", false)

	# Position the player at the spawn point and hide UI.
	var player = PlayerTopDown
	player.global_position = player_move_in_location.global_position
	player.cutscene_velocity = Vector3.ZERO
	player.lock_input()
	player.set_ui_visible(false)

	_camera = player.get_node_or_null("CameraRig/SpringArm3D/Camera3D")
	if _camera == null:
		_camera = get_viewport().get_camera_3d()

	transition.visible = true
	_play_entrance()


func _play_entrance() -> void:
	_update_circle_position()

	# Start the player walking toward the move-out point.
	PlayerTopDown.move_to(player_move_out_location.global_position)

	# Play reverse animation to the pause point (circle partially open).
	animation_player.play("transition_in", -1, -1.0, true)
	await get_tree().create_timer(level_transition.pause_at).timeout
	animation_player.pause()

	# Wait for the player to finish walking.
	while PlayerTopDown._move_to_target.x != INF:
		await get_tree().physics_frame

	# Resume and finish the reverse animation.
	animation_player.play("transition_in", -1, -1.0, true)
	await animation_player.animation_finished

	transition.visible = false
	level_transition.set_deferred("monitoring", true)
	PlayerTopDown.set_ui_visible(true)
	PlayerTopDown.unlock_input()


func _process(_delta: float) -> void:
	if _camera == null or not transition.visible:
		return
	_update_circle_position()


func _update_circle_position() -> void:
	if _camera == null:
		return
	var screen_pos := _camera.unproject_position(PlayerTopDown.global_position + Vector3.UP * 0.7)
	var viewport_size := color_rect.get_viewport_rect().size
	var uv := screen_pos / viewport_size
	var shader_mat := color_rect.material as ShaderMaterial
	if shader_mat:
		shader_mat.set_shader_parameter("_CirclePosition", uv)
