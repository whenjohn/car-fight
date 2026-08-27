extends SceneTree

const SKIDS := preload("res://player/tire_skid_trails.gd")

var _failures: Array[String] = []


func _init() -> void:
	_check(SKIDS.skid_strength(0.0, 0.0, 0.0, 18.0, false) == 0.0,
		"ordinary rolling leaves the road clean")
	_check(SKIDS.skid_strength(1.0, 0.0, 0.0, 18.0, true) > 0.95,
		"hard braking marks front tires")
	var rear_drift := SKIDS.skid_strength(0.0, 1.0, 0.0, 18.0, false)
	var front_drift := SKIDS.skid_strength(0.0, 1.0, 0.0, 18.0, true)
	_check(rear_drift > 0.95 and rear_drift > front_drift,
		"drifts make stronger rear ribbons than front scrub")
	_check(SKIDS.skid_strength(0.0, 0.0, 1.0, 12.0, false) > 0.95,
		"oil residue marks a rolling rear tire")
	_check(SKIDS.skid_strength(1.0, 1.0, 1.0, 0.5, false) < 0.01,
		"stationary tires cannot paint marks")
	_check(not SKIDS.can_connect(Vector3.ZERO, Vector3(0.02, 0.0, 0.0)),
		"tiny samples do not create dense overlapping geometry")
	_check(SKIDS.can_connect(Vector3.ZERO, Vector3(0.4, 0.0, 0.0)),
		"nearby samples connect into a continuous curve")
	_check(not SKIDS.can_connect(Vector3.ZERO, Vector3(4.0, 0.0, 0.0)),
		"teleports and map transitions cannot draw a bridge")
	var trails := SKIDS.new()
	trails.call("_ready")
	trails.call("sample_tire", "rear_left", Vector3.ZERO, Vector3.RIGHT,
		0.12, 1.0, 0.0, true)
	trails.call("sample_tire", "rear_left", Vector3(0.0, 0.0, -0.4), Vector3.RIGHT,
		0.12, 0.8, 0.0, true)
	trails.call("_process", 0.0)
	var trail_mesh := trails.get_node_or_null("TireSkidMesh") as MeshInstance3D
	_check(int(trails.call("segment_count")) == 1 and trail_mesh != null \
		and trail_mesh.mesh != null and trail_mesh.mesh.get_surface_count() == 1,
		"two moving contact samples build one continuous tire quad")
	trails.call("sample_tire", "rear_left", Vector3(5.0, 0.0, -0.4), Vector3.RIGHT,
		0.12, 1.0, 0.0, true)
	_check(int(trails.call("segment_count")) == 1,
		"a discontinuity resets the emitter without adding geometry")
	trails.free()

	var shader := load("res://fx/tire_skid_trail.gdshader") as Shader
	_check(shader != null and "soft_edge" in shader.code and "center_tread" in shader.code,
		"skid shader retains soft tire-shaped breakup")
	if _failures.is_empty():
		print("TIRE_SKID_TRAILS_TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
