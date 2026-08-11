extends SceneTree

const JEEP_SPLITTER := preload("res://player/jeep_mesh_splitter.gd")
const JEEP_PRESENTATION := preload("res://player/ground_vehicle_hull.gd")

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
	var full_roll_degrees := rad_to_deg(absf(JEEP_PRESENTATION.chassis_roll_target(1.85, 8.0)))
	if absf(full_roll_degrees - 11.0) > 0.001:
		push_error("JEEP_ROLL_TEST FAIL: expected 11 degrees at medium-speed full steer")
		quit(1)
		return
	if not is_zero_approx(JEEP_PRESENTATION.chassis_roll_target(1.85, 0.0)):
		push_error("JEEP_ROLL_TEST FAIL: stopped chassis must remain level")
		quit(1)
		return
	print("PRESENTATION_ASSET_TEST PASS chassis_surfaces=6 wheels=4 front=2 grid_shader=loaded")
	jeep.free()
	quit()
