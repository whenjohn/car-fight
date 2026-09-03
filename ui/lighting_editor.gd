extends Node
## Client-local live editor for the handful of lighting controls that make an
## obvious visual difference. Main owns the Environment and Light3D nodes; this
## window only presents values and emits edits.

signal values_changed(values: Dictionary)
signal look_loaded(base_preset: String, values: Dictionary)
signal reset_requested

const WORKING_PATH := "user://lighting_working.cfg"
const LOOKS_PATH := "user://lighting_looks.cfg"
const STORAGE_SECTION := "lighting"
const LOOKS_SECTION := "looks"

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
var _saved_looks: OptionButton
var _look_name: LineEdit
var _save_status: Label
var _sun_color: ColorPickerButton
var _contact_shadows: CheckBox
var _spins := {}
var _values := {}
var _base_preset_name := ""
var _looks := {}
var _updating := false


func setup(initial_values: Dictionary, preset_name: String) -> void:
	_build_window()
	_set_values(initial_values, preset_name, false)
	_load_looks()
	_restore_working()


func open() -> void:
	_window.popup_centered(Vector2i(470, 540))


func has_input_focus() -> bool:
	return _window != null and _window.visible and _window.has_focus()


func _return_to_game() -> void:
	get_tree().root.grab_focus()


func _close() -> void:
	_window.hide()
	_return_to_game()


func set_values(values: Dictionary, preset_name: String) -> void:
	_set_values(values, preset_name, true)
	_save_status.text = "Working look autosaved."


func _set_values(values: Dictionary, preset_name: String, save_working: bool) -> void:
	_values = values.duplicate()
	_base_preset_name = preset_name
	_updating = true
	_preset_label.text = "Editing from preset: %s" % preset_name
	for key in FIELDS:
		(_spins[key] as SpinBox).value = float(_values.get(key, 0.0))
	_sun_color.color = _values.get("sun_color", Color.WHITE) as Color
	_contact_shadows.button_pressed = bool(_values.get("contact_shadows", true))
	_updating = false
	if save_working:
		_save_working()


func _build_window() -> void:
	_window = Window.new()
	_window.name = "LightingEditorWindow"
	_window.title = "Lighting Editor"
	_window.visible = false
	_window.transient = true
	_window.exclusive = false
	# Car Fight stretches its embedded 1280x720 canvas with the game window.
	# Keep this tool in native pixels so resizing the game does not also magnify
	# the editor into a giant overlay.
	_window.force_native = true
	_window.close_requested.connect(_close)
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
	intro.text = "Changes are live, local, and autosaved as your working look."
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

	root.add_child(HSeparator.new())
	var saved_title := Label.new()
	saved_title.text = "Saved looks"
	root.add_child(saved_title)
	var load_row := HBoxContainer.new()
	_saved_looks = OptionButton.new()
	_saved_looks.name = "SavedLooks"
	_saved_looks.custom_minimum_size.x = 250.0
	load_row.add_child(_saved_looks)
	var load_button := Button.new()
	load_button.text = "Load"
	load_button.pressed.connect(_load_selected_look)
	load_row.add_child(load_button)
	var delete_button := Button.new()
	delete_button.text = "Delete"
	delete_button.pressed.connect(_delete_selected_look)
	load_row.add_child(delete_button)
	root.add_child(load_row)
	var save_row := HBoxContainer.new()
	_look_name = LineEdit.new()
	_look_name.name = "LookName"
	_look_name.placeholder_text = "Name this look…"
	_look_name.custom_minimum_size.x = 300.0
	_look_name.text_submitted.connect(func(_text: String):
		_save_named_look()
		_return_to_game()
	)
	save_row.add_child(_look_name)
	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_save_named_look)
	save_row.add_child(save_button)
	root.add_child(save_row)
	_save_status = Label.new()
	_save_status.name = "SaveStatus"
	_save_status.modulate = Color(0.72, 0.72, 0.72)
	root.add_child(_save_status)


func _on_value_changed(key: String, value: float) -> void:
	if _updating:
		return
	_values[key] = value
	_save_working()
	_save_status.text = "Working look autosaved."
	values_changed.emit(_values.duplicate())


func _on_sun_color_changed(color: Color) -> void:
	if _updating:
		return
	_values["sun_color"] = color
	_save_working()
	_save_status.text = "Working look autosaved."
	values_changed.emit(_values.duplicate())


func _on_contact_shadows_toggled(enabled: bool) -> void:
	if _updating:
		return
	_values["contact_shadows"] = enabled
	_save_working()
	_save_status.text = "Working look autosaved."
	values_changed.emit(_values.duplicate())


func _save_working() -> void:
	var config := ConfigFile.new()
	config.set_value(STORAGE_SECTION, "base_preset", _base_preset_name)
	config.set_value(STORAGE_SECTION, "values", _values)
	config.save(WORKING_PATH)


func _restore_working() -> void:
	var config := ConfigFile.new()
	if config.load(WORKING_PATH) != OK:
		return
	var saved_values = config.get_value(STORAGE_SECTION, "values", {})
	if not saved_values is Dictionary:
		return
	var restored := _values.duplicate()
	for key in restored:
		if saved_values.has(key):
			restored[key] = saved_values[key]
	var base_preset := String(config.get_value(STORAGE_SECTION, "base_preset",
		_base_preset_name))
	look_loaded.emit(base_preset, restored.duplicate())
	_set_values(restored, base_preset, false)
	_save_status.text = "Restored autosaved working look."


func _load_looks() -> void:
	_looks.clear()
	var config := ConfigFile.new()
	if config.load(LOOKS_PATH) == OK:
		for look_name in config.get_section_keys(LOOKS_SECTION):
			var snapshot = config.get_value(LOOKS_SECTION, look_name, {})
			if snapshot is Dictionary:
				_looks[look_name] = snapshot
	_refresh_saved_looks()


func _write_looks() -> void:
	var config := ConfigFile.new()
	var names := _looks.keys()
	names.sort()
	for look_name in names:
		config.set_value(LOOKS_SECTION, look_name, _looks[look_name])
	config.save(LOOKS_PATH)


func _refresh_saved_looks(selected_name: String = "") -> void:
	_saved_looks.clear()
	var names := _looks.keys()
	names.sort()
	if names.is_empty():
		_saved_looks.add_item("No saved looks")
		_saved_looks.disabled = true
		return
	_saved_looks.disabled = false
	for look_name in names:
		_saved_looks.add_item(look_name)
		if look_name == selected_name:
			_saved_looks.select(_saved_looks.item_count - 1)


func _selected_look_name() -> String:
	if _saved_looks.disabled or _saved_looks.selected < 0:
		return ""
	return _saved_looks.get_item_text(_saved_looks.selected)


func _save_named_look() -> void:
	var look_name := _look_name.text.strip_edges()
	if look_name.is_empty():
		_save_status.text = "Enter a name first."
		return
	_looks[look_name] = {
		"base_preset": _base_preset_name,
		"values": _values.duplicate(),
	}
	_write_looks()
	_refresh_saved_looks(look_name)
	_look_name.clear()
	_save_status.text = "Saved look “%s”." % look_name


func _load_selected_look() -> void:
	var look_name := _selected_look_name()
	if look_name.is_empty():
		return
	var snapshot: Dictionary = _looks[look_name]
	var saved_values = snapshot.get("values", {})
	if not saved_values is Dictionary:
		_save_status.text = "Saved look is invalid."
		return
	var restored := _values.duplicate()
	for key in restored:
		if saved_values.has(key):
			restored[key] = saved_values[key]
	var base_preset := String(snapshot.get("base_preset", _base_preset_name))
	look_loaded.emit(base_preset, restored.duplicate())
	_set_values(restored, base_preset, true)
	_save_status.text = "Loaded look “%s”." % look_name


func _delete_selected_look() -> void:
	var look_name := _selected_look_name()
	if look_name.is_empty():
		return
	_looks.erase(look_name)
	_write_looks()
	_refresh_saved_looks()
	_save_status.text = "Deleted look “%s”." % look_name
