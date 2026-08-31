extends RefCounted
## Sparse city-block lighting study derived from the proven godot-aerial POC.
## Geometry is deliberately quiet so lighting, materials, and the car stay legible.

const HALF_EXTENT := 82.0
const HDRI_PATH := "res://assets/environment/kloofendal_overcast_puresky_2k.hdr"


static func build_geometry(root: Node3D, rendered: bool) -> void:
	_add_static_box(root, "OvercastGroundCollision",
		Vector3(HALF_EXTENT * 2.0, 1.0, HALF_EXTENT * 2.0),
		Vector3(0.0, -0.5, 0.0), Color("8a9188"), false)
	_add_perimeter(root, rendered)
	for building in _buildings():
		_add_static_box(root, str(building["name"]), building["size"],
			building["position"], building["color"], rendered)
	if not rendered:
		return
	_add_surface(root, "OvercastGround", Vector2(HALF_EXTENT * 2.0, HALF_EXTENT * 2.0),
		Vector3(0.0, 0.005, 0.0), Color("858d82"), 0.92)
	_add_surface(root, "NorthSouthRoad", Vector2(18.0, 154.0),
		Vector3(0.0, 0.018, 0.0), Color("3e4345"), 0.48)
	_add_surface(root, "EastWestRoad", Vector2(154.0, 18.0),
		Vector3(0.0, 0.022, 0.0), Color("3e4345"), 0.48)
	for sidewalk in _sidewalks():
		_add_surface(root, str(sidewalk["name"]), sidewalk["size"],
			sidewalk["position"], Color("a3a49d"), 0.86)
	for puddle in _puddles():
		_add_surface(root, str(puddle["name"]), puddle["size"],
			puddle["position"], Color("58646b"), 0.08)


static func build_lighting(root: Node3D) -> SpotLight3D:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "OvercastEnvironment"
	var environment := Environment.new()
	var panorama := load(HDRI_PATH) as Texture2D
	var sky_material := PanoramaSkyMaterial.new()
	sky_material.panorama = panorama
	sky_material.energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 1.0
	environment.ambient_light_energy = 1.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 1.5
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.05
	environment.adjustment_contrast = 1.0
	environment.adjustment_saturation = 1.08
	world_environment.environment = environment
	root.add_child(world_environment)

	# The panorama supplies the broad overcast illumination. This light adds only
	# a subtle warm direction and specular response; Compatibility shadows from a
	# DirectionalLight3D are unreliable on the target Intel/ANGLE path.
	var sun := DirectionalLight3D.new()
	sun.name = "OvercastSun"
	sun.rotation_degrees = Vector3(-68.0, -130.0, 0.0)
	sun.light_color = Color("fff5e8")
	sun.light_energy = 0.34
	sun.light_specular = 0.35
	sun.shadow_enabled = false
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	root.add_child(sun)

	# A broad, low-opacity spotlight retains a stable car contact shadow without
	# reintroducing the dark, high-contrast arena look or Compatibility grain.
	var contact_light := SpotLight3D.new()
	contact_light.name = "OvercastContactShadow"
	contact_light.position = Vector3(-32.0, 40.0, 34.0)
	contact_light.light_color = Color("fff7eb")
	contact_light.light_energy = 0.72
	contact_light.light_specular = 0.25
	contact_light.spot_range = 100.0
	contact_light.spot_angle = 66.0
	contact_light.spot_attenuation = 0.1
	contact_light.shadow_enabled = true
	contact_light.shadow_opacity = 0.34
	contact_light.shadow_bias = 0.12
	contact_light.shadow_normal_bias = 1.25
	contact_light.shadow_blur = 0.0
	contact_light.shadow_reverse_cull_face = true
	root.add_child(contact_light)
	contact_light.look_at_from_position(contact_light.position, Vector3.ZERO, Vector3.UP)
	return contact_light


static func _add_perimeter(root: Node3D, rendered: bool) -> void:
	var thickness := 1.0
	var height := 0.7
	var color := Color("929993")
	_add_static_box(root, "OvercastBoundaryNorth",
		Vector3(HALF_EXTENT * 2.0, height, thickness),
		Vector3(0.0, height * 0.5, -HALF_EXTENT), color, rendered)
	_add_static_box(root, "OvercastBoundarySouth",
		Vector3(HALF_EXTENT * 2.0, height, thickness),
		Vector3(0.0, height * 0.5, HALF_EXTENT), color, rendered)
	_add_static_box(root, "OvercastBoundaryWest",
		Vector3(thickness, height, HALF_EXTENT * 2.0),
		Vector3(-HALF_EXTENT, height * 0.5, 0.0), color, rendered)
	_add_static_box(root, "OvercastBoundaryEast",
		Vector3(thickness, height, HALF_EXTENT * 2.0),
		Vector3(HALF_EXTENT, height * 0.5, 0.0), color, rendered)


static func _buildings() -> Array[Dictionary]:
	return [
		{"name": "OvercastBuildingNW", "size": Vector3(24.0, 15.0, 22.0),
			"position": Vector3(-48.0, 7.5, -48.0), "color": Color("b8b5ad")},
		{"name": "OvercastBuildingNE", "size": Vector3(25.0, 21.0, 20.0),
			"position": Vector3(47.0, 10.5, -49.0), "color": Color("8e9da3")},
		{"name": "OvercastBuildingSW", "size": Vector3(22.0, 12.0, 24.0),
			"position": Vector3(-49.0, 6.0, 48.0), "color": Color("c0bbb0")},
		{"name": "OvercastBuildingSE", "size": Vector3(27.0, 17.0, 22.0),
			"position": Vector3(47.0, 8.5, 49.0), "color": Color("9ca5a5")},
	]


static func _sidewalks() -> Array[Dictionary]:
	return [
		{"name": "SidewalkWest", "size": Vector2(2.0, 154.0),
			"position": Vector3(-10.0, 0.03, 0.0)},
		{"name": "SidewalkEast", "size": Vector2(2.0, 154.0),
			"position": Vector3(10.0, 0.03, 0.0)},
		{"name": "SidewalkNorth", "size": Vector2(154.0, 2.0),
			"position": Vector3(0.0, 0.035, -10.0)},
		{"name": "SidewalkSouth", "size": Vector2(154.0, 2.0),
			"position": Vector3(0.0, 0.035, 10.0)},
	]


static func _puddles() -> Array[Dictionary]:
	return [
		{"name": "PuddleNorth", "size": Vector2(5.0, 2.2),
			"position": Vector3(-4.5, 0.042, -25.0)},
		{"name": "PuddleEast", "size": Vector2(3.0, 6.0),
			"position": Vector3(27.0, 0.044, 4.0)},
		{"name": "PuddleSouth", "size": Vector2(6.5, 2.5),
			"position": Vector3(4.0, 0.046, 31.0)},
	]


static func _add_static_box(root: Node3D, node_name: String, size: Vector3,
		position: Vector3, color: Color, rendered: bool) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	if rendered:
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_instance.mesh = mesh
		mesh_instance.material_override = _material(color, 0.82)
		body.add_child(mesh_instance)
	root.add_child(body)


static func _add_surface(root: Node3D, node_name: String, size: Vector2,
		position: Vector3, color: Color, roughness: float) -> void:
	var surface := MeshInstance3D.new()
	surface.name = node_name
	var plane := PlaneMesh.new()
	plane.size = size
	surface.mesh = plane
	surface.position = position
	surface.material_override = _material(color, roughness)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(surface)


static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	return material
