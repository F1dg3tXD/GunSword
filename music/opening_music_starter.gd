extends AudioStreamPlayer
## Plays the opening theme once Lit 2D shader precompilation has finished.
## Starting playback during the precompile would desync the music against the
## opening sequence, so this waits for the precompiler's `finished` signal.
## Playback is handed to ProjectMusicController, which reparents the player
## when the opening scene exits so the music keeps running between scenes.

const MainMenuAnimations := preload("res://mainMenu/scenes/menus/main_menu/main_menu_with_animations.gd")

func _ready() -> void:
	_play_music()

func _play_music() -> void:
	if not is_instance_valid(self) or not is_instance_valid(ProjectMusicController):
		return
	MainMenuAnimations.came_from_opening = true
	ProjectMusicController.play_stream_player(self)
