extends Node3D
#@onready var animation_tree: AnimationTree = $AnimationTree
#@onready var animation_player: AnimationPlayer = $AnimationPlayer

var day = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	#animation_tree.active = true
	#animation_tree.set("parameters/dayNight/blend_position", 0)

#func set_time() -> void:
	#if day == true:
		##animation_tree.set("parameters/dayNight/blend_position", lerp(0, 1, 1.0))
		#day = false
	#elif day == false:
		##animation_tree.set("parameters/dayNight/blend_position", lerp(1, 0, 1.0))
		#day = true

#
#func _on_point_trigger_3d_body_entered(body: Node3D) -> void:
	##set_time()
