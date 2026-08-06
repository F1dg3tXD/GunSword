extends CharacterBody2D

const SPEED := 300.0

#@onready var animation_tree: AnimationTree = $AnimationTree
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var move_stick := Vector2.ZERO
var aim_stick := Vector2.ZERO

func _ready() -> void:
	#animation_tree.active = true
	#sprite.animation = "idle"
	pass

func _physics_process(_delta: float) -> void:
	move_stick = Input.get_vector("left", "right", "up", "down")
	aim_stick = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")

	velocity = move_stick * SPEED
	move_and_slide()

	#_update_animation_tree()

#func _update_animation_tree() -> void:
	#var blend_tree := animation_tree.tree_root as AnimationNodeBlendTree
	#if blend_tree == null:
		#return
	#if blend_tree.has_node("move_blend"):
		#animation_tree.set("parameters/move_blend/blend_position", move_stick)
	#if blend_tree.has_node("aim_blend"):
		#animation_tree.set("parameters/aim_blend/blend_position", aim_stick)
