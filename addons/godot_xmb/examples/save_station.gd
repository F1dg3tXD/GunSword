extends Node2D

@onready var interaction_zone: Area2D = $interactionZone

@export var create_menu_scene_path := ""

var _player_in_range: Node = null


func _ready() -> void:
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)


func interact(player: Node) -> void:
	if player == null or player != _player_in_range:
		return

	if not XMBSave.has_saves():
		var scene_path := create_menu_scene_path
		if scene_path == "" and get_tree().current_scene:
			scene_path = get_tree().current_scene.scene_file_path
		XMBSave.open_create_menu(scene_path)
	else:
		XMBSave.open_save_menu()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	_player_in_range = body
	if body.has_method("set_active_station"):
		body.set_active_station(self)


func _on_body_exited(body: Node) -> void:
	if body != _player_in_range:
		return

	if body.has_method("clear_active_station"):
		body.clear_active_station(self)

	_player_in_range = null
