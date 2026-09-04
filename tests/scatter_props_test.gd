extends SceneTree

const CONFIG_PATH := "res://world/scatter_prop_config.gd"
const BODY_PATH := "res://world/scatter_prop.gd"

var _failures: Array[String] = []


func _init() -> void:
	_check(FileAccess.file_exists(CONFIG_PATH), "scatter prop configuration exists")
	_check(FileAccess.file_exists(BODY_PATH), "networked scatter prop body exists")
	var main_source := FileAccess.get_file_as_string("res://Main.gd")
	var config_source := FileAccess.get_file_as_string(CONFIG_PATH)
	var body_source := FileAccess.get_file_as_string(BODY_PATH)
	var state_bundle_source := FileAccess.get_file_as_string("res://net/state_bundle.gd")
	_check("_scatter_prop_spawner" in main_source
		and "_spawn_ramming_lab_props" in main_source,
		"the server owns a dedicated ramming-lab prop spawner")
	_check("RollbackSynchronizer" in main_source
		and "TickInterpolator" in main_source,
		"scatter motion uses the existing authoritative rigid-body network path")
	for kind in ["barrel", "crate", "tire", "mailbox"]:
		_check(kind in config_source, "configuration includes %s props" % kind)
	_check("MASS_MAX := 0.18" in config_source,
		"props stay much lighter than the lightest tunable vehicle")
	_check("continuous_cd = true" in main_source,
		"fast vehicle impacts use continuous collision detection")
	_check("physics_state" in body_source and "global_transform" in body_source,
		"prop physics and presentation transforms are synchronized")
	_check("ScatterProps" in state_bundle_source and "route_id" in state_bundle_source,
		"packed state reserves stable authoritative routes for scatter props")
	_check("scatter_prop_library.tscn" in main_source,
		"city-pack prop presentation uses the extracted visual library")

	if _failures.is_empty():
		print("SCATTER_PROPS_TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
