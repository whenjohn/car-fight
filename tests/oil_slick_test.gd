extends SceneTree

const OIL := preload("res://world/oil_slick.gd")
const OIL_VISUAL := preload("res://world/oil_slicks.gd")
const MAP_LAYOUT := preload("res://world/map_layout.gd")

var _failures := 0


func _init() -> void:
	var slicks := OIL.slicks()
	_check(slicks.size() == 3, "the first world pass has three fixed slicks")
	var names := {}
	for slick in slicks:
		var name := str(slick["name"])
		_check(not names.has(name), "slick names are unique")
		names[name] = true
		var position: Vector3 = slick["position"]
		_check(position.length() > 12.0, "slicks stay clear of the four center spawns")

	var center: Vector3 = slicks[0]["position"]
	var first_stretch: Vector2 = slicks[0]["stretch"]
	var first_yaw := float(slicks[0]["yaw"])
	var outside_direction := Vector2(1.0, 0.0).rotated(first_yaw) \
		* (OIL.RADIUS * first_stretch.x + 0.1)
	_expect_close(OIL.footprint_strength(MAP_LAYOUT.ARENA,
		center + Vector3.UP * 1.5), 1.0, 0.0001, "slick center has full effect")
	_expect_close(OIL.footprint_strength(MAP_LAYOUT.ARENA,
		center + Vector3(outside_direction.x, 1.5, outside_direction.y)), 0.0, 0.0001,
		"outside the visible footprint is dry")
	_expect_close(OIL.footprint_strength(MAP_LAYOUT.DRIVING_COURSE,
		center + Vector3.UP * 1.5), 0.0, 0.0001, "another map cannot touch arena oil")
	_expect_close(OIL.footprint_strength(MAP_LAYOUT.ARENA,
		center + Vector3.UP * 5.0), 0.0, 0.0001, "an elevated road stays above ground oil")

	var amount := 0.0
	for step in range(8):
		amount = OIL.next_amount(amount, 1.0, true, 18.0, 1.0 / 60.0)
	_check(amount > 0.99, "road-speed contact engages oil quickly")
	var residue := OIL.next_amount(amount, 0.0, true, 18.0, 0.25)
	_check(residue > 0.60, "oil residue survives long enough for a fishtail")
	var parked := OIL.next_amount(0.0, 1.0, true, 0.0, 1.0)
	_expect_close(parked, 0.0, 0.0001, "a parked car does not rotate on oil")

	var dry := OIL.steering_response(-1.0, -0.5, 6.0, deg_to_rad(-75.0), 18.0, 0.0)
	var oily := OIL.steering_response(-1.0, -0.5, 6.0, deg_to_rad(-75.0), 18.0,
		1.0, PI * 1.5)
	_check(absf(float(oily["yaw_rate"])) > absf(float(dry["yaw_rate"])) * 2.8,
		"a committed oil turn materially over-rotates")
	_check(float(oily["yaw_acceleration"]) > float(dry["yaw_acceleration"]),
		"the visible fishtail builds quickly enough to read during one crossing")
	_check(OIL.grip_scale(1.0) < 0.25,
		"full oil keeps most road momentum instead of following the nose")
	var phase := OIL.next_fishtail_phase(0.0, 1.0, 18.0, 0.15)
	var straight := OIL.steering_response(0.0, 0.0, 6.0, 0.0, 18.0, 1.0, phase)
	_check(absf(float(straight["yaw_rate"])) > 1.4,
		"a straight road-speed crossing produces an unmistakable deterministic veer")
	var opposite := OIL.steering_response(0.0, 0.0, 6.0, 0.0, 18.0, 1.0,
		phase + PI)
	_check(signf(float(straight["yaw_rate"])) != signf(float(opposite["yaw_rate"])),
		"the next phase swings the rear back instead of applying a constant pull")

	var main_source := FileAccess.get_file_as_string("res://Main.gd")
	var body_source := FileAccess.get_file_as_string("res://player/player_body.gd")
	var visual_source := FileAccess.get_file_as_string("res://world/oil_slicks.gd")
	var shader_source := FileAccess.get_file_as_string("res://fx/oil_slick_decal.gdshader")
	_check("OIL_SLICKS_SCRIPT" in main_source,
		"the arena builds the presentation-only decals")
	_check("oil_slick_amount" in body_source \
		and "_sync.add_state(self, \"oil_slick_amount\")" in body_source \
		and "_sync.add_state(self, \"oil_fishtail_phase\")" in body_source,
		"the per-car residue and fishtail phase participate in rollback")
	_check("Area3D" not in visual_source and "CollisionShape3D" not in visual_source,
		"oil decals never add trigger or collision bodies")
	_check("METALLIC" in shader_source and "stencil_mode write" in shader_source,
		"the dark puddle retains an oily sheen and masks vehicle X-ray")
	var visual := Node3D.new()
	visual.set_script(OIL_VISUAL)
	visual.call("_ready")
	_check(visual.get_child_count() == slicks.size(),
		"every gameplay footprint has exactly one ground decal")
	for child in visual.get_children():
		var mesh := child as MeshInstance3D
		_check(mesh != null and mesh.material_override is ShaderMaterial,
			"each oil decal builds a shader-backed plane")
	visual.free()

	if _failures == 0:
		print("OIL_SLICK_TEST PASS")
		quit()
	else:
		push_error("OIL_SLICK_TEST FAIL failures=%d" % _failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error(label)


func _expect_close(actual: float, expected: float, tolerance: float, label: String) -> void:
	if absf(actual - expected) > tolerance:
		_failures += 1
		push_error("%s: expected %.6f, got %.6f" % [label, expected, actual])
