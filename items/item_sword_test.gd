extends Node3D

@onready var animated_sprite_3d: AnimatedSprite3D = $AnimatedSprite2D

func _ready() -> void:
	animated_sprite_3d.play("idle")

func _physics_process(_delta: float) -> void:
	pass
