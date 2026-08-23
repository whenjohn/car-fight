extends Node3D
## Close-up, network-free workbench for tuning vehicle presentation.

const HULL_SCRIPT := preload("res://player/ground_vehicle_hull.gd")
const LAB_BODY_SCRIPT := preload("res://tools/vehicle_animation_lab_body.gd")

const PRESETS := [
	{"name": "Neutral", "speed": 0.0, "steer": 0.0, "brake": 0.0,
		"load": 0.0, "drift": 0.0, "boost": false},
	{"name": "Fast left", "speed": 18.0, "steer": -1.0, "brake": 0.0,
		"load": 0.0, "drift": 0.0, "boost": false},
	{"name": "Fast right", "speed": 18.0, "steer": 1.0, "brake": 0.0,
		"load": 0.0, "drift": 0.0, "boost": false},
	{"name": "Hard brake", "speed": 18.0, "steer": 0.0, "brake": 1.0,
		"load": -1.0, "drift": 0.0, "boost": false},
	{"name": "Launch", "speed": 8.0, "steer": 0.0, "brake": 0.0,
		"load": 1.0, "drift": 0.0, "boost": false},
	{"name": "Boost", "speed": 28.0, "steer": 0.18, "brake": 0.0,
		"load": 1.0, "drift": 0.0, "boost": true},
	{"name": "Drift left", "speed": 18.0, "steer": -0.75, "brake": 0.78,
		"load": -0.35, "drift": -1.0, "boost": false},
	{"name": "Drift right", "speed": 18.0, "steer": 0.75, "brake": 0.78,
		"load": -0.35, "drift": 1.0, "boost": false},
]

var _body: RigidBody3D
var _hull: Node3D
var _camera: Camera3D
var _camera_yaw := deg_to_rad(38.0)
var _camera_pitch := deg_to_rad(-18.0)
var _camera_distance := 7.2
var _orbiting := false
var _preset_index := 0
var _preset_buttons: Array[Button] = []
var _sliders := {}
var _value_labels := {}
var _state_label: Label
var _vehicle_button: Button
var _boost_check: CheckButton
var _paused := false

func _ready() -> void:
	DisplayServer.window_set_title("Car Fight — Vehicle Animation Lab")
	_build_world()
	_build_vehicle()
	_build_ui()
	_apply_preset(0)
	_update_camera()

func _process(_delta: float) -> void:
	if _paused:
		return
	var speed := float((_sliders["speed"] as HSlider).value)
	var steer := float((_sliders["steer"] as HSlider).value)
	var brake := float((_sliders["brake"] as HSlider).value)
	var load := float((_sliders["load"] as HSlider).value)
	var drift := float((_sliders["drift"] as HSlider).value)
	_hull.call("set_animation_preview_state", {
		"speed": speed,
		"signed_speed": speed,
		"steer": steer,
		"yaw_rate": steer * HULL_SCRIPT.STEER_RATE_REFERENCE,
		"brake": brake,
		"longitudinal_load": load,
		"drift": drift,
		"boosting": _boost_check.button_pressed,
	})
	_body.brake_skid_amount = brake
	_body.boost_active = _boost_check.button_pressed
	_body.drift_assist_amount = absf(drift)
	_body.drift_assist_side = signf(drift)
	for key in _sliders.keys():
		(_value_labels[key] as Label).text = _format_value(str(key),
			float((_sliders[key] as HSlider).value))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_orbiting = mouse.pressed
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = maxf(_camera_distance - 0.6, 3.4)
			_update_camera()
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = minf(_camera_distance + 0.6, 13.0)
			_update_camera()
	elif event is InputEventMouseMotion and _orbiting:
		var motion := event as InputEventMouseMotion
		_camera_yaw -= motion.relative.x * 0.008
		_camera_pitch = clampf(_camera_pitch - motion.relative.y * 0.008,
			deg_to_rad(-72.0), deg_to_rad(12.0))
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode >= KEY_1 and key.keycode <= KEY_8:
			_apply_preset(int(key.keycode - KEY_1))
		elif key.keycode == KEY_SPACE:
			_paused = not _paused
			_state_label.text = "%s  •  %s" % [str(PRESETS[_preset_index]["name"]),
				"PAUSED" if _paused else "LIVE"]
		elif key.keycode == KEY_V:
			_cycle_vehicle()

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("17202b")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b8c9dc")
	settings.ambient_light_energy = 0.72
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-54.0, -32.0, 0.0)
	light.light_energy = 1.45
	light.shadow_enabled = true
	add_child(light)

	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(40.0, 40.0)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("2b3440")
	floor_material.roughness = 0.9
	floor.material_override = floor_material
	add_child(floor)

	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 38.0
	add_child(_camera)

func _build_vehicle() -> void:
	_body = RigidBody3D.new()
	_body.name = "AnimationPreviewBody"
	_body.set_script(LAB_BODY_SCRIPT)
	_body.freeze = true
	_body.position = Vector3(0.0, 1.15, 0.0)
	add_child(_body)
	_hull = Node3D.new()
	_hull.name = "GroundVehicleHull"
	_hull.set_script(HULL_SCRIPT)
	_body.add_child(_hull)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(20.0, 20.0)
	panel.custom_minimum_size = Vector2(318.0, 0.0)
	canvas.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	var title := Label.new()
	title.text = "VEHICLE ANIMATION LAB"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	_state_label = Label.new()
	_state_label.text = "Neutral  •  LIVE"
	_state_label.modulate = Color("7fe7ff")
	box.add_child(_state_label)

	var presets := GridContainer.new()
	presets.columns = 2
	box.add_child(presets)
	for index in range(PRESETS.size()):
		var button := Button.new()
		button.text = "%d  %s" % [index + 1, str(PRESETS[index]["name"])]
		button.pressed.connect(_apply_preset.bind(index))
		presets.add_child(button)
		_preset_buttons.append(button)

	_add_slider(box, "speed", "Road speed", 0.0, 30.0, 0.1)
	_add_slider(box, "steer", "Steering", -1.0, 1.0, 0.01)
	_add_slider(box, "brake", "Brake / lock", 0.0, 1.0, 0.01)
	_add_slider(box, "load", "Gas ↔ brake load", -1.0, 1.0, 0.01)
	_add_slider(box, "drift", "Drift side", -1.0, 1.0, 0.01)
	_boost_check = CheckButton.new()
	_boost_check.text = "Boost afterimages"
	_boost_check.toggled.connect(_manual_edit.unbind(1))
	box.add_child(_boost_check)
	_vehicle_button = Button.new()
	_vehicle_button.text = "Vehicle: Jeep  (V)"
	_vehicle_button.pressed.connect(_cycle_vehicle)
	box.add_child(_vehicle_button)
	var help := Label.new()
	help.text = "Drag empty space: orbit\nWheel: zoom  •  Space: pause  •  V: vehicle"
	help.modulate = Color("aebbc8")
	box.add_child(help)

func _add_slider(parent: VBoxContainer, key: String, caption: String,
		minimum: float, maximum: float, step: float) -> void:
	var header := HBoxContainer.new()
	parent.add_child(header)
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var value := Label.new()
	value.custom_minimum_size.x = 62.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(value)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value_changed.connect(_manual_edit.unbind(1))
	parent.add_child(slider)
	_sliders[key] = slider
	_value_labels[key] = value

func _apply_preset(index: int) -> void:
	if index < 0 or index >= PRESETS.size():
		return
	_preset_index = index
	var preset: Dictionary = PRESETS[index]
	(_sliders["speed"] as HSlider).value = preset["speed"]
	(_sliders["steer"] as HSlider).value = preset["steer"]
	(_sliders["brake"] as HSlider).value = preset["brake"]
	(_sliders["load"] as HSlider).value = preset["load"]
	(_sliders["drift"] as HSlider).value = preset["drift"]
	_boost_check.button_pressed = preset["boost"]
	_state_label.text = "%s  •  %s" % [str(preset["name"]),
		"PAUSED" if _paused else "LIVE"]
	for button_index in range(_preset_buttons.size()):
		_preset_buttons[button_index].disabled = button_index == index

func _manual_edit() -> void:
	_state_label.text = "Custom  •  %s" % ("PAUSED" if _paused else "LIVE")
	for button in _preset_buttons:
		button.disabled = false

func _cycle_vehicle() -> void:
	_hull.call("cycle_vehicle")
	_vehicle_button.text = "Vehicle: %s  (V)" % str(_hull.call("vehicle_name"))

func _update_camera() -> void:
	var target := Vector3(0.0, 1.1, 0.0)
	var flat := cos(_camera_pitch) * _camera_distance
	_camera.position = target + Vector3(sin(_camera_yaw) * flat,
		sin(-_camera_pitch) * _camera_distance, cos(_camera_yaw) * flat)
	_camera.look_at(target, Vector3.UP)

func _format_value(key: String, value: float) -> String:
	if key == "speed":
		return "%4.1f" % value
	return "%+.2f" % value

