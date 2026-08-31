extends Node3D

var day = true
@onready var sun: DirectionalLight3D = $sun
@onready var world_environment: WorldEnvironment = $WorldEnvironment

## How long (in minutes) a full day/night cycle takes. Reserved for driving the
## sun rotation; not used by the shader tick.
@export var day_length_minutes: float = 12.0
## How fast the sky's `overwritten_time` shader parameter advances per second.
## This acts as a time-scaling for the sky's animated effects (clouds, stars).
@export var tick_speed: float = 2.0

var _sky_material: ShaderMaterial


func _ready() -> void:
	if world_environment != null and world_environment.environment != null:
		var sky: Sky = world_environment.environment.sky
		if sky != null and sky.sky_material is ShaderMaterial:
			_sky_material = sky.sky_material


func _process(delta: float) -> void:
	if not _is_map_scene():
		return

	if _sky_material != null:
		var t: float = _sky_material.get_shader_parameter("overwritten_time")
		_sky_material.set_shader_parameter("overwritten_time", t + tick_speed * delta)

	_rotate_sun(delta)


## Rotates the sun around the global X axis to complete a full 360 degree day /
## night cycle in [member day_length_minutes].
func _rotate_sun(delta: float) -> void:
	if sun == null:
		return
	if day_length_minutes <= 0.0:
		return

	var angle_per_second := TAU / (day_length_minutes * 60.0)
	sun.rotate(Vector3.RIGHT, angle_per_second * delta)


## Returns true only while the current scene lives inside res://maps/ so this
## singleton does not tick in non-map scenes (menus, editor scenes, etc).
func _is_map_scene() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return scene.scene_file_path.begins_with("res://maps/")
