extends Node
## Native live tuning window for the presentation-only camera experiment.

signal values_changed(values: Dictionary)
signal reset_requested

const FIELDS := {
	"turn_response": {
		"label": "Turn catch-up", "min": 0.5, "max": 12.0, "step": 0.1,
		"tip": "How quickly the world rotates to put the vehicle nose back at screen-up.",
	},
	"turn_dead_zone": {
		"label": "Turn comfort zone", "min": 0.0, "max": 30.0, "step": 1.0,
		"tip": "How far the vehicle may turn on screen before the world starts rotating.",
	},
	"max_turn_speed": {
		"label": "Maximum camera turn", "min": 30.0, "max": 240.0, "step": 5.0,
		"tip": "Caps world rotation during sharp steering and impacts, in degrees per second.",
	},
	"camera_pitch": {
		"label": "Camera pitch", "min": 35.0, "max": 65.0, "step": 1.0,
		"tip": "Lower values show more building sides and feel less top-down.",
	},
	"look_ahead_distance": {
		"label": "Look-ahead distance", "min": 0.0, "max": 16.0, "step": 0.25,
		"tip": "Maximum distance framed ahead along the vehicle's travel direction.",
	},
	"acceleration_response": {
		"label": "Acceleration ease", "min": 0.5, "max": 12.0, "step": 0.1,
		"tip": "How quickly look-ahead grows while the vehicle gains speed.",
	},
	"braking_response": {
		"label": "Braking ease", "min": 0.5, "max": 12.0, "step": 0.1,
		"tip": "How quickly look-ahead returns while the vehicle slows down.",
	},
}

var _window: Window
var _spins := {}
var _values := {}
var _updating := false


func setup(initial_values: Dictionary) -> void:
	_build_window()
	set_values(initial_values)


func open() -> void:
	_window.popup_centered(Vector2i(470, 390))


func has_input_focus() -> bool:
	return _window != null and _window.visible and _window.has_focus()


func set_values(values: Dictionary) -> void:
	_values = values.duplicate()
	_updating = true
	for key in FIELDS:
		(_spins[key] as SpinBox).value = float(_values.get(key, 0.0))
	_updating = false


func _return_to_game() -> void:
	get_tree().root.grab_focus()


func _close() -> void:
	_window.hide()
	_return_to_game()


func _build_window() -> void:
	_window = Window.new()
	_window.name = "AlwaysForwardCameraWindow"
	_window.title = "Always-Forward Camera"
	_window.visible = false
	_window.transient = true
	_window.exclusive = false
	_window.force_native = true
	_window.close_requested.connect(_close)
	add_child(_window)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_window.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var intro := Label.new()
	intro.text = "Changes are live, local, and autosaved for this experiment."
	intro.modulate = Color(0.72, 0.72, 0.72)
	root.add_child(intro)
	var input_hint := Label.new()
	input_hint.text = "Vehicle controls pause here. Click the game or Return to game to drive."
	input_hint.modulate = Color(0.72, 0.72, 0.72)
	root.add_child(input_hint)
	var return_to_game := Button.new()
	return_to_game.name = "ReturnToGame"
	return_to_game.text = "Return to game"
	return_to_game.pressed.connect(_return_to_game)
	root.add_child(return_to_game)
	root.add_child(HSeparator.new())

	for key in FIELDS:
		var field: Dictionary = FIELDS[key]
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = field["label"]
		label.custom_minimum_size.x = 190.0
		label.tooltip_text = field["tip"]
		row.add_child(label)
		var spin := SpinBox.new()
		spin.name = key.to_pascal_case()
		spin.min_value = field["min"]
		spin.max_value = field["max"]
		spin.step = field["step"]
		spin.allow_greater = false
		spin.allow_lesser = false
		spin.custom_minimum_size.x = 200.0
		spin.tooltip_text = field["tip"]
		spin.value_changed.connect(func(value: float): _on_value_changed(key, value))
		row.add_child(spin)
		_spins[key] = spin
		root.add_child(row)

	root.add_child(HSeparator.new())
	var reset := Button.new()
	reset.name = "ResetDefaults"
	reset.text = "Reset experiment defaults"
	reset.pressed.connect(func(): reset_requested.emit())
	root.add_child(reset)


func _on_value_changed(key: String, value: float) -> void:
	if _updating:
		return
	_values[key] = value
	values_changed.emit(_values.duplicate())
