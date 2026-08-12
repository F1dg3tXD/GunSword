class_name DialogueIconLabel extends DialogueLabel
## A DialogueLabel that replaces [input_<action>] tokens in dialogue lines with
## the icon for the player's current input device.


func _update_text() -> void:
	if Engine.is_editor_hint():
		super._update_text()
		return
	if is_instance_valid(dialogue_line):
		text = InputIconText.process(dialogue_line.text)
	else:
		text = ""
