extends CanvasLayer

const GAUGE_MAX := 100.0

#autosave icon
@onready var autosave_icon: Sprite2D = $autosave_icon
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Gauges for the 2 GunSword fire types
@onready var laser_charge_gauge: ProgressBar = $Gauges/HBoxContainer/laserChargeGauge
@onready var blaster_charge_gauge: ProgressBar = $Gauges/HBoxContainer/blasterChargeGauge

#Healthbar
@onready var texture_progress_bar: TextureProgressBar = $HealthBars/VBoxContainer/TextureProgressBar


func _ready() -> void:
	add_to_group("player_ui")


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	texture_progress_bar.max_value = player.max_health
	texture_progress_bar.value = player.health
	blaster_charge_gauge.value = player.blaster_charge * GAUGE_MAX
	laser_charge_gauge.value = player.laser_charge * GAUGE_MAX


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
