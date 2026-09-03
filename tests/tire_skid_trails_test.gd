extends SceneTree

const SKIDS := preload("res://player/tire_skid_trails.gd")

var _failures: Array[String] = []


func _init() -> void:
	_check(SKIDS.skid_strength(0.0, 0.0, 0.0, 18.0, false) == 0.0,
		"ordinary rolling leaves the road clean")
	_check(SKIDS.skid_strength(1.0, 0.0, 0.0, 18.0, false) > 0.95 \
		and SKIDS.skid_strength(1.0, 0.0, 0.0, 18.0, true) == 0.0,
		"hard braking still paints only the rear pair")
	_check(SKIDS.reverse_brake_strength(true, 16.0) > 0.99,
		"reverse acts as a hard rear brake at high forward speed")
	_check(SKIDS.reverse_brake_strength(true, -16.0) == 0.0 \
		and SKIDS.reverse_brake_strength(false, 16.0) == 0.0,
		"ordinary backward travel and an unheld reverse key do not mark")
	var rear_drift := SKIDS.skid_strength(0.0, 1.0, 0.0, 18.0, false)
	var front_drift := SKIDS.skid_strength(0.0, 1.0, 0.0, 18.0, true)
	_check(rear_drift > 0.95 and front_drift == 0.0,
		"ordinary drift peel-out paints only the driven rear tires")
	var sustained_drift := SKIDS.sustained_slide(0.02, 0.0, 1.0)
	_check(sustained_drift > 0.75 \
		and SKIDS.skid_strength(0.0, sustained_drift, 0.0, 18.0, false) > 0.95,
		"a peel pulse survives a brief center-velocity alignment")
	_check(SKIDS.should_start_peel(true, true, 0.0, 0.0) \
		and not SKIDS.should_start_peel(false, true, 1.0, 1.0),
		"drift assist starts one armed peel pulse rather than continuous paint")
	_check(SKIDS.should_start_peel(true, false, 0.30, 1.0) \
		and not SKIDS.should_start_peel(true, false, 0.30, 0.0),
		"oil lowers the real-slip threshold without painting by itself")
	_check(SKIDS.skid_strength(0.0, 0.0, 0.0, 18.0, false, 1.0) > 0.99 \
		and SKIDS.skid_strength(0.0, 0.0, 0.0, 18.0, true, 1.0) == 0.0,
		"a boost launch pulse paints the driven rear tires only")
	_check(SKIDS.skid_strength(0.0, 0.0, 1.0, 12.0, false) == 0.0,
		"oil residue alone does not continuously paint a rolling tire")
	_check(SKIDS.skid_strength(1.0, 1.0, 1.0, 0.5, false) < 0.01,
		"stationary tires cannot paint marks")
	_check(not SKIDS.can_connect(Vector3.ZERO, Vector3(0.02, 0.0, 0.0)),
		"tiny samples do not create dense overlapping geometry")
	_check(SKIDS.can_connect(Vector3.ZERO, Vector3(0.4, 0.0, 0.0)),
		"nearby samples connect into a continuous curve")
	_check(not SKIDS.can_connect(Vector3.ZERO, Vector3(4.0, 0.0, 0.0)),
		"teleports and map transitions cannot draw a bridge")
	var lifted_contact := SKIDS.surface_point(Vector3.ZERO, Vector3.UP)
	_check(lifted_contact.y > 0.184 and lifted_contact.y < 0.22,
		"skid ribbons clear the city road cap without an excessive ground gap")
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
	var start_arrays := trail_mesh.mesh.surface_get_arrays(0)
	var start_colors: PackedColorArray = start_arrays[Mesh.ARRAY_COLOR]
	_check(start_colors[0].a == 0.0 and start_colors[2].a > 0.75,
		"a new skid stroke fades in from a transparent leading cap")
	trails.call("sample_tire", "rear_left", Vector3.ZERO, Vector3.RIGHT,
		0.12, 0.0, 0.0, false)
	trails.call("_process", 0.0)
	var end_arrays := trail_mesh.mesh.surface_get_arrays(0)
	var end_colors: PackedColorArray = end_arrays[Mesh.ARRAY_COLOR]
	_check(end_colors[2].a == 0.0 and end_colors[5].a == 0.0,
		"a completed skid stroke fades out through its trailing cap")
	trails.call("sample_tire", "rear_left", Vector3(0.0, 0.0, -0.4), Vector3.RIGHT,
		0.12, 1.0, 0.0, true)
	trails.call("sample_tire", "rear_left", Vector3(5.0, 0.0, -0.4), Vector3.RIGHT,
		0.12, 1.0, 0.0, true)
	_check(int(trails.call("segment_count")) == 1,
		"a discontinuity resets the emitter without adding geometry")
	trails.free()

	var shader := load("res://fx/tire_skid_trail.gdshader") as Shader
	_check(shader != null and "soft_edge" in shader.code \
		and "fine_rubber_variation" in shader.code and "broken_rubber" not in shader.code \
		and "* 0.62" in shader.code,
		"skid shader keeps a translucent solid ribbon without broken gaps")
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
