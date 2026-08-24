extends Control

@onready var camera_behavior: OptionControl = %CameraBehavior
@onready var camera_sensitivity: OptionControl = %CameraSensitivity
@onready var camera_snapping_speed: OptionControl = %CameraSnappingSpeed
@onready var invert_aim_type: OptionControl = %InvertAimType

func _ready() -> void:
	call_deferred("_apply_initial_visibility")


func _apply_initial_visibility() -> void:
	var behavior: Variant = PlayerConfig.get_config("GameSettings", "CameraBehavior", "Free")
	_update_camera_options_visibility(behavior)


func _on_camera_behavior_setting_changed(value: Variant) -> void:
	_update_camera_options_visibility(value)
	_apply_game_settings()


func _update_camera_options_visibility(behavior: Variant) -> void:
	var is_free: bool = str(behavior) == "Free"
	var is_snapping: bool = str(behavior) == "Snapping"
	var is_static: bool = str(behavior) == "Static"

	camera_sensitivity.visible = is_free
	camera_snapping_speed.visible = is_snapping
	invert_aim_type.visible = not is_static


func _on_camera_sensitivity_setting_changed(value: Variant) -> void:
	_apply_game_settings()


func _on_camera_snapping_speed_setting_changed(value: Variant) -> void:
	_apply_game_settings()


func _on_invert_aim_type_setting_changed(value: Variant) -> void:
	_apply_game_settings()


func _apply_game_settings() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("reload_game_settings"):
		player.reload_game_settings()
