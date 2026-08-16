extends SceneTree

var _fail := false

func _check(label: String, ok: bool, detail: String = "") -> void:
	print((("PASS" if ok else "FAIL") + " | " + label) + ((" | " + detail) if detail != "" else ""))
	if not ok:
		_fail = true

func _initialize() -> void:
	var original: MeshLibrary = load("res://addons/kenney_building-kit/building-kit.meshlib")
	_check("meshlib loads", original != null)
	var orig_item57_mat: Material = original.get_item_mesh(57).surface_get_material(0)
	_check("item57 is StandardMaterial3D", orig_item57_mat is StandardMaterial3D)

	var rt := root as Window
	if rt == null:
		quit(1)
		return

	var grid := GridMap.new()
	grid.mesh_library = original
	grid.set_cell_item(Vector3i(0, 0, 0), 57, 0)
	grid.set_cell_item(Vector3i(1, 0, 0), 28, 0)
	rt.add_child(grid)
	var used_before: int = grid.get_used_cells().size()
	_check("cells placed", used_before == 2)

	var player := Node3D.new()
	player.name = "ProbePlayer"
	rt.add_child(player)

	var window := OcclusionWindow3D.new()
	window.name = "ProbeWindow"
	window.auto_window_geometry = true
	window.target = player
	rt.add_child(window)

	window._auto_scan()

	_check("gridmap library swapped", grid.mesh_library != original)
	var converted: MeshLibrary = grid.mesh_library
	_check("cells preserved after swap", grid.get_used_cells().size() == used_before)

	var m57 := converted.get_item_mesh(57)
	var m57mat := m57.surface_get_material(0)
	_check("item57 converted to ShaderMaterial", m57mat is ShaderMaterial)
	if m57mat is ShaderMaterial:
		var sm := m57mat as ShaderMaterial
		_check("item57 occlude on", sm.get_shader_parameter("occlusion_window_occlude") == true)
		_check("item57 vertical_only true", sm.get_shader_parameter("occlusion_window_vertical_only") == true)
		_check("item57 albedo copied", sm.get_shader_parameter("albedo_texture") != null)
		_check("item57 shader is receiver", sm.shader == window._receiver_shader())

	var m28 := converted.get_item_mesh(28)
	_check("item28 converted too", m28.surface_get_material(0) is ShaderMaterial)
	_check("item28 same material as 57 (shared cache)",
		m28.surface_get_material(0) == m57mat)

	_check("ORIGINAL library untouched", original.get_item_mesh(57).surface_get_material(0) == orig_item57_mat)
	_check("original item57 still Standard", original.get_item_mesh(57).surface_get_material(0) is StandardMaterial3D)

	var swapped: MeshLibrary = grid.mesh_library
	window._auto_scan()
	_check("rescan idempotent (no re-swap)", grid.mesh_library == swapped)
	_check("rescan still converted", grid.mesh_library.get_item_mesh(57).surface_get_material(0) is ShaderMaterial)

	var grid2 := GridMap.new()
	grid2.mesh_library = original
	grid2.set_cell_item(Vector3i(5, 0, 0), 58, 0)
	rt.add_child(grid2)
	window._auto_scan()
	_check("shared source library cached", grid2.mesh_library == grid.mesh_library)

	var window2 := OcclusionWindow3D.new()
	window2.auto_window_geometry = true
	window2.gridmap_vertical_only = false
	window2.target = player
	rt.add_child(window2)
	var grid3 := GridMap.new()
	grid3.mesh_library = original
	grid3.set_cell_item(Vector3i(9, 0, 0), 57, 0)
	rt.add_child(grid3)
	window2._auto_scan()
	var m57b := grid3.mesh_library.get_item_mesh(57).surface_get_material(0) as ShaderMaterial
	_check("vertical_only=false material created", m57b.get_shader_parameter("occlusion_window_vertical_only") == false)
	_check("distinct material for false", m57b != m57mat)
	_check("original still untouched after 2nd window", original.get_item_mesh(57).surface_get_material(0) == orig_item57_mat)

	print("RESULT: " + ("FAIL" if _fail else "PASS"))
	quit(1 if _fail else 0)
