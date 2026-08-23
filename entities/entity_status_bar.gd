extends Node3D

@onready var status: Control = $SubViewport/Status
@onready var status_icon: TextureRect = $SubViewport/Status/VBoxContainer/statusIcon
@onready var health_bar: ProgressBar = $SubViewport/Status/VBoxContainer/HealthBar

@export var status_icon_stun: Texture2D = null
@export var status_icon_burn: Texture2D = null

## Maps status effect name -> texture. Populated from exports on _ready.
var _effect_textures: Dictionary = {}

var _current_health: float = 100.0
var _max_health: float = 100.0
var _active_status: String = ""


func _ready() -> void:
	_effect_textures["stun"] = status_icon_stun
	_effect_textures["burn"] = status_icon_burn

	status.hide()
	health_bar.value = 100.0
	status_icon.texture = null


# --- Public API ----------------------------------------------------------
# Entities call these methods to push updates.  No coupling needed —
# the status bar never reaches back into the entity.

## Set the entity's health.  The bar is visible when health < max
## OR when a status effect is active.
func set_health(current: float, max_val: float) -> void:
	_max_health = max_val
	_current_health = current
	health_bar.max_value = max_val
	health_bar.value = current
	_refresh_visibility()


## Show a status-icon for the given effect name (e.g. "stun", "burn").
## Pass an empty string to clear.
func apply_status(effect_name: String) -> void:
	_active_status = effect_name
	_refresh_icon()
	_refresh_visibility()


## Clear the current status effect.
func clear_status() -> void:
	_active_status = ""
	_refresh_icon()
	_refresh_visibility()


## Register a custom effect name with an icon texture at runtime.
func register_status_icon(effect_name: String, icon: Texture2D) -> void:
	_effect_textures[effect_name] = icon


func get_health_percentage() -> float:
	if _max_health <= 0.0:
		return 0.0
	return _current_health / _max_health


# --- Internal ------------------------------------------------------------

func _refresh_visibility() -> void:
	var health_damaged := _current_health < _max_health
	var has_status := not _active_status.is_empty()
	status.visible = health_damaged or has_status


func _refresh_icon() -> void:
	if _active_status.is_empty():
		status_icon.texture = null
		return

	if _effect_textures.has(_active_status):
		status_icon.texture = _effect_textures[_active_status]
	else:
		status_icon.texture = null
