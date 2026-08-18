extends Area3D

signal transition_started
signal transition_finished

@export var target_scene: String = ""

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player_move_in_location: Node3D = $player_move_in_location
@onready var player_move_out_location: Node3D = $player_move_out_location
@onready var level_load_trigger: Area3D = $player_move_in_location/level_load_trigger
@onready var transition_layer: CanvasLayer = $transition
@onready var color_rect: ColorRect = $transition/ColorRect

var _camera: Camera3D
var _transitioning := false


func _ready() -> void:
	level_load_trigger.visible = false


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

	body.lock_input()
	body.cutscene_velocity = Vector3.ZERO
	body.set_ui_visible(false)

	transition_layer.visible = true
	_update_circle_position()

	transition_started.emit()
	animation_player.play("transition_in")
	await animation_player.animation_finished

	body.global_position = player_move_in_location.global_position
	level_load_trigger.visible = true
	_transitioning = false
	transition_finished.emit()

	if target_scene != "":
		get_tree().change_scene_to_file(target_scene)


func play_transition_out(target: Node3D = null) -> void:
	## Call this to reverse the transition (open the circle).
	## If target is provided, the circle tracks that node instead of the player.
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
