extends Node


func _ready() -> void:
	_configure_lights(get_tree().root)
	_configure_sprites(get_tree().root)


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
