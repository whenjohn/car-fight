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
	_expect_close(OIL.footprint_strength(MAP_LAYOUT.CITY,
		center + Vector3.UP * 1.5), 1.0, 0.0001, "slick center has full effect")
	_expect_close(OIL.footprint_strength(MAP_LAYOUT.CITY,
		center + Vector3(outside_direction.x, 1.5, outside_direction.y)), 0.0, 0.0001,
		"outside the visible footprint is dry")
	_expect_close(OIL.footprint_strength(MAP_LAYOUT.DRIVING_COURSE,
		center + Vector3.UP * 1.5), 0.0, 0.0001, "another map cannot touch city oil")
	_expect_close(OIL.footprint_strength(MAP_LAYOUT.CITY,
		center + Vector3.UP * 5.0), 0.0, 0.0001, "an elevated road stays above ground oil")

	var amount := OIL.next_amount(0.0, 1.0, true, 18.0, 1.0 / 60.0)
	_check(amount > 0.99, "the first road-speed contact tick applies full oil")
	var edge_amount := OIL.next_amount(0.0, 0.45, true, 18.0, 1.0 / 60.0)
	_expect_close(edge_amount, 0.45, 0.0001,
		"the feathered edge also engages at its exact strength without ramping")
	var residue := OIL.next_amount(amount, 0.0, true, 18.0, 0.25)
	_check(residue > 0.80, "oil residue stays strong immediately after the puddle")
	var long_residue := OIL.next_amount(amount, 0.0, true, 18.0, 1.0)
	_check(long_residue > 0.70,
		"oil remains active for multiple tail swings after a road-speed crossing")
	var extreme_residue := OIL.next_amount(amount, 0.0, true, 18.0, 3.0)
	_check(extreme_residue > 0.20,
		"extreme tuning remains obvious for several seconds after leaving oil")
	var parked := OIL.next_amount(0.0, 1.0, true, 0.0, 1.0)
	_expect_close(parked, 0.0, 0.0001, "a parked car does not rotate on oil")

	var forward := Vector3.FORWARD
	var road_velocity := forward * 18.0
	var dry := OIL.axle_response(road_velocity, forward, -1.0, 0.0, 6.0,
		18.0, 0.0, 0.25)
	var oily := OIL.axle_response(road_velocity, forward, -1.0, 0.0, 6.0,
		18.0, 1.0, 0.25)
	_check(absf(float(oily["yaw_rate"])) > absf(float(dry["yaw_rate"])) * 2.0,
		"turning on oil applies strong front steering torque and breaks the rear loose")
	_check((Vector3(oily["planar_velocity"]) - road_velocity).length() < 0.05,
		"turn-in preserves the old road momentum instead of steering velocity sideways")
	_check(OIL.grip_scale(1.0) < 0.04,
		"full oil keeps most road momentum instead of following the nose")
	var straight := OIL.axle_response(road_velocity, forward, 0.0, 0.0, 6.0,
		18.0, 1.0, 0.25)
	_expect_close(float(straight["yaw_rate"]), 0.0, 0.0001,
		"a settled straight crossing has no scripted side-to-side wobble")
	var rotated_forward := forward.rotated(Vector3.UP, -0.55)
	var sliding := OIL.axle_response(road_velocity, rotated_forward, -1.0, -2.0,
		6.0, 18.0, 1.0, 0.10)
	_check(absf(float(sliding["rear_contact_slip"])) > 6.0,
		"rear-axle contact velocity detects the tail moving across the road momentum")
	_check(absf(Vector3(sliding["planar_velocity"]).dot(
		rotated_forward.cross(Vector3.UP).normalized())) > 5.0,
		"weak rear grip sustains a major sideways slide")
	var countersteer := OIL.axle_response(road_velocity, rotated_forward, 1.0, -2.0,
		6.0, 18.0, 1.0, 0.10)
	_check(float(countersteer["yaw_rate"]) > -2.0 \
		and float(countersteer["yaw_rate"]) < 0.0,
		"countersteer fights existing tail momentum instead of instantly reversing it")
	var default_tuning := OIL.tuning_snapshot()
	_check(OIL.set_tuning_value("duration", 8.0) \
		and OIL.set_tuning_value("min_grip_scale", 0.15),
		"live menu values are accepted by the shared oil model")
	_expect_close(OIL.next_amount(1.0, 0.0, true, 18.0, 1.0), 0.875, 0.0001,
		"edited duration immediately controls residue release")
	_expect_close(OIL.grip_scale(1.0), 0.15, 0.0001,
		"edited road grip immediately controls full-oil traction")
	_check(not OIL.set_tuning_value("not_an_oil_setting", 1.0),
		"unknown network tuning keys are rejected")
	_check(not OIL.set_tuning_value("duration", {"bad": "type"}),
		"invalid network tuning value types are rejected")
	OIL.apply_tuning_snapshot(default_tuning)
	_expect_close(OIL.duration, OIL.DEFAULT_DURATION, 0.0001,
		"tests restore the extreme defaults after live tuning")

	var main_source := FileAccess.get_file_as_string("res://Main.gd")
	var body_source := FileAccess.get_file_as_string("res://player/player_body.gd")
	var visual_source := FileAccess.get_file_as_string("res://world/oil_slicks.gd")
	var shader_source := FileAccess.get_file_as_string("res://fx/oil_slick_decal.gdshader")
	_check("OIL_SLICKS_SCRIPT" in main_source,
		"the city builds the presentation-only decals")
	_check("oil_slick_amount" in body_source \
		and "_sync.add_state(self, \"oil_slick_amount\")" in body_source,
		"the per-car residue participates in rollback")
	_check("OIL_SLICK.axle_response" in body_source \
		and "oil_fishtail_phase" not in body_source,
		"the handling no longer injects a scripted alternating yaw phase")
	_check("_build_oil_tuning_menu" in main_source \
		and "prefer_global_menu = true" in main_source \
		and "_request_oil_tuning_change.rpc_id(1" in main_source \
		and "_apply_oil_tuning_snapshot.rpc" in main_source,
		"the native system menu edits server-synchronized oil tuning")
	_check("user://oil_slick_tuning.cfg" in main_source \
		and "_load_persisted_oil_tuning()" in main_source \
		and "_save_persisted_oil_tuning()" in main_source \
		and "_request_oil_tuning_snapshot.rpc_id(1" in main_source,
		"native oil edits autosave and reclaim authority after reconnecting")
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
