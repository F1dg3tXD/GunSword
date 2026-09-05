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

## The sun's path never comes within this many degrees of pointing straight up
## or straight down. Near the zenith/nadir it glides along the rim of this
## buffer cone instead of passing through vertical, which avoids the shadow
## acne/banding a flat ground shows under an exactly-overhead directional light.
## The same buffer is applied to the moon's orbit.
const SUN_VERTICAL_BUFFER_DEG := 30.0

## Peak time-scale multiplier used while the sky travels to a `time set` target.
## The tickrate eases up from 1 to this value and back down to 1, so changing
## the time feels smooth instead of a hard snap.
const TIME_TRAVEL_MAX_TICKRATE := 2400.0

## How many tickrate units per second the time travel ramps by. Accelerates to
## TIME_TRAVEL_MAX_TICKRATE in roughly a second, giving a smooth ease in/out.
const TIME_TRAVEL_TICKRATE_RATE := 80.0

## How long (in minutes) a full day/night cycle takes. Reserved for driving the
## sun rotation; not used by the shader tick.
## With the default 12 minutes = one 24-hour game-day, 1 game-hour is 30 seconds.
@export var day_length_minutes: float = 12.0
## How fast the sky's `overwritten_time` shader parameter advances per second.
## This acts as a time-scaling for the sky's animated effects (clouds, stars).
@export var tick_speed: float = 2.0

## The user-facing time-scale multiplier (1.0 is normal speed). Driven by the
## `tickrate` console command, and temporarily ramped up/down by a `time set`
## transition. Also speeds up eclipse dissipation and the sky `overwritten_time`
## clock.
var tickrate: float = 1.0

## How long (in game ticks) a forced eclipse holds the moon fully aligned with
## the sun before it starts dissipating. 1000 ticks = one game hour.
@export var eclipse_hold_ticks := 200.0

## How long (in game ticks, scaled by the current tickrate) a forced eclipse
## takes to fully dissipate back onto the moon's natural phase path.
@export var eclipse_dissipate_ticks := 1200.0

enum EclipsePhase { NONE, HOLD, DISSIPATE }

var _cycle_tick: float = 0.0
var _sky_material: ShaderMaterial
var _moon_origin_quat: Quaternion

## Eclipse lifecycle. The moon is kept aligned with the sun during HOLD, then
## gradually slerped back onto its natural phase path during DISSIPATE. In-game
## time (and therefore the current tickrate) drives both phases, so the eclipse
## no longer rides the sun all day.
var _eclipse_phase: EclipsePhase = EclipsePhase.NONE
var _eclipse_progress_tick: float = 0.0

## Active time-travel target in ticks (0-24000), or -1 when not travelling.
var _target_tick: float = -1.0

## Moon cone-traversal state: while the moon's raw light direction is inside the
## vertical buffer cone, its azimuth is tracked unwrapped frame-to-frame from the
## raw path so the rim glide stays continuous even as the raw azimuth pivots
## through the (near-)vertical point.
var _moon_cone_active: bool = false
var _moon_cone_az: float = 0.0


func _ready() -> void:
	if world_environment != null and world_environment.environment != null:
		var sky: Sky = world_environment.environment.sky
		if sky != null and sky.sky_material is ShaderMaterial:
			_sky_material = sky.sky_material
	if moon != null:
		_moon_origin_quat = moon.quaternion


func _process(delta: float) -> void:
	if not _is_map_scene():
		return

	if _sky_material != null:
		var t: float = _sky_material.get_shader_parameter("overwritten_time")
		_sky_material.set_shader_parameter("overwritten_time", t + tick_speed * tickrate * delta)

	_advance_sun(delta)
	_update_eclipse(delta)


## Advances the internal cycle clock by one physics frame and applies the result
## to the sun/moon transforms. If a time-travel target is active the effective
## tickrate is ramped up/down so the sky eases into the requested time.
func _advance_sun(delta: float) -> void:
	if sun == null:
		return
	if day_length_minutes <= 0.0:
		return

	var day_seconds := day_length_minutes * 60.0
	var ticks_per_second := DAY_TICKS / day_seconds

	if _target_tick >= 0.0:
		_travel_toward_target(delta, ticks_per_second)
	else:
		_cycle_tick = fposmod(_cycle_tick + tickrate * ticks_per_second * delta, DAY_TICKS)

	_apply_sun_from_tick()


## Steers the tickrate through a trapezoidal velocity profile while moving the
## cycle toward the target: ramp up to TIME_TRAVEL_MAX_TICKRATE, cruise, then
## ramp back down to 1 as the target approaches. Eases in and out smoothly.
func _travel_toward_target(delta: float, ticks_per_second: float) -> void:
	var forward_dist := fposmod(_target_tick - _cycle_tick, DAY_TICKS)

	# Ticks needed to fully decelerate from the current tickrate back down to 1,
	# so we start slowing at the right moment instead of overshooting.
	var decel_ticks := 0.5 * (tickrate * tickrate - 1.0) / TIME_TRAVEL_TICKRATE_RATE * ticks_per_second
	var desired := TIME_TRAVEL_MAX_TICKRATE
	if forward_dist <= decel_ticks:
		desired = 1.0

	if tickrate < desired:
		tickrate = minf(tickrate + TIME_TRAVEL_TICKRATE_RATE * delta, desired)
	elif tickrate > desired:
		tickrate = maxf(tickrate - TIME_TRAVEL_TICKRATE_RATE * delta, desired)

	var step := tickrate * ticks_per_second * delta
	if step >= forward_dist:
		_cycle_tick = _target_tick
		_target_tick = -1.0
		tickrate = 1.0
	else:
		_cycle_tick = fposmod(_cycle_tick + step, DAY_TICKS)


## Applies the sun's orientation from the current cycle tick (0-24000). The
## light-travel direction is remapped so it never points within
## SUN_VERTICAL_BUFFER_DEG of the world vertical: instead of passing straight
## down (overhead noon) or straight up (midnight) it glides along the rim of the
## buffer cone. `light_negative` flips when the sun dips below the horizon.
func _apply_sun_from_tick() -> void:
	var travel_dir := _sun_travel_direction(_cycle_tick / DAY_TICKS * TAU)
	sun.quaternion = Basis.looking_at(travel_dir, Vector3.UP).get_rotation_quaternion()

	var sun_dir: Vector3 = -sun.global_transform.basis.z
	var sun_angle_from_up := acos(clampf(sun_dir.y / sun_dir.length(), -1.0, 1.0))
	sun.light_negative = sun_angle_from_up <= deg_to_rad(60.0)

	_apply_moon()


## Maps a raw cycle angle (0-2PI) to the sunlight's travel direction. Outside
## the buffer cone this is the plain great-circle rotation around the world X
## axis (dawn at +Z, dusk at -Z). Near the zenith/nadir the direction is kept
## at exactly SUN_VERTICAL_BUFFER_DEG from vertical while its azimuth sweeps
## across the cone, so the result is continuous and never enters the cone.
func _sun_travel_direction(angle: float) -> Vector3:
	var delta := deg_to_rad(SUN_VERTICAL_BUFFER_DEG)
	angle = fposmod(angle, TAU)
	if angle < PI * 0.5 - delta:
		return _polar_travel_direction(angle)
	elif angle < PI * 0.5 + delta:
		var t := (angle - (PI * 0.5 - delta)) / (2.0 * delta)
		return _cone_rim_direction(t, -1.0)
	elif angle < 3.0 * PI * 0.5 - delta:
		return _polar_travel_direction(angle)
	elif angle < 3.0 * PI * 0.5 + delta:
		var t := (angle - (3.0 * PI * 0.5 - delta)) / (2.0 * delta)
		return _cone_rim_direction(t, 1.0)
	return _polar_travel_direction(angle)


## The un-modified great-circle path: rotating around the world X axis from the
## +Z horizon (dawn) through straight-down (noon) and straight-up (midnight).
func _polar_travel_direction(angle: float) -> Vector3:
	return Vector3(0.0, -sin(angle), cos(angle))


## A point on the rim of the SUN_VERTICAL_BUFFER_DEG vertical cone. `pole`
## selects the zenith (-1, sun at noon) or nadir (+1, sun at midnight). The
## vertical component stays pinned at cos(buffer) while the azimuth sweeps 0->PI
## across the cone, matching the plain path at both entry and exit.
func _cone_rim_direction(t: float, pole: float) -> Vector3:
	var delta := deg_to_rad(SUN_VERTICAL_BUFFER_DEG)
	var azimuth := t * PI
	return Vector3(sin(delta) * sin(azimuth), pole * cos(delta), -pole * sin(delta) * cos(azimuth))


## Applies the moon quaternion based on the current phase angle and eclipse
## state. The moon is a child of the sun node, so its local rotation is relative
## to the sun's orientation. During normal operation it drifts with a synodic
## phase offset (full moon opposes the sun, new moon aligns with it), and its
## world light direction is buffered away from vertical just like the sun so the
## moon's shadow can never hit the flat ground edge-on. During an eclipse the
## moon slerps toward identity (same world direction as the sun), which is
## already buffered, then peels back onto its natural path as the eclipse
## dissipates.
func _apply_moon() -> void:
	if moon == null:
		return

	var phase_angle := (_cycle_tick / DAY_TICKS) / LUNAR_MONTH_DAYS * TAU
	var phase_quat := _moon_origin_quat * Quaternion(Vector3.RIGHT, phase_angle)
	var blend := _eclipse_blend()
	if blend > 0.0:
		moon.quaternion = phase_quat.slerp(Quaternion.IDENTITY, blend)
		_moon_cone_active = false
	else:
		# Natural orbit (outside the buffer cone this reproduces the raw phase
		# rotation exactly; inside, the world direction is reprojected onto the
		# buffer rim). The result is expressed as a local quaternion relative to
		# the sun so the moon stays a child of the sun.
		var raw_dir: Vector3 = -(sun.global_transform.basis * Basis(phase_quat)).z
		var buffered := _buffer_moon_direction(raw_dir)
		var world_basis := Basis.looking_at(buffered, Vector3.UP)
		var local := sun.global_transform.basis.transposed() * world_basis
		moon.quaternion = local.get_rotation_quaternion()

	# Moon light is the inverse of the sun: only shines at night when the sun
	# is below the horizon.
	moon.light_negative = not sun.light_negative


## Keeps the moon's world light direction at least SUN_VERTICAL_BUFFER_DEG from
## the world vertical. Outside the cone the raw direction passes through
## unchanged (exactly the natural orbit). Inside, the direction is pinned to the
## rim, keeping the raw horizontal azimuth. That azimuth is tracked unwrapped
## across frames (instead of being recomputed from angle-to-vertical) so the rim
## glide stays continuous near the degenerate point the moon passes closest to
## vertical, where the raw horizontal azimuth is ill-defined.
func _buffer_moon_direction(raw: Vector3) -> Vector3:
	var delta := deg_to_rad(SUN_VERTICAL_BUFFER_DEG)
	var dir := raw.normalized()
	if absf(dir.y) <= cos(delta):
		_moon_cone_active = false
		return dir
	var horizontal := Vector2(dir.x, dir.z)
	if not _moon_cone_active:
		_moon_cone_active = true
		_moon_cone_az = horizontal.angle()
	_moon_cone_az += wrapf(horizontal.angle() - _moon_cone_az, -PI, PI)
	return Vector3(
		sin(delta) * cos(_moon_cone_az),
		signf(dir.y) * cos(delta),
		sin(delta) * sin(_moon_cone_az))


## Advances the eclipse lifecycle. Both phases are measured in game ticks, so a
## higher tickrate (including an active time-travel ramp) dissipates the eclipse
## faster in real time.
func _update_eclipse(delta: float) -> void:
	if _eclipse_phase == EclipsePhase.NONE:
		return
	if day_length_minutes <= 0.0:
		return

	var day_seconds := day_length_minutes * 60.0
	var ticks_per_second := DAY_TICKS / day_seconds
	var ticks := tickrate * ticks_per_second * delta

	match _eclipse_phase:
		EclipsePhase.HOLD:
			_eclipse_progress_tick += ticks
			if _eclipse_progress_tick >= eclipse_hold_ticks:
				_eclipse_phase = EclipsePhase.DISSIPATE
				_eclipse_progress_tick = 0.0
		EclipsePhase.DISSIPATE:
			_eclipse_progress_tick += ticks
			if _eclipse_progress_tick >= eclipse_dissipate_ticks:
				_eclipse_phase = EclipsePhase.NONE
				_eclipse_progress_tick = 0.0


## How strongly the moon is forced toward the sun (1.0 = fully eclipsed,
## 0.0 = natural orbit). 1 during hold, easing down to 0 through dissipation.
func _eclipse_blend() -> float:
	match _eclipse_phase:
		EclipsePhase.HOLD:
			return 1.0
		EclipsePhase.DISSIPATE:
			var t := clampf(_eclipse_progress_tick / eclipse_dissipate_ticks, 0.0, 1.0)
			return 1.0 - smoothstep(0.0, 1.0, t)
	return 0.0


## Snaps or smoothly travels the daylight cycle to an absolute tick position
## (0-24000). Rather than jumping, the tickrate eases up to 60 and back down to
## 1 so the sky accelerates into the requested time. Used by the `time` console
## command.
func set_time(tick: float) -> void:
	var target := fposmod(tick, DAY_TICKS)
	var dist := fposmod(target - _cycle_tick, DAY_TICKS)
	if dist < 1.0:
		_cycle_tick = target
		_target_tick = -1.0
		_apply_sun_from_tick()
		return
	tickrate = 1.0
	_target_tick = target


## Returns the current cycle position in ticks (0-24000).
func get_time() -> float:
	return _cycle_tick


## Sets the time-scale multiplier for the daylight cycle. A value of 1.0 is
## normal speed; 2.0 doubles it; 0.5 halves it. Driven by the `tickrate`
## console command. Overrides (cancels) any active time travel.
func set_tickrate(value: float) -> void:
	tickrate = maxf(value, 0.0)
	_target_tick = -1.0


## Returns the current time-scale multiplier.
func get_tickrate() -> float:
	return tickrate


## Activates an eclipse: forces the moon to align with the sun. The eclipse
## holds briefly, then smoothly dissipates as the moon returns to its natural
## orbit. A higher tickrate dissipates it faster.
func set_eclipse(active: bool = true) -> void:
	if active:
		_eclipse_phase = EclipsePhase.HOLD
	else:
		_eclipse_phase = EclipsePhase.NONE
	_eclipse_progress_tick = 0.0


## Returns true while an eclipse is active (held or dissipating).
func get_eclipse() -> bool:
	return _eclipse_phase != EclipsePhase.NONE


## Returns true only while the current scene lives inside res://maps/ so this
## singleton does not tick in non-map scenes (menus, editor scenes, etc).
func _is_map_scene() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return scene.scene_file_path.begins_with("res://maps/")
