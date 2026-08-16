extends Area2D

@export var dialogue: DialogueResource
@export var interact_required := false
@export var can_interrupt := false

var _player_in_range := false
var _auto_started := false
var _balloon: Node = null
var _player: Node = null


func _ready() -> void:
	body_entered.connect(_on_trigger_body_entered)
	body_exited.connect(_on_trigger_body_exited)


func _physics_process(_delta: float) -> void:
	if _balloon != null or not _player_in_range:
		return
	if interact_required:
		if Input.is_action_just_pressed("interact"):
			_start_dialogue()
	elif not _auto_started:
		_auto_started = true
		_start_dialogue()


func _start_dialogue() -> void:
	if dialogue == null:
		push_error("DialogueTrigger: no dialogue resource set on %s" % get_path())
		return
	_balloon = DialogueManager.show_dialogue_balloon(dialogue)
	if not is_instance_valid(_balloon):
		return
	_balloon.add_to_group("dialogue_balloon")
	_balloon.tree_exited.connect(_on_balloon_closed)
	if can_interrupt:
		_player = get_tree().get_first_node_in_group("player")
		if _player != null and _player.has_signal("damaged"):
			_player.damaged.connect(_on_player_damaged)


func _on_player_damaged() -> void:
	if can_interrupt and is_instance_valid(_balloon):
		_balloon.queue_free()


func _on_balloon_closed() -> void:
	if _player != null and _player.has_signal("damaged") and _player.damaged.is_connected(_on_player_damaged):
		_player.damaged.disconnect(_on_player_damaged)
	_player = null
	_balloon = null


func _on_trigger_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_range = true


func _on_trigger_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_range = false
		_auto_started = false
