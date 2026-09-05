extends Node

var current_map_name := ""


func _ready() -> void:
	Console.pause_enabled = false
	Console.console_opened.connect(on_console_opened)
	Console.console_closed.connect(on_console_closed)
	Console.add_command("debug", on_debug, 1, 1, "debug 0 = off | debug 1 = collision shapes | debug 2 = full debug")
	Console.add_command("fly", on_fly, 0, 0, "fly - toggle fly mode")
	Console.add_command("map", on_map, 1, 1, "map <map_name> - load map from maps/<map_name>.tscn")
	Console.add_command("heal", on_heal, 1, 0, "heal [amount] - heal player to full or by amount")
	Console.add_command("damage", on_damage, 1, 1, "damage <amount> - deal damage to player")
	Console.add_command("speed", on_speed, 1, 1, "speed <value> - set player walk speed")
	Console.add_command("tp", on_teleport, 3, 3, "tp <x> <y> <z> - teleport player to position")
	Console.add_command("kys", on_kys, 0, 0, "kys")
	Console.add_command("tickrate", on_tickrate, 1, 0, "tickrate [value] - get or set the daylight cycle speed multiplier")
	Console.add_command("time", on_time, 2, 0, "time [set <ticks|day|noon|night|midnight> | eclipse [off]] - get or set daylight cycle position (24000 ticks/day)")


func _exit_tree() -> void:
	Console.remove_command("debug")
	Console.remove_command("fly")
	Console.remove_command("map")
	Console.remove_command("heal")
	Console.remove_command("damage")
	Console.remove_command("speed")
	Console.remove_command("tp")
	Console.remove_command("kys")
	Console.remove_command("tickrate")
	Console.remove_command("time")


func on_console_opened() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func on_console_closed() -> void:
	if PlayerTopDown.HIDE_OS_CURSOR:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ── debug ────────────────────────────────────────────────────────────────────

func on_debug(param: String) -> void:
	var level := param.to_int()
	if level <= 0:
		_set_debug_collision(false)
		Console.print_line("Debug: off")
	elif level == 1:
		_set_debug_collision(true)
		Console.print_line("Debug: collision shapes on")
	else:
		_set_debug_collision(true)
		Console.print_line("Debug: full (collision shapes on)")


func _set_debug_collision(enabled: bool) -> void:
	for node in get_tree().get_nodes_in_group("debug"):
		if node is Node3D:
			for cs in node.find_children("*", "CollisionShape3D", true, false):
				cs.visible = enabled
			node.visible = enabled


# ── fly ──────────────────────────────────────────────────────────────────────

func on_fly() -> void:
	var player := PlayerTopDown
	player._fly_mode = not player._fly_mode
	if player._fly_mode:
		player.velocity = Vector3.ZERO
		Console.print_line("Fly: ON")
	else:
		Console.print_line("Fly: OFF")


# ── map ──────────────────────────────────────────────────────────────────────

func on_map(map_name: String) -> void:
	if map_name.is_empty():
		Console.print_line("Usage: map <map_name>")
		Console.print_line("Available maps:")
		for m in _get_available_maps():
			Console.print_line("  - " + m)
		return

	var map_path := "res://maps/%s.tscn" % map_name
	if not ResourceLoader.exists(map_path):
		Console.print_line("Error: Map not found: " + map_path)
		return

	current_map_name = map_name
	get_tree().change_scene_to_file(map_path)
	Console.print_line("Loading map: " + map_name)


func _get_available_maps() -> PackedStringArray:
	var files: PackedStringArray = []
	var dir := DirAccess.open("res://maps/")
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn"):
				files.append(file_name.get_file().get_basename())
			file_name = dir.get_next()
		dir.list_dir_end()
	return files


# ── heal ─────────────────────────────────────────────────────────────────────

func on_heal(param: String) -> void:
	var player := PlayerTopDown
	if param.is_empty():
		player.heal(player.max_health)
	else:
		player.heal(param.to_int())
	Console.print_line("Health: %d / %d" % [player.health, player.max_health])


# ── damage ───────────────────────────────────────────────────────────────────

func on_damage(param: String) -> void:
	PlayerTopDown.take_damage(param.to_int())
	Console.print_line("Health: %d / %d" % [PlayerTopDown.health, PlayerTopDown.max_health])


# ── speed ────────────────────────────────────────────────────────────────────

func on_speed(param: String) -> void:
	var val := param.to_float()
	if val <= 0.0:
		Console.print_line("Speed must be > 0")
		return
	PlayerTopDown.walk_speed = val
	Console.print_line("Walk speed set to: " + str(val))


# ── tp ───────────────────────────────────────────────────────────────────────

func on_teleport(x: String, y: String, z: String) -> void:
	var pos := Vector3(x.to_float(), y.to_float(), z.to_float())
	PlayerTopDown.global_position = pos
	Console.print_line("Teleported to: " + str(pos))
	
# ── kys ──────────────────────────────────────────────────────────────────────

func on_kys() -> void:
	PlayerTopDown.take_damage(100)
	Console.print_line("L+ratio")


# ── tickrate ────────────────────────────────────────────────────────────────

func on_tickrate(value: String) -> void:
	var sky = EntSky
	if sky == null or not is_instance_valid(sky):
		Console.print_line("Error: No sky found in current map")
		return
	if value.is_empty():
		Console.print_line("Tickrate: %s" % str(sky.tickrate))
		return
	var val := value.to_float()
	if val <= 0.0:
		Console.print_line("Tickrate must be > 0")
		return
	sky.set_tickrate(val)
	Console.print_line("Tickrate set to: " + str(val))


# ── time ────────────────────────────────────────────────────────────────────

const TIME_PRESETS := {
	"day": 1000,
	"noon": 6000,
	"night": 13000,
	"midnight": 18000,
}


func on_time(action: String, value: String) -> void:
	var sky = EntSky
	if sky == null or not is_instance_valid(sky):
		Console.print_line("Error: No sky found in current map")
		return
	if action == "eclipse":
		if value.to_lower() == "off":
			sky.set_eclipse(false)
			Console.print_line("Eclipse cleared. The moon resumes its orbit.")
			return
		if not value.is_empty():
			Console.print_line("Usage: time eclipse [off]")
			return
		sky.set_eclipse(true)
		Console.print_line("Eclipse activated. Sun and moon aligned.")
		Console.print_line("It holds briefly, then fades as the moon returns to its orbit.")
		Console.print_line("It fades faster at higher tickrate. Force-clear now with: time eclipse off")
		return
	if action == "set" and value.to_lower() == "eclipse":
		sky.set_eclipse(true)
		Console.print_line("Eclipse activated. Sun and moon aligned.")
		Console.print_line("It holds briefly, then fades as the moon returns to its orbit.")
		Console.print_line("It fades faster at higher tickrate. Force-clear now with: time eclipse off")
		return
	if action.is_empty() or action == "set":
		if action == "set" and value.is_empty():
			Console.print_line("Usage: time set <ticks|day|noon|night|midnight>")
			return
		if action.is_empty():
			var tick: float = sky.get_time()
			var hours := int(tick / 1000.0)
			var tick_in_hour := int(tick) % 1000
			Console.print_line("Time: %d ticks (%02d:%02d)" % [int(tick), hours, tick_in_hour * 60 / 1000])
			return
		var tick_val: float
		if TIME_PRESETS.has(value.to_lower()):
			tick_val = float(TIME_PRESETS[value.to_lower()])
		elif value.is_valid_float() or value.is_valid_int():
			tick_val = value.to_float()
		else:
			Console.print_line("Invalid time value: " + value)
			Console.print_line("Use a number (0-24000) or a preset (day, noon, night, midnight); eclipse is toggled with: time eclipse [off]")
			return
		sky.set_time(tick_val)
		Console.print_line("Time travelling to: %d ticks" % int(tick_val))
	else:
		Console.print_line("Usage: time [set <ticks|day|noon|night|midnight> | eclipse [off]]")
