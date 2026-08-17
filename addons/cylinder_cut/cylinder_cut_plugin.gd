@tool
extends EditorPlugin

## Registers CylinderCutNode as a first-class node type so it shows up in the
## "Create Node" dialog under Node3D.


func _enter_tree() -> void:
	add_custom_type("CylinderCutNode", "Node3D",
			load("res://addons/cylinder_cut/cylinder_cut_node.gd"),
			load("res://addons/cylinder_cut/icon.svg"))


func _exit_tree() -> void:
	remove_custom_type("CylinderCutNode")
