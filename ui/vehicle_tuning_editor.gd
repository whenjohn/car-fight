extends Node
## Native draft/apply editor for server-authoritative vehicle size and mass.

signal draft_changed(model_scale: float, mass: float)
signal apply_requested(model_scale: float, mass: float)
signal reset_requested
signal collision_visibility_changed(visible: bool)

var _window: Window
var _vehicle_label: Label
var _approved_label: Label
var _weight_label: Label
var _size_option: OptionButton
var _mass_spin: SpinBox
var _collision_check: CheckBox
var _apply_button: Button
var _scale_options: Array = []
var _updating := false


func setup(scale_options: Array) -> void:
	_scale_options = scale_options.duplicate()
	_build_window()


func open(context: Dictionary) -> void:
	set_context(context)
	_window.popup_centered(Vector2i(470, 420))


func has_input_focus() -> bool:
	return _window != null and _window.visible and _window.has_focus()


func set_context(context: Dictionary) -> void:
	if _window == null:
		return
	_updating = true
	_vehicle_label.text = "Vehicle: %s" % str(context.get("vehicle_name", "Jeep"))
	_approved_label.text = "Server-approved: %.0f%% size  |  %.1f mass (%s)" % [
		float(context.get("approved_scale", 1.0)) * 100.0,
		float(context.get("approved_mass", 2.2)),
		str(context.get("approved_weight_class", "Standard")),
	]
	var draft_scale := float(context.get("draft_scale", 1.0))
	for index in range(_scale_options.size()):
		if is_equal_approx(draft_scale, float(_scale_options[index])):
			_size_option.select(index)
			break
	_mass_spin.value = float(context.get("draft_mass", 2.2))
	_weight_label.text = "Weight class: %s" % str(
		context.get("draft_weight_class", "Standard"))
	_collision_check.button_pressed = bool(context.get("collision_visible", false))
	_apply_button.disabled = not bool(context.get("apply_enabled", false))
	_updating = false


func set_collision_visible(visible: bool) -> void:
	if _collision_check == null:
		return
	_updating = true
	_collision_check.button_pressed = visible
	_updating = false


func _return_to_game() -> void:
	get_tree().root.grab_focus()


func _close() -> void:
	_window.hide()
	_return_to_game()


func _build_window() -> void:
	_window = Window.new()
	_window.name = "VehicleTuningWindow"
	_window.title = "Vehicle Tuning"
	_window.visible = false
	_window.transient = true
	_window.exclusive = false
	_window.force_native = true
	_window.close_requested.connect(_close)
	add_child(_window)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	_window.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	_vehicle_label = Label.new()
	_vehicle_label.name = "VehicleName"
	_vehicle_label.add_theme_font_size_override("font_size", 20)
	root.add_child(_vehicle_label)
	_approved_label = Label.new()
	_approved_label.name = "ServerApproved"
	_approved_label.modulate = Color(0.72, 0.82, 0.76)
	root.add_child(_approved_label)
	var intro := Label.new()
	intro.text = "Draft locally, then Apply & Respawn to update server physics."
	intro.modulate = Color(0.72, 0.72, 0.72)
	root.add_child(intro)
	var input_hint := Label.new()
	input_hint.text = "Vehicle controls pause while this window has focus."
	input_hint.modulate = Color(0.72, 0.72, 0.72)
	root.add_child(input_hint)
	root.add_child(HSeparator.new())

	var size_row := HBoxContainer.new()
	var size_label := Label.new()
	size_label.text = "Model + collider size"
	size_label.custom_minimum_size.x = 205.0
	size_row.add_child(size_label)
	_size_option = OptionButton.new()
	_size_option.name = "ModelScale"
	_size_option.custom_minimum_size.x = 190.0
	for scale_variant in _scale_options:
		var scale := float(scale_variant)
		_size_option.add_item("%.0f%%" % (scale * 100.0))
	_size_option.item_selected.connect(_on_size_selected)
	size_row.add_child(_size_option)
	root.add_child(size_row)

	var mass_row := HBoxContainer.new()
	var mass_label := Label.new()
	mass_label.text = "Mass"
	mass_label.custom_minimum_size.x = 205.0
	mass_label.tooltip_text = "Controls momentum and resistance to knockback; independent of size."
	mass_row.add_child(mass_label)
	_mass_spin = SpinBox.new()
	_mass_spin.name = "Mass"
	_mass_spin.min_value = 1.0
	_mass_spin.max_value = 6.0
	_mass_spin.step = 0.1
	_mass_spin.allow_greater = false
	_mass_spin.allow_lesser = false
	_mass_spin.custom_minimum_size.x = 190.0
	_mass_spin.tooltip_text = mass_label.tooltip_text
	_mass_spin.value_changed.connect(_on_mass_changed)
	mass_row.add_child(_mass_spin)
	root.add_child(mass_row)

	_weight_label = Label.new()
	_weight_label.name = "WeightClass"
	_weight_label.text = "Weight class: Standard"
	root.add_child(_weight_label)
	_collision_check = CheckBox.new()
	_collision_check.name = "ShowCollisionCapsule"
	_collision_check.text = "Show collision capsules (all vehicles)"
	_collision_check.toggled.connect(_on_collision_toggled)
	root.add_child(_collision_check)
	root.add_child(HSeparator.new())

	_apply_button = Button.new()
	_apply_button.name = "ApplyRespawn"
	_apply_button.text = "Apply & Respawn"
	_apply_button.tooltip_text = "Server validates size and mass, then recreates this vehicle for every client."
	_apply_button.pressed.connect(_on_apply)
	root.add_child(_apply_button)
	var reset := Button.new()
	reset.name = "ResetDefaults"
	reset.text = "Reset Vehicle Defaults"
	reset.pressed.connect(func(): reset_requested.emit())
	root.add_child(reset)
	var return_to_game := Button.new()
	return_to_game.name = "ReturnToGame"
	return_to_game.text = "Return to game"
	return_to_game.pressed.connect(_return_to_game)
	root.add_child(return_to_game)


func _draft_scale() -> float:
	if _size_option.selected < 0 or _size_option.selected >= _scale_options.size():
		return 1.0
	return float(_scale_options[_size_option.selected])


func _on_size_selected(_index: int) -> void:
	if not _updating:
		draft_changed.emit(_draft_scale(), _mass_spin.value)


func _on_mass_changed(value: float) -> void:
	if not _updating:
		draft_changed.emit(_draft_scale(), value)


func _on_collision_toggled(visible: bool) -> void:
	if not _updating:
		collision_visibility_changed.emit(visible)


func _on_apply() -> void:
	apply_requested.emit(_draft_scale(), _mass_spin.value)
