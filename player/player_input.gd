extends "res://addons/netfox.extras/base-net-input.gd"
## Player intent crosses the network. The server owns resulting physics and combat.

const INPUT_FOCUS_POLICY := preload("res://player/input_focus_policy.gd")

var cursor_offset := Vector2.ZERO
var burst := false
var reverse := false
var cloak_held := false
var shield_held := false
var tractor := false
## Det is held, not toggled: Cmd on macOS and Alt on other platforms, matching g2.
var det := false
# The Web export reports its OS as "Web", even when it is running in a Mac
# browser. Keep Command as the primary Mac/Web binding; accepting Alt as well
# on Web preserves the portable fallback for non-Mac browsers.
var _det_key: Key = KEY_META if OS.get_name() in ["macOS", "Web"] else KEY_ALT
var area_arm_held := false
var area_fire := false
var homing_held := false
var rc_fire_held := false
var rc_detonate_held := false
var drop_troops := false
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
	det = false
	area_arm_held = false
	area_fire = false
	homing_held = false
	rc_fire_held = false
	rc_detonate_held = false
	drop_troops = false
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
		det = bool(scripted.get("det", false))
		area_arm_held = bool(scripted.get("area_arm_held", false))
		area_fire = bool(scripted.get("area_fire", false))
		homing_held = bool(scripted.get("homing_held", false))
		rc_fire_held = bool(scripted.get("rc_fire_held", false))
		rc_detonate_held = bool(scripted.get("rc_detonate_held", false))
		drop_troops = bool(scripted.get("drop_troops", false))
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
	det = (Input.is_key_pressed(_det_key) \
		or (OS.has_feature("web") and Input.is_key_pressed(KEY_ALT))) and not editing
	# Slot 3 mirrors the isometric Splash weapon: arm it once, then hold the
	# primary button and drag a ground area before releasing to call the run.
	area_arm_held = Input.is_key_pressed(KEY_3) and not editing
	area_fire = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not editing
	# Unlike G2's slot-selection gesture, Car Fight fires slot 1 immediately.
	homing_held = Input.is_key_pressed(KEY_1) and not editing
	# Unlike G2's slot selector, Num 2 fires the RC orb immediately. Left mouse
	# detonates an active orb; both values cross the existing input timeline.
	rc_fire_held = (Input.is_key_pressed(KEY_2) or Input.is_key_pressed(KEY_KP_2)) and not editing
	rc_detonate_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not editing
	# Troop delivery is deliberately a vehicle-area interaction: hold F only
	# while inside the red pad's radius; there is no cursor targeting involved.
	drop_troops = Input.is_key_pressed(KEY_F) and not editing
