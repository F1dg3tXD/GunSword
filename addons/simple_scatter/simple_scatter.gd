@tool
extends EditorPlugin

func _enter_tree():
	add_custom_type(
		"Scatter",
		"Node3D",
		preload("res://addons/simple_scatter/scatter.gd"),
		preload("res://addons/simple_scatter/icons/Scatter3D.PNG"))
	
	add_custom_type(
		"ScatterShape",
		"CollisionShape3D",
		preload("res://addons/simple_scatter/scatter_shape.gd"),
		preload("res://addons/simple_scatter/icons/ScatterCollider3D.PNG"))

func _exit_tree():
	remove_custom_type("Scatter")
	remove_custom_type("ScatterShape")
