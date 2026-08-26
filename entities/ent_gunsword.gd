extends Node3D

const LASER_DRAW_SPEED := 40.0
const LASER_RADIUS := 0.6

@export var blaster_bolt: PackedScene

@onready var projectile_dir: RayCast3D = $projectileDir
@onready var laser_light: AreaLight3D = $ent_laser_light

var _laser_beam: MeshInstance3D = null
var _laser_current_length := 0.0
var _laser_target_length := 0.0


func _ready() -> void:
	_init_laser_beam()


func _init_laser_beam() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(LASER_RADIUS, LASER_RADIUS, 1.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.15, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.15)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat

	_laser_beam = MeshInstance3D.new()
	_laser_beam.mesh = mesh
	_laser_beam.visible = false
	add_child(_laser_beam)


func fire_blaster(start: Vector3, aim_point: Vector3) -> void:
	if blaster_bolt == null:
		return

	var direction := (aim_point - start).normalized()
	if direction.length_squared() < 0.001:
		return

	var bolt := blaster_bolt.instantiate()
	bolt._direction = direction
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = start

	var look_target := start + direction
	if look_target.distance_to(start) > 0.001:
		bolt.look_at(look_target, Vector3.UP)


func update_laser(active: bool, delta: float, start: Vector3, aim_point: Vector3) -> void:
	if not active:
		_laser_beam.visible = false
		laser_light.visible = false
		_laser_current_length = 0.0
		return

	_laser_target_length = start.distance_to(aim_point)

	_laser_current_length = move_toward(_laser_current_length, _laser_target_length, LASER_DRAW_SPEED * delta)
	if _laser_current_length < 0.01:
		_laser_beam.visible = false
		laser_light.visible = false
		return

	var dir := (aim_point - start).normalized()
	if dir.length_squared() < 0.001:
		_laser_beam.visible = false
		laser_light.visible = false
		return

	_laser_beam.visible = true
	var mid := start + dir * _laser_current_length * 0.5
	_laser_beam.global_position = mid
	_laser_beam.scale = Vector3(LASER_RADIUS, LASER_RADIUS, _laser_current_length)
	var look_target := mid + dir
	if look_target.distance_to(mid) > 0.001:
		_laser_beam.look_at(look_target, Vector3.UP)

	laser_light.update_light(_laser_current_length, start, dir)
