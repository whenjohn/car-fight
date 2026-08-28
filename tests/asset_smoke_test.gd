extends SceneTree

const JEEP_SPLITTER := preload("res://player/jeep_mesh_splitter.gd")
const JEEP_PRESENTATION := preload("res://player/ground_vehicle_hull.gd")
const DRIFT_GUIDE := preload("res://player/drift_guide.gd")
const VEHICLE_CONFIG := preload("res://player/vehicle_config.gd")
const SERVER_DRIVER_COLLISION := preload("res://player/server_driver_collision.gd")
const REMOTE_COLLISION_PHASE := preload("res://player/remote_collision_phase.gd")
const COVERAGE_VISUAL := preload("res://combat/coverage_visual.gd")
const TARGET_DUMMY := preload("res://combat/target_dummy.gd")
const BOLT_VISUAL := preload("res://combat/bolt_visual.gd")
const SHIELD_VISUAL := preload("res://fx/vehicle_shield.gd")
const SHIELD_DRONE := preload("res://combat/shield_drone.gd")
const INPUT_FOCUS_POLICY := preload("res://player/input_focus_policy.gd")
const HOMING_VISUAL := preload("res://combat/homing_missile_visual.gd")
const RC_ORB_VISUAL := preload("res://combat/rc_orb_visual.gd")
const PLAYER_BODY := preload("res://player/player_body.gd")

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
	var driver_collision := CollisionShape3D.new()
	SERVER_DRIVER_COLLISION.configure(driver_collision)
	var driver_capsule := driver_collision.shape as CapsuleShape3D
	var capsule_axis := driver_collision.basis * Vector3.UP
	if not VEHICLE_CONFIG.DEFAULT_CAPSULE_ENABLED:
		push_error("PLAYER_COLLIDER_TEST FAIL: ordinary gameplay must default to the accepted capsule")
		quit(1)
		return
	if driver_capsule == null \
			or absf(absf(capsule_axis.normalized().dot(Vector3.FORWARD)) - 1.0) > 0.001:
		push_error("SERVER_DRIVER_COLLIDER_TEST FAIL: capsule must run Jeep front-to-rear")
		quit(1)
		return
	if absf(float(driver_capsule.radius) - VEHICLE_CONFIG.CAPSULE_RADIUS) > 0.001 \
			or absf(float(driver_capsule.height) - VEHICLE_CONFIG.CAPSULE_HEIGHT) > 0.001:
		push_error("PLAYER_COLLIDER_TEST FAIL: gameplay capsule dimensions changed")
		quit(1)
		return
	if absf(driver_collision.position.y - SERVER_DRIVER_COLLISION.RADIUS \
			+ VEHICLE_CONFIG.COLLISION_RADIUS) > 0.001:
		push_error("SERVER_DRIVER_COLLIDER_TEST FAIL: capsule bottom must retain ground height")
		quit(1)
		return
	if SERVER_DRIVER_COLLISION.RADIUS < 0.87 \
			or SERVER_DRIVER_COLLISION.HEIGHT * 0.5 < 1.30:
		push_error("SERVER_DRIVER_COLLIDER_TEST FAIL: capsule must cover the Jeep footprint")
		quit(1)
		return
	var capsule_excess := _capsule_footprint_excess(source_mesh.mesh, source_mesh.transform,
		SERVER_DRIVER_COLLISION.RADIUS, SERVER_DRIVER_COLLISION.HEIGHT)
	if capsule_excess > 0.001:
		push_error("SERVER_DRIVER_COLLIDER_TEST FAIL: Jeep corners exceed capsule by %.3f" \
			% capsule_excess)
		quit(1)
		return
	driver_collision.free()
	var debug_body := PLAYER_BODY.new()
	var debug_collision := CollisionShape3D.new()
	debug_collision.name = "Collision"
	SERVER_DRIVER_COLLISION.configure(debug_collision)
	debug_body.add_child(debug_collision)
	debug_body.call("set_gameplay_collision_debug_visible", true)
	var gameplay_debug := debug_body.get_node_or_null("GameplayCollisionDebug") \
		as MeshInstance3D
	if gameplay_debug == null or not gameplay_debug.visible \
			or not gameplay_debug.mesh is CapsuleMesh \
			or not gameplay_debug.transform.is_equal_approx(debug_collision.transform):
		debug_body.free()
		push_error("PLAYER_COLLIDER_DEBUG_TEST FAIL: menu debug must match the gameplay capsule")
		quit(1)
		return
	debug_body.call("set_gameplay_collision_debug_visible", false)
	if gameplay_debug.visible:
		debug_body.free()
		push_error("PLAYER_COLLIDER_DEBUG_TEST FAIL: menu debug must hide without changing collision")
		quit(1)
		return
	debug_body.free()
	var live_proxy := REMOTE_COLLISION_PHASE.disabled_states(true, false, true)
	var replay_proxy := REMOTE_COLLISION_PHASE.disabled_states(true, true, true)
	if not bool(live_proxy["source"]) or bool(live_proxy["proxy"]) \
			or bool(replay_proxy["source"]) or not bool(replay_proxy["proxy"]):
		push_error("REMOTE_COLLISION_PHASE_TEST FAIL: replay must restore the server body")
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
	for vehicle in JEEP_PRESENTATION.VEHICLES:
		var vehicle_config: Dictionary = vehicle
		var vehicle_scene := vehicle_config["scene"] as PackedScene
		var vehicle_instance := vehicle_scene.instantiate()
		var vehicle_meshes := vehicle_instance.find_children("*", "MeshInstance3D", true, false)
		var vehicle_mesh := vehicle_meshes[0] as MeshInstance3D if not vehicle_meshes.is_empty() else null
		if vehicle_mesh == null:
			push_error("VEHICLE_ASSET_TEST FAIL: %s has no mesh" % vehicle_config["name"])
			quit(1)
			return
		var separate_meshes := bool(vehicle_config.get("separated_meshes", false))
		var vehicle_split: Dictionary = JEEP_SPLITTER.split_separated(vehicle_instance) \
			if separate_meshes else JEEP_SPLITTER.split(vehicle_mesh.mesh, vehicle_mesh.transform)
		var vehicle_wheels: Dictionary = vehicle_split["wheels"]
		if (vehicle_split["chassis"] as ArrayMesh).get_surface_count() < 1 or vehicle_wheels.size() != 4:
			push_error("VEHICLE_SPLIT_TEST FAIL: %s needs a chassis and four wheels" % vehicle_config["name"])
			quit(1)
			return
		var vehicle_front_wheels := 0
		var expected_wheel_surfaces := int(vehicle_config.get("wheel_surfaces", 2))
		for vehicle_wheel in vehicle_wheels.values():
			if (vehicle_wheel["mesh"] as ArrayMesh).get_surface_count() != expected_wheel_surfaces:
				push_error("VEHICLE_SPLIT_TEST FAIL: %s wheel must retain %d surface(s)" % [
					vehicle_config["name"], expected_wheel_surfaces])
				quit(1)
				return
			if bool(vehicle_wheel["front"]):
				vehicle_front_wheels += 1
		if vehicle_front_wheels != 2:
			push_error("VEHICLE_SPLIT_TEST FAIL: %s needs two steerable front wheels" % vehicle_config["name"])
			quit(1)
			return
		var vehicle_footprint := _split_footprint_radius(vehicle_split,
			float(vehicle_config["scale"]))
		if vehicle_footprint > VEHICLE_CONFIG.COLLISION_RADIUS + 0.01:
			push_error("VEHICLE_COLLIDER_TEST FAIL: %s footprint %.3f exceeds collider" % [
				vehicle_config["name"], vehicle_footprint])
			quit(1)
			return
		vehicle_instance.free()
	if JEEP_PRESENTATION.VEHICLES.size() != 6 \
			or str(JEEP_PRESENTATION.VEHICLES[-1]["name"]) != "Humvee M242":
		push_error("HUMVEE_ASSET_TEST FAIL: Humvee M242 must be the sixth vehicle")
		quit(1)
		return
	var humvee_rig := JEEP_PRESENTATION.new()
	var humvee_parent := Node3D.new()
	humvee_parent.add_child(humvee_rig)
	humvee_rig.set("_vehicle_index", JEEP_PRESENTATION.VEHICLES.size() - 1)
	humvee_rig.call("_build_selected_vehicle")
	var humvee_chassis := humvee_rig.get_node_or_null(
		"ChassisLean/ChassisModel/SeparatedChassis") as MeshInstance3D
	var humvee_wheels := humvee_rig.find_children("*Spin", "Node3D", true, false)
	var humvee_material := humvee_chassis.mesh.surface_get_material(0) as StandardMaterial3D \
		if humvee_chassis != null else null
	if humvee_chassis == null or humvee_wheels.size() != 4 \
			or humvee_material == null or humvee_material.albedo_texture == null \
			or humvee_material.albedo_texture.resource_path != \
				"res://assets/ground_vehicle/humvee_m242/texture.png":
		humvee_parent.free()
		push_error("HUMVEE_ASSET_TEST FAIL: rig must retain four wheels and supplied texture")
		quit(1)
		return
	humvee_parent.free()
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
	var occlusion_material := JEEP_PRESENTATION.occlusion_material()
	var xray_pass := occlusion_material.next_pass as BaseMaterial3D
	if occlusion_material.stencil_mode != BaseMaterial3D.STENCIL_MODE_XRAY \
			or xray_pass == null \
			or not xray_pass.albedo_color.is_equal_approx(JEEP_PRESENTATION.OCCLUDED_SILHOUETTE_COLOR):
		push_error("OCCLUDED_SILHOUETTE_TEST FAIL: vehicle overlay must use the cyan stencil X-ray pass")
		quit(1)
		return
	var ground_shader := load("res://world/grid_ground.gdshader") as Shader
	var grass_shader := load("res://fx/interactive_grass.gdshader") as Shader
	if ground_shader == null or grass_shader == null \
			or "stencil_mode write, compare_always, 1" not in ground_shader.code \
			or "stencil_mode write, compare_always, 1" not in grass_shader.code:
		push_error("OCCLUDED_SILHOUETTE_TEST FAIL: floor and grass must mask the X-ray pass")
		quit(1)
		return
	var rc_orb := RC_ORB_VISUAL.new()
	rc_orb.call("_ready")
	if rc_orb.get_child_count() != 4:
		push_error("RC_ORB_ASSET_TEST FAIL: energy orb must retain core, flow, and two satellites")
		quit(1)
		return
	rc_orb.free()
	var shield_shader := load("res://fx/vehicle_shield.gdshader") as Shader
	if shield_shader == null or shield_shader.code.is_empty():
		push_error("SHIELD_SHADER_TEST FAIL: glass shield shader did not load")
		quit(1)
		return
	for required in ["shield_strength", "impact_direction", "impact_age",
			"vertex_ripple", "screen_texture"]:
		if required not in shield_shader.code:
			push_error("SHIELD_SHADER_TEST FAIL: missing %s" % required)
			quit(1)
			return
	var homing_shader := load("res://fx/homing_missile_head.gdshader") as Shader
	if homing_shader == null or "chevron" not in homing_shader.code or "hot_color" not in homing_shader.code:
		push_error("HOMING_SHADER_TEST FAIL: G2 isometric seeker shader did not load")
		quit(1)
		return
	if HOMING_VISUAL == null:
		push_error("HOMING_VISUAL_TEST FAIL: missile presentation did not load")
		quit(1)
		return
	if SHIELD_VISUAL.SHELL_RADIUS <= VEHICLE_CONFIG.CAPSULE_HEIGHT * 0.5:
		push_error("SHIELD_SHELL_TEST FAIL: shield must fully contain the gameplay collider")
		quit(1)
		return
	var shield_visual := SHIELD_VISUAL.new()
	shield_visual.call("_ready")
	var shell := shield_visual.get_node_or_null("GlassShell") as MeshInstance3D
	if shell == null or shell.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		push_error("SHIELD_SHELL_TEST FAIL: glass shell must exist without shadow cost")
		quit(1)
		return
	shield_visual.free()
	if SHIELD_DRONE.FIRE_INTERVAL_TICKS < 120:
		push_error("SHIELD_DRONE_TEST FAIL: fixture must retain its slow firing pace")
		quit(1)
		return
	var drone_range: float = SHIELD_DRONE.BOLT_SPEED * SHIELD_DRONE.BOLT_LIFETIME
	var central_spawn_distance := Vector2(SHIELD_DRONE.ARENA_POSITION.x,
		SHIELD_DRONE.ARENA_POSITION.z).length()
	if drone_range <= central_spawn_distance:
		push_error("SHIELD_DRONE_TEST FAIL: bolts must cross the expanded west clearing")
		quit(1)
		return
	var main_source := FileAccess.get_file_as_string("res://Main.gd")
	if "HOMING_MISSILE_SHADER" not in main_source:
		push_error("SHADER_PREWARM_TEST FAIL: homing pipeline must compile before ENet starts")
		quit(1)
		return
	if "MaxSpeedMarker" not in main_source:
		push_error("CURSOR_SPEED_MARKER_TEST FAIL: local cursor path must show its max-speed point")
		quit(1)
		return
	if "DisplayServer.window_set_title(\"Car Fight — %s\" % _player_name)" not in main_source \
			and "DisplayServer.window_set_title(\"CAR FIGHT — %s — %s\" % [_session_label, _player_name])" not in main_source:
		push_error("CLIENT_WINDOW_TITLE_TEST FAIL: client title must include the session name")
		quit(1)
		return
	if INPUT_FOCUS_POLICY.live_input_allowed(false) \
			or not INPUT_FOCUS_POLICY.live_input_allowed(true):
		push_error("INPUT_FOCUS_TEST FAIL: only the focused window may gather live controls")
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
	var brake_pitch_degrees := rad_to_deg(
		JEEP_PRESENTATION.chassis_brake_pitch_target(1.0, 18.0))
	if absf(brake_pitch_degrees + 18.0) > 0.001:
		push_error("JEEP_BRAKE_PITCH_TEST FAIL: hard braking must pitch the chassis forward")
		quit(1)
		return
	if not is_zero_approx(JEEP_PRESENTATION.chassis_brake_pitch_target(0.70, 18.0)):
		push_error("JEEP_BRAKE_PITCH_TEST FAIL: chassis dive must wait for peak braking")
		quit(1)
		return
	var approaching_peak_pitch := absf(JEEP_PRESENTATION.chassis_brake_pitch_target(0.85, 18.0))
	if approaching_peak_pitch <= 0.0 or approaching_peak_pitch >= deg_to_rad(10.0):
		push_error("JEEP_BRAKE_PITCH_TEST FAIL: chassis dive must build progressively near peak braking")
		quit(1)
		return
	if not is_zero_approx(JEEP_PRESENTATION.chassis_brake_pitch_target(0.0, 18.0)) \
			or not is_zero_approx(JEEP_PRESENTATION.wheel_roll_scale(1.0)) \
			or JEEP_PRESENTATION.wheel_roll_scale(0.0) != 1.0:
		push_error("JEEP_BRAKE_SKID_TEST FAIL: only hard braking may lock wheel presentation")
		quit(1)
		return
	if absf(DRIFT_GUIDE.speed_fraction(9.0) - 0.5) > 0.001 \
			or not is_zero_approx(DRIFT_GUIDE.boost_fraction(9.0)) \
			or DRIFT_GUIDE.boost_fraction(28.0) < 0.999:
		push_error("DRIFT_GUIDE_TEST FAIL: local rings must map road and burst speed continuously")
		quit(1)
		return
	if DRIFT_GUIDE.ZONE_OUTER_RADIUS - DRIFT_GUIDE.ZONE_INNER_RADIUS < 4.0:
		push_error("DRIFT_GUIDE_TEST FAIL: rear drift targets must be cursor areas, not thin bars")
		quit(1)
		return
	print("PRESENTATION_ASSET_TEST PASS chassis_surfaces=6 wheels=4 front=2 grid_shader=loaded coverage_depth=enabled shadow_filter=hard shadow_depth=32bit")
	coverage_visual.free()
	target_dummy.free()
	jeep.free()
	quit()

func _visual_footprint_radius(mesh: Mesh, source_transform: Transform3D,
		scale_amount: float = JEEP_PRESENTATION.JEEP_SCALE) -> float:
	var radius := 0.0
	var model_basis := Basis(Vector3.UP, PI).scaled(Vector3.ONE * scale_amount)
	var model_offset := Vector3(0.0, 0.065, -0.05)
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var presented := model_basis * (source_transform * vertex) + model_offset
			radius = maxf(radius, Vector2(presented.x, presented.z).length())
	return radius


func _split_footprint_radius(split: Dictionary, scale_amount: float) -> float:
	var radius := _mesh_footprint_radius(split["chassis"] as Mesh, Vector3.ZERO, scale_amount)
	for wheel_value in (split["wheels"] as Dictionary).values():
		var wheel := wheel_value as Dictionary
		radius = maxf(radius, _mesh_footprint_radius(wheel["mesh"] as Mesh,
			wheel["center"] as Vector3, scale_amount))
	return radius


func _mesh_footprint_radius(mesh: Mesh, position: Vector3, scale_amount: float) -> float:
	var radius := 0.0
	var model_basis := Basis(Vector3.UP, PI).scaled(Vector3.ONE * scale_amount)
	var model_offset := Vector3(0.0, 0.065, -0.05)
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var presented := model_basis * (vertex + position) + model_offset
			radius = maxf(radius, Vector2(presented.x, presented.z).length())
	return radius


func _capsule_footprint_excess(mesh: Mesh, source_transform: Transform3D,
		radius: float, height: float) -> float:
	var excess := 0.0
	var segment_half := maxf(height * 0.5 - radius, 0.0)
	var model_basis := Basis(Vector3.UP, PI).scaled(
		Vector3.ONE * JEEP_PRESENTATION.JEEP_SCALE)
	var model_offset := Vector3(0.0, 0.065, -0.05)
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var presented := model_basis * (source_transform * vertex) + model_offset
			var cap_z := maxf(absf(presented.z) - segment_half, 0.0)
			var distance := Vector2(presented.x, cap_z).length()
			excess = maxf(excess, distance - radius)
	return excess
