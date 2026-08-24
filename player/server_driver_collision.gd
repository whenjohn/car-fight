extends RefCounted
## Shared horizontal Jeep capsule, first accepted by the Networking-1 harness.

const VEHICLE_CONFIG := preload("res://player/vehicle_config.gd")
const RADIUS := VEHICLE_CONFIG.CAPSULE_RADIUS
const HEIGHT := VEHICLE_CONFIG.CAPSULE_HEIGHT
const CENTER_Y := VEHICLE_CONFIG.CAPSULE_CENTER_Y


static func configure(collision: CollisionShape3D) -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	collision.shape = capsule
	# Godot capsules are vertical on local Y. Rotate that axis onto the Jeep's
	# longitudinal Z axis; the capsule is symmetric front-to-rear.
	collision.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
		Vector3(0.0, CENTER_Y, 0.0))


static func debug_mesh(shape: CapsuleShape3D) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = shape.radius
	mesh.height = shape.height
	mesh.radial_segments = 24
	mesh.rings = 8
	return mesh
