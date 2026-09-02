extends Node
## Client-local live editor for the handful of lighting controls that make an
## obvious visual difference. Main owns the Environment and Light3D nodes; this
## window only presents values and emits edits.

signal values_changed(values: Dictionary)
signal reset_requested

const FIELDS := {
	"sun_energy": {
		"label": "Sun brightness", "min": 0.0, "max": 3.0, "step": 0.05,
		"tip": "Strength of the main directional light.",
	},
	"sun_elevation": {
		"label": "Sun height", "min": 5.0, "max": 85.0, "step": 1.0,
		"tip": "Low values create long side lighting; high values feel like midday.",
	},
	"sun_azimuth": {
		"label": "Sun direction", "min": -180.0, "max": 180.0, "step": 1.0,
		"tip": "Rotates the sunlight around the city.",
	},
	"ambient_energy": {
		"label": "World fill", "min": 0.0, "max": 2.0, "step": 0.05,
		"tip": "Brightness outside the direct sun. Lower values deepen shaded areas.",
	},
	"exposure": {
		"label": "Exposure", "min": 0.25, "max": 2.0, "step": 0.05,
		"tip": "Overall scene brightness before display.",
	},
	"saturation": {
		"label": "Color saturation", "min": 0.0, "max": 2.0, "step": 0.05,
		"tip": "0 is grayscale; 1 keeps the source colors.",
	},
	"shadow_opacity": {
		"label": "Shadow darkness", "min": 0.0, "max": 1.0, "step": 0.05,
		"tip": "Darkness of the Intel-safe positional contact shadows.",
	},
}

var _window: Window
var _preset_label: Label
var _sun_color: ColorPickerButton
var _contact_shadows: CheckBox
var _spins := {}
var _values := {}
var _updating := false


func setup(initial_values: Dictionary, preset_name: String) -> void:
	_build_window()
	set_values(initial_values, preset_name)


func open() -> void:
	_window.popup_centered(Vector2i(560, 650))


func set_values(values: Dictionary, preset_name: String) -> void:
	_values = values.duplicate()
	_updating = true
	_preset_label.text = "Editing from preset: %s" % preset_name
	for key in FIELDS:
		(_spins[key] as SpinBox).value = float(_values.get(key, 0.0))
	_sun_color.color = _values.get("sun_color", Color.WHITE) as Color
	_contact_shadows.button_pressed = bool(_values.get("contact_shadows", true))
	_updating = false


func _build_window() -> void:
	_window = Window.new()
	_window.name = "LightingEditorWindow"
	_window.title = "Lighting Editor"
	_window.visible = false
	_window.transient = true
	_window.exclusive = false
	_window.close_requested.connect(_window.hide)
	add_child(_window)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_window.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	scroll.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	_preset_label = Label.new()
	_preset_label.name = "PresetLabel"
	root.add_child(_preset_label)
	var intro := Label.new()
	intro.text = "Changes are live and local to this game window."
	intro.modulate = Color(0.72, 0.72, 0.72)
	root.add_child(intro)
	root.add_child(HSeparator.new())

	var color_row := HBoxContainer.new()
	var color_label := Label.new()
	color_label.text = "Sun color"
	color_label.custom_minimum_size.x = 170.0
	color_label.tooltip_text = "Color and warmth of the direct sunlight."
	color_row.add_child(color_label)
	_sun_color = ColorPickerButton.new()
	_sun_color.name = "SunColor"
	_sun_color.custom_minimum_size = Vector2(190.0, 32.0)
	_sun_color.tooltip_text = color_label.tooltip_text
	_sun_color.color_changed.connect(_on_sun_color_changed)
	color_row.add_child(_sun_color)
	root.add_child(color_row)

	for key in FIELDS:
		var field: Dictionary = FIELDS[key]
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = field["label"]
		label.custom_minimum_size.x = 170.0
		label.tooltip_text = field["tip"]
		row.add_child(label)
		var spin := SpinBox.new()
		spin.name = key.to_pascal_case()
		spin.min_value = field["min"]
		spin.max_value = field["max"]
		spin.step = field["step"]
		spin.allow_greater = false
		spin.allow_lesser = false
		spin.custom_minimum_size.x = 190.0
		spin.tooltip_text = field["tip"]
		spin.value_changed.connect(func(value: float): _on_value_changed(key, value))
		row.add_child(spin)
		_spins[key] = spin
		root.add_child(row)

	_contact_shadows = CheckBox.new()
	_contact_shadows.name = "ContactShadows"
	_contact_shadows.text = "Intel-safe contact shadows"
	_contact_shadows.tooltip_text = (
		"Uses the existing positional shadow light; directional shadows remain disabled."
	)
	_contact_shadows.toggled.connect(_on_contact_shadows_toggled)
	root.add_child(_contact_shadows)
	root.add_child(HSeparator.new())
	var reset := Button.new()
	reset.name = "ResetPreset"
	reset.text = "Reset to selected preset"
	reset.tooltip_text = "Discard these edits and restore the Scenery menu preset."
	reset.pressed.connect(func(): reset_requested.emit())
	root.add_child(reset)


func _on_value_changed(key: String, value: float) -> void:
	if _updating:
		return
	_values[key] = value
	values_changed.emit(_values.duplicate())


func _on_sun_color_changed(color: Color) -> void:
	if _updating:
		return
	_values["sun_color"] = color
	values_changed.emit(_values.duplicate())


func _on_contact_shadows_toggled(enabled: bool) -> void:
	if _updating:
		return
	_values["contact_shadows"] = enabled
	values_changed.emit(_values.duplicate())
