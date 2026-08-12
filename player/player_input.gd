extends "res://addons/netfox.extras/base-net-input.gd"
## Only these three values cross the network. The server owns resulting physics.

var cursor_offset := Vector2.ZERO
var burst := false
var reverse := false

func _gather() -> void:
	var body := get_parent() as Node3D
	var main := get_tree().current_scene
	if body == null or main == null:
		cursor_offset = Vector2.ZERO
		burst = false
		reverse = false
		return
	if main.has_method("scripted_input_for") and main.is_scripted_client():
		var scripted: Dictionary = main.scripted_input_for(body)
		cursor_offset = scripted.get("cursor_offset", Vector2.ZERO)
		burst = bool(scripted.get("burst", false))
		reverse = bool(scripted.get("reverse", false))
		return
	if main.has_method("cursor_offset_for"):
		cursor_offset = main.cursor_offset_for(body)
	else:
		cursor_offset = Vector2.ZERO
	burst = Input.is_action_pressed("burst")
	reverse = Input.is_action_pressed("reverse")
