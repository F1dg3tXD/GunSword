extends Node2D

@onready var music: AudioStreamPlayer = $music

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ProjectMusicController.play_stream_player(music)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
