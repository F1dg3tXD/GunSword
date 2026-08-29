extends Node

var _scatter_max: int = 1800
var _scatter_originals: Dictionary = {}


func _ready() -> void:
	_configure_lights(get_tree().root)
	_configure_sprites(get_tree().root)
	get_tree().scene_changed.connect(_on_scene_changed)
	_apply_scatter_from_config.call_deferred()


func _on_scene_changed() -> void:
	_apply_scatter_from_config.call_deferred()


func _apply_scatter_from_config() -> void:
	configure_scatter(int(AppSettings.get_foiliage_density()))


func _configure_lights(node: Node) -> void:
	for child in node.get_children():
		if child is Light3D:
			child.shadow_bias = 0.01
			child.shadow_blur = 0.0
		_configure_lights(child)


func _configure_sprites(node: Node) -> void:
	for child in node.get_children():
		if child is SpriteBase3D:
			child.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			child.texture_filter = 0
		_configure_sprites(child)


func configure_scatter(max_amount: int) -> void:
	_scatter_max = max_amount
	_apply_scatter(get_tree().root)


func _apply_scatter(node: Node) -> void:
	for child in node.get_children():
		if child is Scatter:
			var id := child.get_instance_id()
			if not _scatter_originals.has(id):
				_scatter_originals[id] = child.amount
			var original: int = _scatter_originals[id]
			child.amount = mini(original, _scatter_max)
		_apply_scatter(child)
