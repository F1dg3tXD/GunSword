extends Node

@onready var music_player : AudioStreamPlayer = $MusicPlayer

func get_playback_time() -> float:
	if music_player == null or not music_player.playing:
		return 0.0
	return music_player.get_playback_position() + AudioServer.get_time_since_last_mix()
