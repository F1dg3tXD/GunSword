extends Node3D

@onready var area_3d: Area3D = $Area3D
@onready var animated_sprite_3d: AnimatedSprite3D = $AnimatedSprite3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animated_sprite_3d.play("wave_idle")
	animated_sprite_3d.frame = randi_range(
	0,
	animated_sprite_3d.sprite_frames.get_frame_count("wave_idle") - 1
)


func _on_area_3d_body_entered(body: Node3D) -> void:
	if not (
		body.is_in_group("player")
		or body.is_in_group("friend")
		or body.is_in_group("enemy")
	):
		return
	animated_sprite_3d.play("squish")
	await animated_sprite_3d.animation_finished
	animated_sprite_3d.frame = animated_sprite_3d.sprite_frames.get_frame_count("squish") - 1
	animated_sprite_3d.pause()


func _on_area_3d_body_exited(body: Node3D) -> void:
	if not (
		body.is_in_group("player")
		or body.is_in_group("friend")
		or body.is_in_group("enemy")
	):
		return
	animated_sprite_3d.play("spring")
	await animated_sprite_3d.animation_finished
	animated_sprite_3d.play("wave_idle")
