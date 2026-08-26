@tool
extends InputIconMapper
## Shared InputIconMapper singleton (autoload "InputIcons") used across the game
## to look up device specific icons.

const ICON_PACK_PATH := "res://addons/kenney_input-prompts_1.5"

var _colored_prompts := false

func _ready() -> void:
	recursive = false
	filter = "color"
	filtered_strings = ["keyboard", "color", "button", "arrow"]
	replace_strings = {
		"Capslock": "Caps Lock",
		"Generic Stick": "Generic Left Stick",
		"Guide": "Home",
		"Slash Back": "Back Slash",
		"Slash Forward": "Slash",
		"Stick L": "Left Stick",
		"Stick R": "Right Stick",
		"Trigger L 1": "Left Shoulder",
		"Trigger L 2": "Left Trigger",
		"Trigger R 1": "Right Shoulder",
		"Trigger R 2": "Right Trigger",
	}
	add_stick_directions = true
	ends_with = ".png"
	not_ends_with = "outline.png"
	directories = [
		"%s/Keyboard & Mouse/Default" % ICON_PACK_PATH,
		"%s/Generic/Default" % ICON_PACK_PATH,
		"%s/Xbox Series/Default" % ICON_PACK_PATH,
		"%s/PlayStation Series/Default" % ICON_PACK_PATH,
		"%s/Nintendo Switch/Default" % ICON_PACK_PATH,
		"%s/Steam Deck/Default" % ICON_PACK_PATH,
	]
	super._ready()


func set_colored_prompts(enabled: bool) -> void:
	if _colored_prompts == enabled:
		return
	_colored_prompts = enabled
	if enabled:
		filter = ""
		prioritized_strings = ["color"]
	else:
		filter = "color"
		prioritized_strings = []
	_refresh_files()
	_match_icons_to_inputs()
