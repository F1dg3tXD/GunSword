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
## or straight down. Instead of passing through vertical (or snapping onto the
## rim of a buffer cone), the path is smoothly eased so it stays at least this
## far from the axis, which avoids the shadow acne/banding a flat ground shows
## under an exactly-overhead directional light. The same buffer and easing are
## applied to the moon's orbit.
const SUN_VERTICAL_BUFFER_DEG := 30.0

## Width of the smooth ramp (in degrees) over which the path is eased away from
## the vertical axis. Outside this angle the light follows its raw orbit exactly;
## inside it, the tilt-from-axis is gradually clamped down to
## SUN_VERTICAL_BUFFER_DEG with a tangent-continuous profile, so there are no
## sharp corners at the entry/exit of the buffer zone.
const VERTICAL_BUFFER_RAMP_DEG := 50.0

## Half-width (in degrees) of the linear light_energy fade. A light pointing
## level (horizontal) gets 0.5 energy; pointing LIGHT_ENERGY_RAMP_DEG below the
## horizon ramps it to 1.0, pointing the same angle above it ramps it to 0.0.
const LIGHT_ENERGY_RAMP_DEG := 10.0

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

## No persistent state is needed for the moon's vertical avoidance: its raw
## orbit is a great circle (closed form in the phase angle), so the rounded pass
## is recomputed deterministically every frame.


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
## down (overhead noon) or straight up (midnight), the raw great-circle path is
## smoothly eased around the buffer zone. light_energy fades with how far the
## light tilts below the horizon, and `light_negative` flips when the sun dips
## below the horizon.
func _apply_sun_from_tick() -> void:
	var travel_dir := _sun_travel_direction(_cycle_tick / DAY_TICKS * TAU)
	sun.quaternion = Basis.looking_at(travel_dir, Vector3.UP).get_rotation_quaternion()

	var sun_dir: Vector3 = -sun.global_transform.basis.z
	sun.light_energy = _light_energy_for_direction(sun_dir)
	var sun_angle_from_up := acos(clampf(sun_dir.y / sun_dir.length(), -1.0, 1.0))
	sun.light_negative = sun_angle_from_up <= deg_to_rad(60.0)

	_apply_moon()


## The un-modified great-circle path: rotating around the world X axis from the
## +Z horizon (dawn) through straight-down (noon) and straight-up (midnight).
func _polar_travel_direction(angle: float) -> Vector3:
	return Vector3(0.0, -sin(angle), cos(angle))


## Closed-form smoothed sun path. The raw great circle (which passes straight
## through the vertical axis) is eased so that near the zenith/nadir it rounds
## the axis at least SUN_VERTICAL_BUFFER_DEG away: the tilt-from-axis is molded
## by _avoided_tilt and the azimuth sweeps smoothly across each rounded pass,
## giving a C1 path with tangent matching at entry/exit and no sharp corners.
func _sun_travel_direction(angle: float) -> Vector3:
	angle = fposmod(angle, TAU)
	var ramp := deg_to_rad(VERTICAL_BUFFER_RAMP_DEG)
	var half := PI * 0.5

	# Bottom pass (noon, pointing near straight down).
	if angle > half - ramp and angle < half + ramp:
		return _sun_rounded_direction(angle, half, -1.0)
	# Top pass (midnight, pointing near straight up).
	var top := 3.0 * half
	if angle > top - ramp and angle < top + ramp:
		return _sun_rounded_direction(angle, top, 1.0)
	return _polar_travel_direction(angle)


## One rounded pass though the buffer zone. `center` is the cycle angle at which
## the raw path would point straight at the vertical axis, `y_sign` is which pole
## it rounds. The tilt-from-axis eases in and back out (matching the raw path's
## slope at both ends) while the azimuth sweeps a half turn, so the pass touches
## the buffer boundary once at its deepest point.
func _sun_rounded_direction(angle: float, center: float, y_sign: float) -> Vector3:
	var ramp := deg_to_rad(VERTICAL_BUFFER_RAMP_DEG)
	var p := clampf((angle - (center - ramp)) / (2.0 * ramp), 0.0, 1.0)
	var tilt_m: float = _avoided_tilt(absf(angle - center))
	# Horizontal azimuth on entry: the raw path arrives from +Z on the bottom
	# pass and from -Z on the top pass.
	var az_start := PI * 0.5 if y_sign < 0.0 else -PI * 0.5
	var az := az_start + PI * _eased_sweep(p)
	return Vector3(
		sin(tilt_m) * cos(az),
		y_sign * cos(tilt_m),
		sin(tilt_m) * sin(az))


## Eases the tilt-from-axis (radians, 0 = exactly on the axis) into the buffer
## range using a tangent-continuous ramp that attaches to the raw path at the
## VERTICAL_BUFFER_RAMP_DEG boundary.
func _avoided_tilt(tilt: float) -> float:
	var cap := deg_to_rad(VERTICAL_BUFFER_RAMP_DEG)
	var delta := deg_to_rad(SUN_VERTICAL_BUFFER_DEG)
	var u := clampf(tilt / cap, 0.0, 1.0)
	var s := 0.5 * u * u + 0.5 * u * u * u
	return lerp(delta, cap, s)


## Fades a directional light's energy with its pitch: level (horizontal) = 0.5,
## LIGHT_ENERGY_RAMP_DEG below the horizon = 1.0, and the same angle above the
## horizon = 0.0.
func _light_energy_for_direction(dir: Vector3) -> float:
	var elev := asin(clampf(dir.y / dir.length(), -1.0, 1.0))
	return clampf(0.5 - elev / deg_to_rad(LIGHT_ENERGY_RAMP_DEG), 0.0, 1.0)


## Applies the moon quaternion based on the current phase angle and eclipse
## state. The moon is a child of the sun node, so its local rotation is relative
## to the sun's orientation. During normal operation it drifts with a synodic
## phase offset (full moon opposes the sun, new moon aligns with it), and its
## world light direction is eased away from vertical just like the sun so the
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
	else:
		# Natural orbit (outside the buffer ramp this reproduces the raw phase
		# rotation exactly; inside, the world direction is smoothly rounded over
		# the vertical axis so its tilt-from-axis stays at least
		# SUN_VERTICAL_BUFFER_DEG). The result is expressed as a local quaternion
		# relative to the sun so the moon stays a child of the sun.
		var world_basis := _moon_world_basis(phase_angle, phase_quat)
		var local := sun.global_transform.basis.transposed() * world_basis
		moon.quaternion = local.get_rotation_quaternion()

	moon.light_energy = _light_energy_for_direction(-moon.global_transform.basis.z)
	# Moon light is the inverse of the sun: only shines at night when the sun
	# is below the horizon.
	moon.light_negative = not sun.light_negative


## Computes the moon's world orientation basis. Out in its raw orbit this is just
## the phase rotation applied inside the sun's frame. As the orbit passes closest
## to the world vertical (its great-circle path can brush or even cross the axis)
## the pass is rounded: the tilt-from-axis is eased down to exactly
## SUN_VERTICAL_BUFFER_DEG and the azimuth sweeps a half turn, mirroring the sun's
## treatment. Because the raw orbit is a closed-form great circle in the phase
## angle, this rounding is recomputed deterministically every frame - no state.
func _moon_world_basis(phase_angle: float, phase_quat: Quaternion) -> Basis:
	var raw_world := sun.global_transform.basis * Basis(phase_quat)

	var ramp := deg_to_rad(VERTICAL_BUFFER_RAMP_DEG)
	var cos_ramp := cos(ramp)

	# The raw orbit sweeps the great circle spanned by the sun's local Z and Y:
	#   moon_dir(phase) = cos(phase) * sun.z + sin(phase) * sun.y
	var e1: Vector3 = sun.global_transform.basis.z
	var e2: Vector3 = sun.global_transform.basis.y
	var c: float = Vector3.UP.dot(e1)
	var s: float = Vector3.UP.dot(e2)
	var m := sqrt(c * c + s * s)
	if m < cos_ramp:
		return raw_world  # the orbit never gets within the ramp of vertical

	var psi_star := atan2(s, c)
	var center_a := (c * e1 + s * e2) / m
	var perp_a := (-s * e1 + c * e2) / m
	var psi_r := acos(clampf(cos_ramp / m, 0.0, 1.0))

	# The orbit crosses (or grazes) the axis twice per complete phase cycle, so
	# check both poles; they are PI apart on the circle.
	var attempt: Variant = _moon_rounded_pass(phase_angle, psi_star, center_a, perp_a, m, psi_r, ramp)
	if attempt != null:
		return attempt
	attempt = _moon_rounded_pass(phase_angle - PI, psi_star, -center_a, -perp_a, m, psi_r, ramp)
	if attempt != null:
		return attempt
	return raw_world


## One rounded pass of the moon's orbit around a vertical pole. `center` is the
## orbit direction that comes closest to (or through) the world axis, `perp` the
## perpendicular direction on the great circle. Inside the ramp band the
## tilt-from-axis is eased down to SUN_VERTICAL_BUFFER_DEG and the azimuth is
## swept smoothly from the raw entry azimuth to the raw exit azimuth, so the
## rounded pass matches the raw orbit exactly (position and tangent) at both ends.
func _moon_rounded_pass(phase: float, psi_star: float, center: Vector3, perp: Vector3, m: float, psi_r: float, ramp: float):
	var psi := phase - psi_star
	if absf(psi) >= psi_r:
		return null

	var entry_raw: Vector3 = center * cos(psi_r) - perp * sin(psi_r)
	var exit_raw: Vector3 = center * cos(psi_r) + perp * sin(psi_r)
	var az_start := Vector2(entry_raw.x, entry_raw.z).angle()
	var az_end := Vector2(exit_raw.x, exit_raw.z).angle()
	var az_span := wrapf(az_end - az_start, -PI, PI)

	var tilt := acos(clampf(absf(m * cos(psi)), -1.0, 1.0))
	var tilt_m: float = _avoided_tilt(tilt)

	var p := clampf((psi + psi_r) / (2.0 * psi_r), 0.0, 1.0)
	var az := az_start + az_span * _eased_sweep(p)

	var y_sign: float = 1.0 if center.y >= 0.0 else -1.0
	var dir := Vector3(
		cos(az) * sin(tilt_m),
		y_sign * cos(tilt_m),
		sin(az) * sin(tilt_m))
	return Basis.looking_at(dir, Vector3.UP)


## Eases the azimuth sweep across a rounded pass. The raw great circle rotates
## fast near the axis, so the sweep has to carry that motion while the tilt is
## floored; a plain smoothstep (or a mild linear blend) leaves the direction
## nearly stopped in the middle of the pass. This profile keeps the tangent
## close to the raw orbit at the entry/exit (steep end slope) and pushes extra
## azimuth through the middle where the tilt is pinned, so the direction keeps
## moving smoothly instead of hesitating at the axis.
func _eased_sweep(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	var smooth := c * c * (3.0 - 2.0 * c)
	var linear := c
	var blend := lerpf(smooth, linear, 0.85)
	var center := c * c * (1.0 - c) * (1.0 - c) * (2.0 * c - 1.0)
	return blend + 1.16 * center


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
