extends SceneTree

const JEEP_SPLITTER := preload("res://player/jeep_mesh_splitter.gd")
const JEEP_PRESENTATION := preload("res://player/ground_vehicle_hull.gd")
const VEHICLE_CONFIG := preload("res://player/vehicle_config.gd")
const COVERAGE_VISUAL := preload("res://combat/coverage_visual.gd")
const TARGET_DUMMY := preload("res://combat/target_dummy.gd")
const BOLT_VISUAL := preload("res://combat/bolt_visual.gd")

func _init() -> void:
	var resource := load("res://assets/ground_vehicle/Jeep.fbx") as PackedScene
	if resource == null:
		push_error("JEEP_ASSET_TEST FAIL: scene did not import")
		quit(1)
		return
	var jeep := resource.instantiate()
	var meshes := jeep.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		push_error("JEEP_ASSET_TEST FAIL: no meshes")
		quit(1)
		return
	var source_mesh := meshes[0] as MeshInstance3D
	var footprint_radius := _visual_footprint_radius(source_mesh.mesh, source_mesh.transform)
	if VEHICLE_CONFIG.COLLISION_RADIUS + 0.001 < footprint_radius:
		push_error("JEEP_COLLIDER_TEST FAIL: radius %.3f does not contain visual footprint %.3f" % [
			VEHICLE_CONFIG.COLLISION_RADIUS, footprint_radius])
		quit(1)
		return
	var split: Dictionary = JEEP_SPLITTER.split(source_mesh.mesh, source_mesh.transform)
	var chassis := split["chassis"] as ArrayMesh
	var wheels: Dictionary = split["wheels"]
	if chassis.get_surface_count() != 6 or wheels.size() != 4:
		push_error("JEEP_SPLIT_TEST FAIL: expected 6 chassis surfaces and 4 wheels")
		quit(1)
		return
	var front_wheels := 0
	for wheel in wheels.values():
		if (wheel["mesh"] as ArrayMesh).get_surface_count() != 2:
			push_error("JEEP_SPLIT_TEST FAIL: each wheel needs tire and hub surfaces")
			quit(1)
			return
		if bool(wheel["front"]):
			front_wheels += 1
	if front_wheels != 2:
		push_error("JEEP_SPLIT_TEST FAIL: expected two steerable front wheels")
		quit(1)
		return
	var grid_shader := load("res://world/grid_ground.gdshader") as Shader
	if grid_shader == null or grid_shader.code.is_empty():
		push_error("GRID_SHADER_TEST FAIL: shader did not load")
		quit(1)
		return
	if "unshaded" in grid_shader.code or "EMISSION" in grid_shader.code:
		push_error("GRID_SHADOW_TEST FAIL: ground shader must receive real lighting and shadows")
		quit(1)
		return
	var cloak_shader := load("res://fx/vehicle_cloak_dissolve.gdshader") as Shader
	var ghost_shader := load("res://fx/vehicle_cloak_ghost.gdshader") as Shader
	if cloak_shader == null or ghost_shader == null:
		push_error("CLOAK_SHADER_TEST FAIL: vehicle cloak shaders did not load")
		quit(1)
		return
	if "vehicle_forward" not in cloak_shader.code or "world_vertex.y - cut_height" in cloak_shader.code:
		push_error("CLOAK_DIRECTION_TEST FAIL: dissolve must use the vehicle's longitudinal axis")
		quit(1)
		return
	if JEEP_PRESENTATION.cloak_cut_position(0.0) <= JEEP_PRESENTATION.cloak_cut_position(1.0):
		push_error("CLOAK_WIPE_TEST FAIL: cloak must cut front-to-back and return back-to-front")
		quit(1)
		return
	var coverage_visual := COVERAGE_VISUAL.new()
	var coverage_material := coverage_visual.call("_material", Color.WHITE) as StandardMaterial3D
	if coverage_material.no_depth_test:
		push_error("COVERAGE_DEPTH_TEST FAIL: cones must not draw through solid geometry")
		quit(1)
		return
	if not COVERAGE_VISUAL.overlay_is_visible(true, false):
		push_error("COVERAGE_EDITOR_VISIBILITY_TEST FAIL: editor must override the drive preference")
		quit(1)
		return
	if COVERAGE_VISUAL.overlay_is_visible(false, false):
		push_error("COVERAGE_DRIVE_VISIBILITY_TEST FAIL: drive preference must still hide cones")
		quit(1)
		return
	var target_dummy := TARGET_DUMMY.new()
	target_dummy.call("setup", 0, true)
	var target_meshes := target_dummy.find_children("*", "MeshInstance3D", true, false)
	var target_mesh := target_meshes[0] as MeshInstance3D if not target_meshes.is_empty() else null
	if target_mesh == null or target_mesh.cast_shadow != \
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		push_error("TARGET_SHADOW_TEST FAIL: stationary targets must not enter the dynamic shadow pass")
		quit(1)
		return
	var bolt_mesh_a := BOLT_VISUAL._bolt_mesh()
	var bolt_mesh_b := BOLT_VISUAL._bolt_mesh()
	var bolt_material_a := BOLT_VISUAL._bolt_material(Color("63d8ff"))
	var bolt_material_b := BOLT_VISUAL._bolt_material(Color("63d8ff"))
	if bolt_mesh_a != bolt_mesh_b or bolt_material_a != bolt_material_b:
		push_error("BOLT_RESOURCE_TEST FAIL: auto-fire bolts must share render resources")
		quit(1)
		return
	var bolt_material := bolt_material_a as StandardMaterial3D
	if bolt_material == null or bolt_material.emission_enabled \
			or bolt_material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
		push_error("BOLT_SHADER_TEST FAIL: bolts must reuse the warmed unshaded shader variant")
		quit(1)
		return
	if bool(ProjectSettings.get_setting(
			"rendering/lights_and_shadows/positional_shadow/atlas_16_bits", true)):
		push_error("SHADOW_DEPTH_TEST FAIL: long-range arena shadows need a 32-bit depth atlas")
		quit(1)
		return
	if int(ProjectSettings.get_setting(
			"rendering/lights_and_shadows/positional_shadow/atlas_size", 4096)) != 2048:
		push_error("SHADOW_ATLAS_TEST FAIL: arena shadow atlas must stay within the 2048 budget")
		quit(1)
		return
	if int(ProjectSettings.get_setting(
			"rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality", 2)) != 0:
		push_error("SHADOW_FILTER_TEST FAIL: compatibility shadows must not use a grain pattern")
		quit(1)
		return
	var full_roll_degrees := rad_to_deg(absf(JEEP_PRESENTATION.chassis_roll_target(1.85, 8.0)))
	if absf(full_roll_degrees - 11.0) > 0.001:
		push_error("JEEP_ROLL_TEST FAIL: expected 11 degrees at medium-speed full steer")
		quit(1)
		return
	if not is_zero_approx(JEEP_PRESENTATION.chassis_roll_target(1.85, 0.0)):
		push_error("JEEP_ROLL_TEST FAIL: stopped chassis must remain level")
		quit(1)
		return
	print("PRESENTATION_ASSET_TEST PASS chassis_surfaces=6 wheels=4 front=2 grid_shader=loaded coverage_depth=enabled shadow_filter=hard shadow_depth=32bit")
	coverage_visual.free()
	target_dummy.free()
	jeep.free()
	quit()

func _visual_footprint_radius(mesh: Mesh, source_transform: Transform3D) -> float:
	var radius := 0.0
	var model_basis := Basis(Vector3.UP, PI).scaled(Vector3.ONE * JEEP_PRESENTATION.JEEP_SCALE)
	var model_offset := Vector3(0.0, 0.065, -0.05)
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var presented := model_basis * (source_transform * vertex) + model_offset
			radius = maxf(radius, Vector2(presented.x, presented.z).length())
	return radius
