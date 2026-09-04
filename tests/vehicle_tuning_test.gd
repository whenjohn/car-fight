extends SceneTree

const TUNING := preload("res://player/vehicle_tuning.gd")

var _failures: Array[String] = []


func _init() -> void:
	_check(is_equal_approx(TUNING.default_mass("LP Car A03-1"), 1.6),
		"low-poly cars default to Light")
	_check(is_equal_approx(TUNING.default_mass("Jeep"), 2.2),
		"Jeep defaults to Standard")
	_check(is_equal_approx(TUNING.default_mass("Humvee M242"), 3.2),
		"Humvee defaults to Heavy")
	_check(is_equal_approx(TUNING.default_mass("Apocalypse Bus"), 4.5),
		"Apocalypse Bus defaults to Super Heavy")
	_check(TUNING.weight_class(1.6) == "Light" \
		and TUNING.weight_class(2.2) == "Standard" \
		and TUNING.weight_class(3.2) == "Heavy" \
		and TUNING.weight_class(4.5) == "Super Heavy",
		"mass values expose readable weight classes")
	_check(is_equal_approx(TUNING.validated_mass(3.2), 3.2) \
		and TUNING.validated_mass(0.9) < 0.0 \
		and TUNING.validated_mass(6.1) < 0.0 \
		and TUNING.validated_mass(1.65) < 0.0 \
		and TUNING.validated_mass({"mass": 3.2}) < 0.0,
		"server accepts only bounded 0.1-step masses")

	var main := FileAccess.get_file_as_string("res://Main.gd")
	var body := FileAccess.get_file_as_string("res://player/player_body.gd")
	var editor := FileAccess.get_file_as_string("res://ui/vehicle_tuning_editor.gd")
	_check("Vehicle Tuning…" in main and "_build_vehicle_tuning_editor" in main,
		"Vehicle Model menu opens a dedicated tuning window")
	_check("vehicle_mass" in main and "vehicle_mass" in body \
		and "body.mass = vehicle_mass" in main,
		"replicated spawn data configures authoritative body mass")
	_check("_request_vehicle_tuning_respawn.rpc_id(1" in main \
		and "_accept_vehicle_tuning_respawn" in main,
		"size and mass use one server-authoritative respawn request")
	_check("force_native = true" in editor and "Apply & Respawn" in editor \
		and "Server-approved" in editor and "Weight class" in editor,
		"tuner follows the compact native editor pattern")
	_check("tool_window_has_input_focus" in main \
		and "_vehicle_tuning_editor" in main,
		"vehicle input pauses while the tuning window owns focus")
	_check("Show collision capsules (all vehicles)" in main \
		and "_set_all_vehicle_collision_debug_visible" in main,
		"collision debug applies to every replicated vehicle")

	if _failures.is_empty():
		print("VEHICLE_TUNING_TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
