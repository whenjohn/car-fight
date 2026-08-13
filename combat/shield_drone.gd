extends Node3D
## Stationary shield-test fixture. Main owns targeting and projectile authority;
## this node deliberately has no collider and is never a player weapon target.

# Isolated west clearing: no red targets or arena structures beside it.
const ARENA_POSITION := Vector3(-22.0, 2.35, -8.0)
const MUZZLE_HEIGHT := 0.15
const ARM_TICKS := 60
const FIRE_INTERVAL_TICKS := 120
const BOLT_SPEED := 22.0
const BOLT_COLOR := Color(1.0, 0.30, 0.18)

var _ring: Node3D

func build_presentation() -> void:
	var core := MeshInstance3D.new()
	core.name = "DroneCore"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.62
	core_mesh.height = 1.24
	core_mesh.radial_segments = 16
	core_mesh.rings = 8
	core.mesh = core_mesh
	core.material_override = _material(Color("3c4651"), Color("ff5538"), 1.4)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)

	var eye := MeshInstance3D.new()
	eye.name = "DroneEye"
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.18
	eye_mesh.height = 0.36
	eye.mesh = eye_mesh
	eye.position = Vector3(0.0, 0.0, 0.52)
	eye.material_override = _material(Color("ff6a48"), Color("ff3c24"), 2.8)
	eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(eye)

	var ring := MeshInstance3D.new()
	ring.name = "DroneRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.outer_radius = 0.92
	ring_mesh.inner_radius = 0.82
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 6
	ring.mesh = ring_mesh
	ring.rotation.x = PI * 0.5
	ring.material_override = _material(Color("722f28"), Color("ff5138"), 1.2)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	_ring = ring

func muzzle_position() -> Vector3:
	return global_position + Vector3.UP * MUZZLE_HEIGHT

func aim_at(target: Vector3) -> void:
	var flat_target := Vector3(target.x, global_position.y, target.z)
	if global_position.distance_squared_to(flat_target) > 0.001:
		look_at(flat_target, Vector3.UP, true)

func _process(delta: float) -> void:
	if _ring != null:
		_ring.rotation.z += delta * 0.65

func _material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.42
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material
