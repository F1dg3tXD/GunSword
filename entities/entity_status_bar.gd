extends Node3D

@onready var status: Control = $SubViewport/Status
@onready var status_icon: TextureRect = $SubViewport/Status/VBoxContainer/statusIcon
@onready var health_bar: ProgressBar = $SubViewport/Status/VBoxContainer/HealthBar

@export var status_icon_stun: Texture2D = null
@export var status_icon_burn: Texture2D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
