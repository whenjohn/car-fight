extends "res://addons/netfox.extras/base-net-input.gd"
## Player intent crosses the network. The server owns resulting physics and combat.

var cursor_offset := Vector2.ZERO
var burst := false
var reverse := false
var cloak_held := false
# Safe spawn default: authority cannot fire before the owning client's first
# gathered input declares that it has entered drive mode.
var editing := true

func _gather() -> void:
	var body := get_parent() as Node3D
	var main := get_tree().current_scene
	if body == null or main == null:
		cursor_offset = Vector2.ZERO
		burst = false
		reverse = false
		cloak_held = false
		editing = true
		return
	if main.has_method("scripted_input_for") and main.is_scripted_client():
		var scripted: Dictionary = main.scripted_input_for(body)
		cursor_offset = scripted.get("cursor_offset", Vector2.ZERO)
		burst = bool(scripted.get("burst", false))
		reverse = bool(scripted.get("reverse", false))
		cloak_held = bool(scripted.get("cloak_held", false))
		editing = bool(scripted.get("editing", false))
		return
	if main.has_method("cursor_offset_for"):
		cursor_offset = main.cursor_offset_for(body)
	else:
		cursor_offset = Vector2.ZERO
	burst = Input.is_action_pressed("burst")
	reverse = Input.is_action_pressed("reverse")
	editing = bool(main.call("combat_editor_active", body)) \
		if main.has_method("combat_editor_active") else false
	cloak_held = Input.is_action_pressed("cloak") and not editing
