extends MainMenu
## Main menu extension that animates the title and menu fading in.
## The animation can be skipped by the player with any input.
@onready var background_music_player: AudioStreamPlayer = $BackgroundMusicPlayer

## Index of the "Loop 2" clip in the opening theme's interactive stream.
const LOOP_2_CLIP_INDEX : int = 1

## Set by the opening scene when it hands its music over to the controller.
## While true, the opening's music is still playing (reparented to the music
## controller), so this menu must not start its own background music.
static var came_from_opening : bool = false

var animation_state_machine : AnimationNodeStateMachinePlayback

func intro_done() -> void:
	animation_state_machine.travel("OpenMainMenu")

func _is_in_intro() -> bool:
	return animation_state_machine.get_current_node() == "Intro"

func _event_skips_intro(event : InputEvent) -> bool:
	return event.is_action_pressed("ui_accept") or \
		event.is_action_pressed("ui_select") or \
		event.is_action_pressed("ui_cancel") or \
		_event_is_mouse_button_released(event)

func _open_sub_menu(menu : PackedScene) -> Node:
	animation_state_machine.travel("OpenSubMenu")
	return super._open_sub_menu(menu)

func _close_sub_menu() -> void:
	super._close_sub_menu()
	animation_state_machine.travel("OpenMainMenu")

func _input(event : InputEvent) -> void:
	if _is_in_intro() and _event_skips_intro(event):
		intro_done()
		return
	super._input(event)

func _ready() -> void:
	super._ready()
	animation_state_machine = $MenuAnimationTree.get("parameters/playback")
	%ContinueGameButton.visible = XMBSave.has_saves()
	if came_from_opening:
		came_from_opening = false
		return
	else:
		_play_background_music()

func _play_background_music() -> void:
	var stream := background_music_player.stream.duplicate() as AudioStreamInteractive
	if stream == null:
		return
	stream.initial_clip = LOOP_2_CLIP_INDEX
	background_music_player.stream = stream
	ProjectMusicController.play_stream_player(background_music_player)

func new_game() -> void:
	XMBSave.open_create_menu(get_game_scene_path())


func _on_continue_button_pressed() -> void:
	if not XMBSave.load_latest_save():
		new_game()


func _on_load_button_pressed() -> void:
	XMBSave.open_load_menu()
