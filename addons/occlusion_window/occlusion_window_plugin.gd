@tool
extends EditorPlugin

## Registers the OcclusionWindow component as a first-class node type so it shows up in
## the "Create Node" dialog under Node2D, ready to drop on any occluder sprite.

const OcclusionWindowScript := preload("res://addons/occlusion_window/occlusion_window.gd")
const OCICON := preload("res://addons/occlusion_window/icon.svg")


func _enter_tree() -> void:
	add_custom_type("OcclusionWindow", "Node2D", OcclusionWindowScript, OCICON)


func _exit_tree() -> void:
	remove_custom_type("OcclusionWindow")
