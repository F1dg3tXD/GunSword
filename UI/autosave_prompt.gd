extends CanvasLayer

signal mode_selected(mode: String)

var _result := ""


func _ready() -> void:
	%OverwriteButton.grab_focus()


func _on_overwrite_button_pressed() -> void:
	_result = "overwrite"
	mode_selected.emit(_result)


func _on_separate_button_pressed() -> void:
	_result = "separate"
	mode_selected.emit(_result)


func prompt() -> String:
	await mode_selected
	queue_free()
	return _result
