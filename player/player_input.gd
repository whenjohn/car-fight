extends "res://addons/netfox.extras/base-net-input.gd"
## Player intent crosses the network. The server owns resulting physics and combat.

const INPUT_FOCUS_POLICY := preload("res://player/input_focus_policy.gd")

var cursor_offset := Vector2.ZERO
var burst := false
var reverse := false
var cloak_held := false
var shield_held := false
var tractor := false
# Safe spawn default: authority cannot fire before the owning client's first
# gathered input declares that it has entered drive mode.
var editing := true

func _clear_live_input() -> void:
	cursor_offset = Vector2.ZERO
	burst = false
	reverse = false
	cloak_held = false
	shield_held = false
	tractor = false
	# Losing focus is not a request to enter the coverage editor. Keep the
	# vehicle in drive mode with neutral controls so it brakes to a stop.
	editing = false

func _gather() -> void:
	var body := get_parent() as Node3D
	var main := get_tree().current_scene
	if body == null or main == null:
		_clear_live_input()
		editing = true
		return
	if main.has_method("scripted_input_for") and main.is_scripted_client():
		var scripted: Dictionary = main.scripted_input_for(body)
		cursor_offset = scripted.get("cursor_offset", Vector2.ZERO)
		burst = bool(scripted.get("burst", false))
		reverse = bool(scripted.get("reverse", false))
		cloak_held = bool(scripted.get("cloak_held", false))
		shield_held = bool(scripted.get("shield_held", false))
		tractor = bool(scripted.get("tractor", false))
		editing = bool(scripted.get("editing", false))
		return
	# macOS continues updating an unfocused Godot window's mouse position from
	# the focused sibling process. Never turn that global cursor into networked
	# vehicle intent: an unfocused client must be a neutral, braking car.
	if not INPUT_FOCUS_POLICY.live_input_allowed(DisplayServer.window_is_focused()):
		_clear_live_input()
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
	shield_held = Input.is_action_pressed("shield") and not editing
	# Match g2: poll the bare modifier directly so unrelated key events cannot
	# make InputMap lose the held Shift level.
	tractor = Input.is_key_pressed(KEY_SHIFT) and not editing
