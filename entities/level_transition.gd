extends Area3D

signal transition_started
signal transition_finished

@export var target_scene: String = ""
@export_range(0.0, 1.5, 0.01) var pause_at: float = 0.75

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player_move_in_location: Node3D = $player_move_in_location
@onready var player_move_out_location: Node3D = $player_move_out_location
@onready var transition_layer: CanvasLayer = $transition
@onready var color_rect: ColorRect = $transition/ColorRect

var _camera: Camera3D
var _transitioning := false


func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	if _camera == null or _transitioning == false:
		return
	_update_circle_position()


func _update_circle_position() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or _camera == null:
		return
	var screen_pos := _camera.unproject_position(player.global_position + Vector3.UP * 0.7)
	var viewport_size := color_rect.get_viewport_rect().size
	var uv := screen_pos / viewport_size
	var shader_mat := color_rect.material as ShaderMaterial
	if shader_mat:
		shader_mat.set_shader_parameter("_CirclePosition", uv)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if _transitioning:
		return
	_transitioning = true

	_camera = body.get_node_or_null("CameraRig/SpringArm3D/Camera3D")
	if _camera == null:
		_camera = get_viewport().get_camera_3d()

	body.set_ui_visible(false)

	# Start the player walking toward the move-in point.
	body.move_to(player_move_in_location.global_position)

	# Play the circle-closes-on-player animation to the pause point.
	transition_layer.visible = true
	_update_circle_position()
	transition_started.emit()
	animation_player.play("transition_in")
	await get_tree().create_timer(pause_at).timeout
	animation_player.pause()

	# Wait for the player to finish walking.
	while body._move_to_target.x != INF:
		await get_tree().physics_frame

	# Resume and finish the animation.
	animation_player.play()
	await animation_player.animation_finished

	_transitioning = false
	transition_finished.emit()

	if target_scene != "":
		get_tree().change_scene_to_file(target_scene)


func play_transition_out(target: Node3D = null) -> void:
	if _transitioning:
		return
	_transitioning = true

	transition_layer.visible = true
	_update_circle_position()

	animation_player.play("transition_in", -1, -1.0, true)
	await animation_player.animation_finished

	transition_layer.visible = false
	_transitioning = false
	transition_finished.emit()
