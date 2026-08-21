extends Node3D
@onready var multi_view_animated_sprite_3d: MultiViewAnimatedSprite3D = $multiViewAnimatedSprite3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	multi_view_animated_sprite_3d.play3d("idle_spin")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
