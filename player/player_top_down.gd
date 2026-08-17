extends CharacterBody3D

signal damaged
signal health_changed(health: float, max_health: float)

const GRAVITY := 20.0

@export_range(0.5, 10.0, 0.1) var walk_speed := 3.0
@export_range(0.5, 12.0, 0.1) var sprint_speed := 4.5
@export_range(0.5, 5.0, 0.1) var max_jump_height := 0.9

enum FireMode { BLASTER, LASER }

const SWORD_SLASH_FUEL := 0.1
const BLASTER_DRAIN_PER_SHOT := 0.05
const LASER_DRAIN_PER_SECOND := 0.1

const MAX_AIM_DIST := 5.0
const LOOK_ARROW_MAX_POS := 1.0
const LOOK_ARROW_MAX_SCALE := 5.0
const PAN_TRIGGER_STRENGTH := 0.25
const CROSSHAIR_SPIN_SPEED := 3.0
const AIM_SMOOTHING := 12.0
const CROSSHAIR_SCALE_SMOOTHING := 30.0
const ROT_SMOOTHING := 15.0
const STICK_DEADZONE := 0.2
const MOUSE_RECENTER_DELAY := 0.5
const CAM_ORBIT_SPEED := 1.5
const CAM_PITCH_MIN := -1.45
const CAM_PITCH_MAX := 1.2
const HIDE_OS_CURSOR := true

const CAM_MODIFIER_TAP_THRESHOLD := 0.2
const TARGET_SWAP_COOLDOWN := 0.3

enum TargetType { ENEMY, FRIEND, POI }

const TARGET_COLORS := {
	TargetType.ENEMY: Color(1.0, 0.25, 0.25),
	TargetType.FRIEND: Color(0.25, 1.0, 0.25),
	TargetType.POI: Color(1.0, 1.0, 0.25),
}

const TARGET_GROUPS := {
	"enemy": TargetType.ENEMY,
	"friend": TargetType.FRIEND,
	"poi": TargetType.POI,
}

enum AimScheme { NONE, STICK, MOUSE }

@onready var sprite: AnimatedSprite3D = $sprite
@onready var look_arrow: TextureRect = $AimUI/look_arrow
@onready var crosshair: TextureRect = $AimUI/crosshair
@onready var pause_menu_layer: CanvasLayer = $PauseMenuLayer
@onready var camera_rig: Node3D = $CameraRig
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var camera_3d: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var mobile_controls: CanvasLayer = $MobileControls

@onready var target_area: Area3D = $targetArea

var move_stick := Vector2.ZERO
var aim_stick := Vector2.ZERO

var facing_right := false
var is_gun := false
var _action_anim := ""

var fire_mode: FireMode = FireMode.BLASTER
var blaster_charge := 1.0
var laser_charge := 1.0
var _laser_was_firing := false

var max_health := 100
var health := 100

var _aim_scheme := AimScheme.NONE
var _aim_offset := Vector2.ZERO
var _aim_strength := 0.0
var _pan_strength := 0.0
var _mouse_idle_time := 1.0

var _cam_pressed := false
var _cam_press_time := 0.0
var _targeting := false
var _current_target: Node3D = null
var _target_swap_cooldown := 0.0
var _crosshair_material: ShaderMaterial = null
var _mouse_delta := Vector2.ZERO

var _movement_locked := false
var _dialogue_locked := false
var _move_dir := Vector2.ZERO
var _moving := false
var cutscene_velocity := Vector3.ZERO


func lock_movement() -> void:
	## Blocks input-driven movement, e.g. while a cutscene plays.
	## Scripted movement (set_cutscene_velocity) still works.
	_movement_locked = true


func unlock_movement() -> void:
	_movement_locked = false


func set_cutscene_velocity(new_velocity: Vector3) -> void:
	## Moves the player while movement is locked, for cutscenes.
	## Pass Vector3.ZERO to stop.
	cutscene_velocity = new_velocity


func _ready() -> void:
	add_to_group("player")
	if HIDE_OS_CURSOR:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	look_arrow.position = Vector2.ZERO
	look_arrow.scale = Vector2.ZERO
	crosshair.scale = Vector2.ZERO
	_crosshair_material = crosshair.material as ShaderMaterial
	camera_3d.current = true
	spring_arm.add_excluded_object(get_rid())
	sprite.play("idle")
	_update_mobile_controls()
	XMBSave.register_save_adapter(self)


func _exit_tree() -> void:
	if HIDE_OS_CURSOR:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_aim_scheme = AimScheme.MOUSE
		_mouse_idle_time = 0.0
	if event is InputEventMouseMotion and Input.is_action_pressed("cam_modifier"):
		_mouse_delta += event.relative


func _physics_process(delta: float) -> void:
	move_stick = Input.get_vector("left", "right", "up", "down")
	aim_stick = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")

	if Input.is_action_just_pressed("cam_modifier"):
		_cam_pressed = true
		_cam_press_time = 0.0
	if _cam_pressed:
		_cam_press_time += delta
		if not Input.is_action_pressed("cam_modifier"):
			if _cam_press_time <= CAM_MODIFIER_TAP_THRESHOLD:
				_toggle_targeting()
			_cam_pressed = false

	_dialogue_locked = _dialogue_on_screen()
	var input_move := move_stick if not (_movement_locked or _dialogue_locked) else Vector2.ZERO
	if cutscene_velocity != Vector3.ZERO:
		velocity = cutscene_velocity
		_move_dir = _world_to_camera_space(cutscene_velocity).normalized()
		_moving = true
	else:
		var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
		var horizontal := _camera_space_to_world(input_move) * speed
		velocity.x = horizontal.x
		velocity.z = horizontal.z
		if is_on_floor():
			if not _dialogue_locked and not _movement_locked and Input.is_action_just_pressed("jump"):
				velocity.y = _jump_velocity()
			else:
				velocity.y -= GRAVITY * delta
		else:
			if Input.is_action_just_released("jump") and velocity.y > 0.0:
				velocity.y = 0.0
			velocity.y -= GRAVITY * delta
		_moving = input_move.length() > 0.01
		_move_dir = input_move.normalized() if _moving else Vector2.ZERO
	move_and_slide()

	_update_weapon()
	_update_shot_type()
	_update_charge(delta)
	_update_animation()
	_update_aim(delta)
	_update_targeting(delta)
	_update_camera(delta)
	_update_pause()
	_update_mobile_controls()


func _camera_space_to_world(v: Vector2) -> Vector3:
	## Camera-space uses the Godot screen convention: +x = screen right,
	## +y = screen down. Maps to the ground plane relative to the camera yaw.
	## Used for character movement only (stays horizontal).
	var basis := camera_rig.global_transform.basis
	return basis.x * v.x + basis.z * v.y


func _aim_to_world(v: Vector2) -> Vector3:
	## Maps a camera-space aim offset to a world offset from the player using
	## the camera's FULL orientation (yaw + pitch), so panning is relative to
	## the camera rotation. Aiming up raises the aim point above the ground
	## (for aerial targets later); aiming below the ground clamps to it.
	var basis := camera_3d.global_transform.basis
	var offset := basis.x * v.x - basis.y * v.y
	if offset.y < 0.0:
		offset.y = 0.0
	return offset


func _world_to_camera_space(v: Vector3) -> Vector2:
	var basis := camera_rig.global_transform.basis
	return Vector2(basis.x.dot(v), basis.z.dot(v))


func _update_weapon() -> void:
	if Input.is_action_just_pressed("fire1") and not is_gun:
		is_gun = true
		_play_action("switchGun")
	elif Input.is_action_just_released("fire1") and is_gun:
		is_gun = false

	if Input.is_action_just_pressed("fire0"):
		if is_gun:
			if fire_mode == FireMode.BLASTER:
				_fire_blaster()
		else:
			_play_action("slash")
			add_kinetic_fuel(SWORD_SLASH_FUEL)


func _update_shot_type() -> void:
	if Input.is_action_just_pressed("shot_type_cycle"):
		_cycle_fire_mode(1)


func _jump_velocity() -> float:
	return sqrt(2.0 * GRAVITY * max_jump_height)


func _cycle_fire_mode(direction: int) -> void:
	var modes := [FireMode.BLASTER, FireMode.LASER]
	var index := modes.find(fire_mode)
	if index < 0:
		index = 0
	fire_mode = modes[(index + direction + modes.size()) % modes.size()]


func _update_charge(delta: float) -> void:
	var laser_active := is_gun and fire_mode == FireMode.LASER and Input.is_action_pressed("fire0")
	if laser_active and laser_charge > 0.0:
		laser_charge = maxf(laser_charge - LASER_DRAIN_PER_SECOND * delta, 0.0)
		if not _laser_was_firing:
			_play_action("gunFire")
		_laser_was_firing = true
	else:
		_laser_was_firing = false


func set_fire_mode(mode: FireMode) -> void:
	fire_mode = mode


func take_damage(amount: float) -> void:
	if amount <= 0.0 or health <= 0:
		return
	health = maxi(health - int(round(amount)), 0)
	health_changed.emit(health, max_health)
	damaged.emit()


func add_kinetic_fuel(amount: float) -> void:
	## Slash attacks charge the gauge of the current fire mode.
	## If that gauge is full, overflow goes to the other gauge.
	if amount <= 0.0:
		return

	var primary := "blaster_charge" if fire_mode == FireMode.BLASTER else "laser_charge"
	var current: float = get(primary)
	var room := 1.0 - current
	if room >= amount:
		set(primary, current + amount)
		return

	set(primary, 1.0)
	var overflow := amount - room
	var other := "laser_charge" if fire_mode == FireMode.BLASTER else "blaster_charge"
	set(other, clampf(get(other) + overflow, 0.0, 1.0))


func _fire_blaster() -> void:
	if blaster_charge < BLASTER_DRAIN_PER_SHOT:
		return
	blaster_charge = maxf(blaster_charge - BLASTER_DRAIN_PER_SHOT, 0.0)
	_play_action("gunFire")


func _play_action(anim: String) -> void:
	if _action_anim != "" and _action_anim != anim:
		sprite.sprite_frames.set_animation_loop(_action_anim, true)
	_action_anim = anim
	sprite.sprite_frames.set_animation_loop(anim, false)
	sprite.play(anim)


func _update_animation() -> void:
	if _action_anim != "":
		if not sprite.is_playing():
			sprite.sprite_frames.set_animation_loop(_action_anim, true)
			_action_anim = ""
			_update_movement_anim()
		return

	_update_movement_anim()


func _update_movement_anim() -> void:
	var anim := "idle"
	if _moving:
		if _move_dir.y < 0.0 and abs(_move_dir.x) <= abs(_move_dir.y):
			anim = "walkUp"
		elif _move_dir.y > 0.0 and abs(_move_dir.x) <= abs(_move_dir.y):
			anim = "walkDown"
		elif _move_dir.y < 0.0:
			anim = "walkUpLeft"
		else:
			anim = "runLeft"

	if _pan_strength > 0.0:
		if abs(_aim_offset.x) > 1.0:
			facing_right = not (_aim_offset.x > 0.0)
	elif _moving:
		if abs(_move_dir.x) > 0.1:
			facing_right = not (_move_dir.x > 0.0)

	if sprite.flip_h != facing_right:
		sprite.flip_h = facing_right
	if sprite.animation != anim:
		sprite.play(anim)


func _update_aim(delta: float) -> void:
	if _targeting and _current_target != null:
		_aim_offset = Vector2.ZERO
		_aim_strength = 0.0
		_pan_strength = 0.0
		var to_target := _current_target.global_position - global_position
		if to_target.length_squared() > 0.01:
			var cam_right := camera_rig.global_transform.basis.x
			facing_right = cam_right.dot(to_target) > 0.0
		var target_screen := camera_3d.unproject_position(_current_target.global_position + Vector3.UP * 0.7)
		var viewport_size := get_viewport().get_visible_rect().size
		crosshair.position = target_screen - crosshair.pivot_offset
		crosshair.rotation = 0.0
		crosshair.scale = Vector2.ONE
		look_arrow.position = Vector2.ZERO
		look_arrow.scale = Vector2.ZERO
		return

	var orbit_active := Input.is_action_pressed("cam_modifier")
	if not orbit_active and aim_stick.length() > STICK_DEADZONE:
		_aim_scheme = AimScheme.STICK

	_mouse_idle_time += delta

	var target_offset := Vector2.ZERO
	match _aim_scheme:
		AimScheme.STICK:
			if not orbit_active and aim_stick.length() > STICK_DEADZONE:
				target_offset = aim_stick * MAX_AIM_DIST
		AimScheme.MOUSE:
			if _mouse_idle_time < MOUSE_RECENTER_DELAY:
				target_offset = _mouse_aim_offset()

	var smooth := 1.0 - exp(-AIM_SMOOTHING * delta)
	_aim_offset = _aim_offset.lerp(target_offset, smooth)
	_aim_strength = clampf(_aim_offset.length() / MAX_AIM_DIST, 0.0, 1.0)
	_pan_strength = clampf((_aim_strength - PAN_TRIGGER_STRENGTH) / (1.0 - PAN_TRIGGER_STRENGTH), 0.0, 1.0)

	var anchor := global_position + Vector3.UP * 0.7
	var aim_world := _aim_to_world(_aim_offset)
	var viewport_size := get_viewport().get_visible_rect().size
	var aim_screen := camera_3d.unproject_position(anchor + aim_world)
	var crosshair_center := aim_screen.clamp(Vector2(40, 40), viewport_size - Vector2(40, 40))
	crosshair.position = crosshair_center - crosshair.pivot_offset
	crosshair.rotation += CROSSHAIR_SPIN_SPEED * delta
	crosshair.scale = crosshair.scale.lerp(Vector2.ONE * _pan_strength, 1.0 - exp(-CROSSHAIR_SCALE_SMOOTHING * delta))

	if aim_world.length() > 0.01:
		look_arrow.rotation = lerp_angle(look_arrow.rotation, _aim_offset.angle() - PI / 2.0, 1.0 - exp(-ROT_SMOOTHING * delta))

	var arrow_target := camera_3d.unproject_position(anchor + _aim_to_world(_aim_offset.limit_length(LOOK_ARROW_MAX_POS))) - look_arrow.pivot_offset
	look_arrow.position = look_arrow.position.lerp(arrow_target, smooth)
	look_arrow.scale = look_arrow.scale.lerp(Vector2.ONE * LOOK_ARROW_MAX_SCALE * _pan_strength, smooth)


func _mouse_aim_offset() -> Vector2:
	var viewport := get_viewport()
	var viewport_size := viewport.get_visible_rect().size
	var max_px := minf(viewport_size.x, viewport_size.y) * 0.5
	var from_center := viewport.get_mouse_position() - viewport_size * 0.5
	return (from_center / max_px).limit_length(1.0) * MAX_AIM_DIST


func _update_camera(delta: float) -> void:
	var orbit_active := Input.is_action_pressed("cam_modifier") and _cam_press_time > CAM_MODIFIER_TAP_THRESHOLD
	if orbit_active and not _targeting:
		if aim_stick.length() > STICK_DEADZONE:
			camera_rig.rotation.y += aim_stick.x * CAM_ORBIT_SPEED * delta
			spring_arm.rotation.x = clampf(spring_arm.rotation.x + aim_stick.y * CAM_ORBIT_SPEED * delta, CAM_PITCH_MIN, CAM_PITCH_MAX)
		if _mouse_delta.length_squared() > 0.001:
			camera_rig.rotation.y -= _mouse_delta.x * 0.003
			spring_arm.rotation.x = clampf(spring_arm.rotation.x - _mouse_delta.y * 0.003, CAM_PITCH_MIN, CAM_PITCH_MAX)
	_mouse_delta = Vector2.ZERO

	var smooth := 1.0 - exp(-AIM_SMOOTHING * delta)

	if _targeting and _current_target != null and is_instance_valid(_current_target):
		var to_target := _current_target.global_position - global_position
		if to_target.length_squared() > 0.01:
			var target_yaw := atan2(-to_target.x, -to_target.z)
			camera_rig.rotation.y = lerp_angle(camera_rig.rotation.y, target_yaw, smooth)
		camera_rig.position = camera_rig.position.lerp(Vector3.ZERO, smooth)
	else:
		var aim_active := _pan_strength > 0.0
		var aim_world := _aim_to_world(_aim_offset)
		var target_pos := Vector3(aim_world.x, 0.0, aim_world.z) if aim_active else Vector3.ZERO
		camera_rig.position = camera_rig.position.lerp(target_pos, smooth)


func _update_pause() -> void:
	if Input.is_action_just_pressed("pause"):
		pause_menu_layer.show()


func _update_mobile_controls() -> void:
	var on_mobile := OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")
	var ui_open := _is_menu_visible() or _dialogue_on_screen()
	mobile_controls.visible = on_mobile and not ui_open
	if not on_mobile:
		return
	Input.emulate_mouse_from_touch = ui_open


func _is_menu_visible() -> bool:
	return pause_menu_layer.visible


func _dialogue_on_screen() -> bool:
	return get_tree().get_first_node_in_group("dialogue_balloon") != null


func _toggle_targeting() -> void:
	if _targeting:
		_release_target()
	else:
		_acquire_target()


func _acquire_target() -> void:
	var targets := _get_targets_in_area()
	if targets.is_empty():
		return
	targets.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var sa := camera_3d.unproject_position(a.global_position).x
		var sb := camera_3d.unproject_position(b.global_position).x
		return sa < sb
	)
	_current_target = targets[0]
	_targeting = true
	_update_target_color()
	_set_target_z_targeted(_current_target, true)


func _release_target() -> void:
	if _current_target != null:
		_set_target_z_targeted(_current_target, false)
	_targeting = false
	_current_target = null
	_target_swap_cooldown = 0.0
	if _crosshair_material != null:
		_crosshair_material.set_shader_parameter("modulate_color", Color.WHITE)


func _set_target_z_targeted(target: Node3D, active: bool) -> void:
	for child in target.find_children("*", "Node", true, false):
		if child.has_method("set_z_targeted"):
			child.set_z_targeted(active)


func _get_targets_in_area() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var shape: SphereShape3D = target_area.get_node("CollisionShape3D").shape as SphereShape3D
	var max_dist := shape.radius if shape else 7.0
	var max_dist_sq := max_dist * max_dist
	for node in get_tree().get_nodes_in_group("target"):
		if not node is Node3D:
			continue
		if global_position.distance_squared_to(node.global_position) > max_dist_sq:
			continue
		result.append(node)
	return result


func _get_target_type(target: Node3D) -> TargetType:
	var n: Node = target
	while n != null:
		for group_name in TARGET_GROUPS:
			if n.is_in_group(group_name):
				return TARGET_GROUPS[group_name]
		n = n.get_parent()
	return TargetType.POI


func _update_targeting(delta: float) -> void:
	_target_swap_cooldown = maxf(_target_swap_cooldown - delta, 0.0)

	if not _targeting:
		return

	if _current_target == null or not is_instance_valid(_current_target):
		_release_target()
		return

	var targets := _get_targets_in_area()
	if targets.is_empty():
		_release_target()
		return

	if _current_target not in targets:
		_set_target_z_targeted(_current_target, false)
		_current_target = targets[0]
		_set_target_z_targeted(_current_target, true)
		_update_target_color()

	var swap_input := aim_stick.x
	if abs(swap_input) > STICK_DEADZONE and _target_swap_cooldown <= 0.0:
		var direction := 1 if swap_input > 0.0 else -1
		targets.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			var sa := camera_3d.unproject_position(a.global_position).x
			var sb := camera_3d.unproject_position(b.global_position).x
			return sa < sb
		)
		var index := targets.find(_current_target)
		if index >= 0:
			_set_target_z_targeted(_current_target, false)
			index = (index + direction + targets.size()) % targets.size()
			_current_target = targets[index]
			_set_target_z_targeted(_current_target, true)
			_update_target_color()
			_target_swap_cooldown = TARGET_SWAP_COOLDOWN


func _update_target_color() -> void:
	if _crosshair_material == null or _current_target == null:
		return
	var color: Color = TARGET_COLORS.get(_get_target_type(_current_target), Color.WHITE)
	_crosshair_material.set_shader_parameter("modulate_color", color)


func capture_save_state() -> Dictionary:
	var savables := {}
	for savable in get_tree().get_nodes_in_group("savable"):
		if not savable.has_method("capture"):
			continue
		var data = savable.capture()
		if data is Dictionary and not data.is_empty():
			savables[str(savable.get_path())] = data

	return {
		"position": global_position,
		"health": health,
		"max_health": max_health,
		"is_gun": is_gun,
		"fire_mode": fire_mode,
		"blaster_charge": blaster_charge,
		"laser_charge": laser_charge,
		"savables": savables,
	}


func apply_save_state(payload: Dictionary) -> void:
	var state: Dictionary = payload.get("state", {})
	if state.is_empty():
		return

	if state.has("position"):
		global_position = state["position"]
	if state.has("max_health"):
		max_health = maxi(int(state["max_health"]), 1)
	if state.has("health"):
		health = clampi(int(state["health"]), 0, max_health)
	if state.has("is_gun"):
		is_gun = state["is_gun"]
	if state.has("fire_mode"):
		fire_mode = state["fire_mode"]
	if state.has("blaster_charge"):
		blaster_charge = clampf(state["blaster_charge"], 0.0, 1.0)
	if state.has("laser_charge"):
		laser_charge = clampf(state["laser_charge"], 0.0, 1.0)

	health_changed.emit(health, max_health)

	var savables: Dictionary = state.get("savables", {})
	for path_str in savables:
		var node := get_tree().root.get_node_or_null(NodePath(path_str))
		if node != null and node.has_method("apply"):
			node.apply(savables[path_str])
