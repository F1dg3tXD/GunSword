@tool
extends EditorPlugin

## Registers the OcclusionWindow 2D/3D components as first-class node types so they show
## up in the "Create Node" dialog under Node2D and Node3D.
##
## - OcclusionWindow2D (Node2D): screen-space window for 2D cameras/characters.
## - OcclusionWindow3D (Node3D): camera-relative window for 3D cameras/characters.

const OcclusionWindow2DScript := preload("res://addons/occlusion_window/occlusion_window_2D.gd")
const OcclusionWindow3DScript := preload("res://addons/occlusion_window/occlusion_window_3D.gd")
const OCICON := preload("res://addons/occlusion_window/icon.svg")


func _enter_tree() -> void:
	add_custom_type("OcclusionWindow2D", "Node2D", OcclusionWindow2DScript, OCICON)
	add_custom_type("OcclusionWindow3D", "Node3D", OcclusionWindow3DScript, OCICON)


func _exit_tree() -> void:
	remove_custom_type("OcclusionWindow2D")
	remove_custom_type("OcclusionWindow3D")
