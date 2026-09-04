extends Node3D

var day = true
@onready var sun: DirectionalLight3D = $sun
@onready var moon: DirectionalLight3D = $sun/moon
@onready var world_environment: WorldEnvironment = $WorldEnvironment

## Full length of one daylight cycle in Minecraft-style ticks (1 game-day = 24000).
## Console commands address time in these ticks; `time set 1800` / `time set night`
## map onto this 24-hour clock (1000 ticks per "hour").
const DAY_TICKS := 24000.0

## Synodic lunar month in game-days (~29.5 Earth days). The moon completes one
## full phase cycle relative to the sun over this many game-days.
const LUNAR_MONTH_DAYS := 29.5

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
var _moon_origin_quat: Quaternion

## Eclipse state. When true the moon is forced to align with the sun direction.
## Any `time set` or `tickrate` command clears this. The eclipse also expires
## naturally after one full synodic month.
var _eclipse: bool = false
var _eclipse_tick: float = 0.0


func _ready() -> void:
	if world_environment != null and world_environment.environment != null:
		var sky: Sky = world_environment.environment.sky
		if sky != null and sky.sky_material is ShaderMaterial:
			_sky_material = sky.sky_material
	if sun != null:
		_sun_origin_quat = sun.quaternion
	if moon != null:
		_moon_origin_quat = moon.quaternion


func _process(delta: float) -> void:
	if not _is_map_scene():
		return

	if _sky_material != null:
		var t: float = _sky_material.get_shader_parameter("overwritten_time")
		_sky_material.set_shader_parameter("overwritten_time", t + tick_speed * tickrate * delta)

	_advance_sun(delta)

	# A natural eclipse passes after one full synodic month.
	if _eclipse:
		_eclipse_tick += tickrate * delta * day_length_minutes * 60.0
		if _eclipse_tick >= DAY_TICKS * LUNAR_MONTH_DAYS:
			_eclipse = false


## Advances the internal cycle clock by one physics frame and applies the result
## to the sun/moon transforms. The rotation is computed from stored quaternion
## bases so that `set_time` can snap to any absolute tick instantly.
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
	var sun_angle := _cycle_tick / DAY_TICKS * TAU
	sun.quaternion = _sun_origin_quat * Quaternion(Vector3.RIGHT, sun_angle)

	var sun_dir: Vector3 = -sun.global_transform.basis.z
	var sun_angle_from_up := acos(clampf(sun_dir.y / sun_dir.length(), -1.0, 1.0))
	sun.light_negative = sun_angle_from_up <= deg_to_rad(60.0)

	_apply_moon()


## Applies the moon quaternion based on the current phase angle or eclipse state.
## The moon is a child of the sun node, so its local rotation is relative to
## the sun's orientation. During normal operation the moon drifts with a synodic
## phase offset (full moon opposes the sun, new moon aligns with it). During an
## eclipse the moon's local quaternion is set to identity so it points in the
## same world direction as the sun.
func _apply_moon() -> void:
	if moon == null:
		return

	if _eclipse:
		# Moon is child of sun; identity local quat = same world direction as sun.
		moon.quaternion = Quaternion.IDENTITY
	else:
		# Normal phase rotation: one full revolution over LUNAR_MONTH_DAYS game-
		# days. The moon starts opposite to the sun (as the scene is authored)
		# so at phase 0 the moon points away from the sun (full moon). As the
		# phase increases, the moon orbits toward new moon (aligned with sun)
		# at half a synodic month.
		var phase_angle := (_cycle_tick / DAY_TICKS) / LUNAR_MONTH_DAYS * TAU
		moon.quaternion = _moon_origin_quat * Quaternion(Vector3.RIGHT, phase_angle)

	# Moon light is the inverse of the sun: only shines at night when the sun
	# is below the horizon.
	moon.light_negative = not sun.light_negative


## Snaps the daylight cycle to an absolute tick position (0-24000) and
## immediately applies it to the sun transform. Any active eclipse is cleared.
## Used by the `time` console command.
func set_time(tick: float) -> void:
	_cycle_tick = fposmod(tick, DAY_TICKS)
	_eclipse = false
	_apply_sun_from_tick()


## Returns the current cycle position in ticks (0-24000).
func get_time() -> float:
	return _cycle_tick


## Sets the time-scale multiplier for the daylight cycle. A value of 1.0 is
## normal speed; 2.0 doubles it; 0.5 halves it. Driven by the `tickrate`
## console command. Any active eclipse is cleared.
func set_tickrate(value: float) -> void:
	tickrate = maxf(value, 0.0)
	_eclipse = false


## Returns the current time-scale multiplier.
func get_tickrate() -> float:
	return tickrate


## Activates an eclipse: forces the moon to align with the sun. The eclipse
## expires naturally after one synodic month, or is cleared immediately by any
## `time set` or `tickrate` command.
func set_eclipse(active: bool = true) -> void:
	_eclipse = active
	_eclipse_tick = 0.0


## Returns true while an eclipse is active (moon forced aligned with sun).
func get_eclipse() -> bool:
	return _eclipse


## Returns true only while the current scene lives inside res://maps/ so this
## singleton does not tick in non-map scenes (menus, editor scenes, etc).
func _is_map_scene() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return scene.scene_file_path.begins_with("res://maps/")
