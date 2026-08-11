extends SceneTree

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
	var grid_shader := load("res://world/grid_ground.gdshader") as Shader
	if grid_shader == null or grid_shader.code.is_empty():
		push_error("GRID_SHADER_TEST FAIL: shader did not load")
		quit(1)
		return
	print("PRESENTATION_ASSET_TEST PASS jeep_meshes=%d grid_shader=loaded" % meshes.size())
	jeep.free()
	quit()
