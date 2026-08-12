extends Area2D

signal autosave_completed

@export var save_slot_id := "autosave"
@export var trigger_once := false

var _saving := false
var _has_triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _saving or not body.is_in_group("player"):
		return
	if trigger_once and _has_triggered:
		return
	_has_triggered = true
	_saving = true

	if not XMBSave.has_autosaves():
		var prompt := preload("res://UI/autosave_prompt.tscn").instantiate()
		get_tree().root.add_child(prompt)
		XMBSave.set_autosave_mode(await prompt.prompt())

	var player_ui := get_tree().get_first_node_in_group("player_ui")
	if player_ui != null and player_ui.has_method("play_autosave"):
		await player_ui.play_autosave(XMBSave.autosave)
	else:
		XMBSave.autosave()

	_saving = false
	autosave_completed.emit()
