extends SceneTree

const AUTHORITY := preload("res://player/vehicle_size_authority.gd")
const COLLISION := preload("res://player/server_driver_collision.gd")
const VEHICLE_CONFIG := preload("res://player/vehicle_config.gd")

var _failures: Array[String] = []


func _init() -> void:
	_check(is_equal_approx(AUTHORITY.validated_scale(1.5), 1.5),
		"server accepts a built-in vehicle sizing step")
	_check(AUTHORITY.validated_scale(1.33) < 0.0 \
		and AUTHORITY.validated_scale({"scale": 1.5}) < 0.0,
		"server rejects arbitrary or malformed collision scales")
	_check(AUTHORITY.valid_vehicle_index(0, 12) \
		and not AUTHORITY.valid_vehicle_index(12, 12),
		"server validates the selected vehicle model")

	var collision_helper := COLLISION.new()
	_check(collision_helper.has_method("scaled_dimensions"),
		"shared vehicle capsule exposes deterministic scaled dimensions")
	if collision_helper.has_method("scaled_dimensions"):
		var dimensions: Dictionary = collision_helper.call("scaled_dimensions", 1.5)
		_check(is_equal_approx(float(dimensions["radius"]),
			VEHICLE_CONFIG.CAPSULE_RADIUS * 1.5),
			"150% sizing expands capsule width")
		_check(is_equal_approx(float(dimensions["height"]),
			VEHICLE_CONFIG.CAPSULE_HEIGHT * 1.5),
			"150% sizing expands capsule length")
		_check(is_equal_approx(float(dimensions["center_y"])
			- float(dimensions["radius"]), -VEHICLE_CONFIG.COLLISION_RADIUS),
			"scaled capsule preserves road clearance")

	var main_source := FileAccess.get_file_as_string("res://Main.gd")
	_check("Apply Draft & Respawn" in main_source \
		and "Show collision capsules (all vehicles)" in main_source \
		and "_request_vehicle_tuning_respawn.rpc_id(1" in main_source,
		"Vehicle Model menu sends an explicit request to the server")
	_check("_accept_vehicle_tuning_respawn" in main_source \
		and "remote_generation" in main_source,
		"server recreates the body with a fresh network generation")
	_check("vehicle_collider_scale" in main_source,
		"replicated spawn data configures the authoritative capsule")

	if _failures.is_empty():
		print("VEHICLE_SIZE_RESPAWN_TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
