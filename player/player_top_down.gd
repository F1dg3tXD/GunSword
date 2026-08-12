extends CharacterBody2D

signal damaged
signal health_changed(health: float, max_health: float)

const SPEED := 300.0

enum FireMode { BLASTER, LASER }

const SWORD_SLASH_FUEL := 0.1
const BLASTER_DRAIN_PER_SHOT := 0.05
const LASER_DRAIN_PER_SECOND := 0.1

const MAX_AIM_DIST := 500.0
const LOOK_ARROW_MAX_POS := 100.0
const LOOK_ARROW_MAX_SCALE := 5.0
const LOOK_ARROW_FORWARD_ANGLE := -PI / 2.0
const PAN_TRIGGER_STRENGTH := 0.25
const CROSSHAIR_SPIN_SPEED := 3.0
const AIM_SMOOTHING := 12.0
const CROSSHAIR_SCALE_SMOOTHING := 30.0
const ROT_SMOOTHING := 15.0
const STICK_DEADZONE := 0.2
const MOUSE_RECENTER_DELAY := 0.5
const HIDE_OS_CURSOR := true

enum AimScheme { NONE, STICK, MOUSE }

@onready var sprite: AnimatedSprite2D = $sprite
@onready var look_dir: Node2D = $lookDir
@onready var look_arrow: Sprite2D = $lookDir/look_arrow
@onready var crosshair: Node2D = $crosshair
@onready var crosshair_sprite: Sprite2D = $crosshair/crosshair_sprite
@onready var pause_menu_layer: CanvasLayer = $PauseMenuLayer
@onready var camera_2d: Camera2D = $DampedSpringJoint2D/CameraCollider/Camera2D
@onready var camera_collider: RigidBody2D = $DampedSpringJoint2D/CameraCollider
@onready var mobile_controls: CanvasLayer = $DampedSpringJoint2D/CameraCollider/Camera2D/MobileControls

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
var _camera_on_collider := true

var _movement_locked := false
var _dialogue_locked := false
var _move_dir := Vector2.ZERO
var _moving := false
var cutscene_velocity := Vector2.ZERO


func lock_movement() -> void:
	## Blocks input-driven movement, e.g. while a cutscene plays.
	## Scripted movement (set_cutscene_velocity) still works.
	_movement_locked = true


func unlock_movement() -> void:
	_movement_locked = false


func set_cutscene_velocity(new_velocity: Vector2) -> void:
	## Moves the player while movement is locked, for cutscenes.
	## Pass Vector2.ZERO to stop.
	cutscene_velocity = new_velocity


func _ready() -> void:
	add_to_group("player")
	if HIDE_OS_CURSOR:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	look_arrow.position = Vector2.ZERO
	look_arrow.scale = Vector2.ZERO
	crosshair_sprite.scale = Vector2.ZERO
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


func _physics_process(delta: float) -> void:
	move_stick = Input.get_vector("left", "right", "up", "down")
	aim_stick = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")

	_dialogue_locked = _dialogue_on_screen()
	var input_move := move_stick if not (_movement_locked or _dialogue_locked) else Vector2.ZERO
	if cutscene_velocity != Vector2.ZERO:
		velocity = cutscene_velocity
		_move_dir = cutscene_velocity.normalized()
		_moving = true
	else:
		velocity = input_move * SPEED
		_moving = input_move.length() > 0.01
		_move_dir = input_move.normalized() if _moving else Vector2.ZERO
	move_and_slide()

	_update_weapon()
	_update_charge(delta)
	_update_animation()
	_update_aim(delta)
	_update_camera(delta)
	_update_pause()
	_update_mobile_controls()


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
			facing_right = _aim_offset.x > 0.0
	elif _moving:
		if abs(_move_dir.x) > 0.1:
			facing_right = _move_dir.x > 0.0

	if sprite.flip_h != facing_right:
		sprite.flip_h = facing_right
	if sprite.animation != anim:
		sprite.play(anim)


func _update_aim(delta: float) -> void:
	if aim_stick.length() > STICK_DEADZONE:
		_aim_scheme = AimScheme.STICK

	_mouse_idle_time += delta

	var target_offset := Vector2.ZERO
	match _aim_scheme:
		AimScheme.STICK:
			if aim_stick.length() > STICK_DEADZONE:
				target_offset = aim_stick * MAX_AIM_DIST
		AimScheme.MOUSE:
			if _mouse_idle_time < MOUSE_RECENTER_DELAY:
				target_offset = (get_global_mouse_position() - global_position).limit_length(MAX_AIM_DIST)

	var smooth := 1.0 - exp(-AIM_SMOOTHING * delta)
	_aim_offset = _aim_offset.lerp(target_offset, smooth)
	_aim_strength = clampf(_aim_offset.length() / MAX_AIM_DIST, 0.0, 1.0)
	_pan_strength = clampf((_aim_strength - PAN_TRIGGER_STRENGTH) / (1.0 - PAN_TRIGGER_STRENGTH), 0.0, 1.0)

	crosshair.position = _aim_offset
	crosshair_sprite.rotation += CROSSHAIR_SPIN_SPEED * delta
	crosshair_sprite.scale = crosshair_sprite.scale.lerp(Vector2.ONE * _pan_strength, 1.0 - exp(-CROSSHAIR_SCALE_SMOOTHING * delta))

	if _aim_offset.length() > 0.01:
		look_dir.rotation = lerp_angle(look_dir.rotation, _aim_offset.angle() + LOOK_ARROW_FORWARD_ANGLE, 1.0 - exp(-ROT_SMOOTHING * delta))

	var arrow_pos := Vector2(0.0, LOOK_ARROW_MAX_POS * _pan_strength)
	var arrow_scale := Vector2.ONE * LOOK_ARROW_MAX_SCALE * _pan_strength
	look_arrow.position = look_arrow.position.lerp(arrow_pos, smooth)
	look_arrow.scale = look_arrow.scale.lerp(arrow_scale, smooth)


func _update_camera(delta: float) -> void:
	var aim_active := _pan_strength > 0.0
	if aim_active and _camera_on_collider:
		camera_2d.reparent(self, true)
		_camera_on_collider = false
	elif not aim_active and not _camera_on_collider:
		camera_2d.reparent(camera_collider, true)
		_camera_on_collider = true

	var target_pos := _aim_offset if aim_active else Vector2.ZERO
	var smooth := 1.0 - exp(-AIM_SMOOTHING * delta)
	camera_2d.position = camera_2d.position.lerp(target_pos, smooth)


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
