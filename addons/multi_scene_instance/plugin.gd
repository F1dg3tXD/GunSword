@tool
extends EditorPlugin

const ICON := "res://addons/multi_scene_instance/icons/MultiSceneInstance3D.svg"


func _enter_tree() -> void:
	add_custom_type(
		"MultiSceneInstance3D",
		"MultiMeshInstance3D",
		preload("multi_scene_instance_3d.gd"),
		load(ICON))


func _exit_tree() -> void:
	remove_custom_type("MultiSceneInstance3D")
