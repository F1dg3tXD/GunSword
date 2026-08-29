extends Node3D
class_name InfoPlayerStart
## Defines a point where the player should spawn when a map is loaded directly
## (e.g. via the "map" command or a direct scene load) rather than arriving
## through a level transition. Works like Quake / Half-Life info_player_start.
##
## Place at least one of these in a map to control the default spawn location.
## If none exist, the player falls back to scene origin (0, 0, 0).


## Finds the active player spawn point in the current scene, or null if none.
static func find_in_scene() -> InfoPlayerStart:
	var scene := Engine.get_main_loop().current_scene as Node
	if scene == null:
		return null
	for child in scene.find_children("*", "InfoPlayerStart", true, false):
		var start := child as InfoPlayerStart
		if start != null:
			return start
	return null
