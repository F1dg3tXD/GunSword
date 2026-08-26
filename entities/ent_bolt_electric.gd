extends Node3D

const MAX_RANGE := 90.0
@onready var multi_view_animated_sprite_3d: MultiViewAnimatedSprite3D = $MultiViewAnimatedSprite3D

@export var speed := 10.0

var _spawn_position := Vector3.ZERO
var _direction := Vector3.FORWARD
var _alive := true

@onready var damager: Area3D = $damager
@onready var sprite: AnimatedSprite3D = $MultiViewAnimatedSprite3D


func _ready() -> void:
	multi_view_animated_sprite_3d.play3d("idle")
	_spawn_position = global_position
	damager.set_deferred("monitoring", false)
	sprite.play("idle_top")
	damager.body_entered.connect(_on_body_entered)
	damager.area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if not _alive:
		return

	global_position += _direction * speed * delta

	if global_position.distance_to(_spawn_position) >= MAX_RANGE:
		queue_free()
		return

	if not damager.monitoring and global_position.distance_to(_spawn_position) > 2.0:
		damager.monitoring = true


func _on_body_entered(body: Node3D) -> void:
	if not _alive:
		return
	if _is_player_part(body):
		return
	if body.is_in_group("enemy"):
		_alive = false
		damager.monitoring = false
		visible = false
		await get_tree().create_timer(0.1).timeout
		queue_free()


func _on_area_entered(area: Area3D) -> void:
	if not _alive:
		return
	if _is_player_part(area):
		return
	if area.is_in_group("enemy"):
		_alive = false
		damager.monitoring = false
		visible = false
		await get_tree().create_timer(0.1).timeout
		queue_free()


func _is_player_part(node: Node) -> bool:
	while node != null:
		if node.is_in_group("player"):
			return true
		node = node.get_parent()
	return false
