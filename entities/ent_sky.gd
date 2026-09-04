extends Node3D

var day = true
@onready var sun: DirectionalLight3D = $sun
@onready var world_environment: WorldEnvironment = $WorldEnvironment

## Full length of one daylight cycle in Minecraft-style ticks (1 game-day = 24000).
## Console commands address time in these ticks; `time set 1800` / `time set night`
## map onto this 24-hour clock (1000 ticks per "hour").
const DAY_TICKS := 24000.0

## How long (in minutes) a full day/night cycle takes. Reserved for driving the
## sun rotation; not used by the shader tick.
## With the default 12 minutes = one 24-hour game-day, 1 game-hour is 30 seconds.
@export var day_length_minutes: float = 12.0
## How fast the sky's `overwritten_time` shader parameter advances per second.
## This acts as a time-scaling for the sky's animated effects (clouds, stars).
@export var tick_speed: float = 2.0

## Time-scale multiplier applied to the daylight cycle (sun rotation and the sky
## `overwritten_time` clock). 1.0 is normal speed. Set via the `tickrate` console
## command.
var tickrate: float = 1.0

var _cycle_tick: float = 0.0
var _sky_material: ShaderMaterial
var _sun_origin_quat: Quaternion


func _ready() -> void:
	if world_environment != null and world_environment.environment != null:
		var sky: Sky = world_environment.environment.sky
		if sky != null and sky.sky_material is ShaderMaterial:
			_sky_material = sky.sky_material
	if sun != null:
		_sun_origin_quat = sun.quaternion


func _process(delta: float) -> void:
	if not _is_map_scene():
		return

	if _sky_material != null:
		var t: float = _sky_material.get_shader_parameter("overwritten_time")
		_sky_material.set_shader_parameter("overwritten_time", t + tick_speed * tickrate * delta)

	_advance_sun(delta)


## Advances the internal cycle clock by one physics frame and applies the result
## to the sun transform. The rotation is computed from a stored quaternion base
## so that `set_time` can snap to any absolute tick instantly.
func _advance_sun(delta: float) -> void:
	if sun == null:
		return
	if day_length_minutes <= 0.0:
		return

	var day_seconds := day_length_minutes * 60.0
	var ticks_per_second := DAY_TICKS / day_seconds
	_cycle_tick = fposmod(_cycle_tick + tickrate * ticks_per_second * delta, DAY_TICKS)
	_apply_sun_from_tick()


## Applies the sun's quaternion from the origin basis rotated by the current
## cycle tick (0-24000) around the global X axis, and flips `light_negative`
## when the sun dips below the horizon.
func _apply_sun_from_tick() -> void:
	var angle := _cycle_tick / DAY_TICKS * TAU
	sun.quaternion = _sun_origin_quat * Quaternion(Vector3.RIGHT, angle)

	# When the sun's light direction is within the bottom 120° of the rotation
	# arc (i.e. within 60° of pointing straight up, below the horizon), flip the
	# light so it doesn't look weird while the sun is down.
	var sun_dir: Vector3 = -sun.global_transform.basis.z
	var angle_from_up := acos(clampf(sun_dir.y / sun_dir.length(), -1.0, 1.0))
	sun.light_negative = angle_from_up <= deg_to_rad(60.0)


## Snaps the daylight cycle to an absolute tick position (0-24000) and
## immediately applies it to the sun transform. Used by the `time` console
## command.
func set_time(tick: float) -> void:
	_cycle_tick = fposmod(tick, DAY_TICKS)
	_apply_sun_from_tick()


## Returns the current cycle position in ticks (0-24000).
func get_time() -> float:
	return _cycle_tick


## Sets the time-scale multiplier for the daylight cycle. A value of 1.0 is
## normal speed; 2.0 doubles it; 0.5 halves it. Driven by the `tickrate`
## console command.
func set_tickrate(value: float) -> void:
	tickrate = maxf(value, 0.0)


## Returns the current time-scale multiplier.
func get_tickrate() -> float:
	return tickrate


## Returns true only while the current scene lives inside res://maps/ so this
## singleton does not tick in non-map scenes (menus, editor scenes, etc).
func _is_map_scene() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return scene.scene_file_path.begins_with("res://maps/")
