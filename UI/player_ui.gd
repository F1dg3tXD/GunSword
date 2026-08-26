extends CanvasLayer

const GAUGE_MAX := 100.0
const GAUGE_SIZE_NORMAL := Vector2(20, 430)
const GAUGE_SIZE_ACTIVE := Vector2(40, 450)
const GAUGE_MAX_NORMAL := Vector2(30, 450)
const GAUGE_MAX_ACTIVE := Vector2(40, 450)
const GAUGE_LERP_SPEED := 10.0

#autosave icon
@onready var autosave_icon: Sprite2D = $autosave_icon
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Gauges for the 2 GunSword fire types
@onready var laser_charge_gauge: ProgressBar = $Gauges/HBoxContainer/laserChargeGauge
@onready var blaster_charge_gauge: ProgressBar = $Gauges/HBoxContainer/blasterChargeGauge

#Healthbar
@onready var texture_progress_bar: TextureProgressBar = $HealthBars/VBoxContainer/TextureProgressBar

var _blaster_min_size := GAUGE_SIZE_NORMAL
var _blaster_max_size := GAUGE_MAX_NORMAL
var _laser_min_size := GAUGE_SIZE_NORMAL
var _laser_max_size := GAUGE_MAX_NORMAL


func _ready() -> void:
	add_to_group("player_ui")


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	texture_progress_bar.max_value = player.max_health
	texture_progress_bar.value = player.health

	var is_blaster: bool = player.fire_mode == player.FireMode.BLASTER
	var t := 1.0 - exp(-GAUGE_LERP_SPEED * delta)

	_blaster_min_size = _blaster_min_size.lerp(GAUGE_SIZE_ACTIVE if is_blaster else GAUGE_SIZE_NORMAL, t)
	_blaster_max_size = _blaster_max_size.lerp(GAUGE_MAX_ACTIVE if is_blaster else GAUGE_MAX_NORMAL, t)
	_laser_min_size = _laser_min_size.lerp(GAUGE_SIZE_NORMAL if is_blaster else GAUGE_SIZE_ACTIVE, t)
	_laser_max_size = _laser_max_size.lerp(GAUGE_MAX_NORMAL if is_blaster else GAUGE_MAX_ACTIVE, t)

	blaster_charge_gauge.custom_minimum_size = _blaster_min_size
	blaster_charge_gauge.custom_maximum_size = _blaster_max_size
	laser_charge_gauge.custom_minimum_size = _laser_min_size
	laser_charge_gauge.custom_maximum_size = _laser_max_size

	blaster_charge_gauge.value = player.blaster_charge * GAUGE_MAX
	laser_charge_gauge.value = player.laser_charge * GAUGE_MAX

	blaster_charge_gauge.indeterminate = player.blaster_charge <= 0.0
	laser_charge_gauge.indeterminate = player.laser_charge <= 0.0


## Plays the save icon animation while [param work] runs.
## Sequence: saveIn -> saveLoop (running while work runs) -> saveIn reversed.
func play_autosave(work: Callable) -> void:
	autosave_icon.show()
	animation_player.play("saveIn")
	await animation_player.animation_finished

	animation_player.play("saveLoop")
	await work.call()
	# Finish the current loop iteration so we end on a clean boundary.
	var remaining := animation_player.current_animation_length - animation_player.current_animation_position
	if remaining > 0.0:
		await get_tree().create_timer(remaining).timeout

	animation_player.play_backwards("saveIn")
	await animation_player.animation_finished
	autosave_icon.hide()
