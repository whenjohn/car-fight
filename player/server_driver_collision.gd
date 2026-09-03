extends RefCounted
## Shared horizontal Jeep capsule, first accepted by the Networking-1 harness.

const VEHICLE_CONFIG := preload("res://player/vehicle_config.gd")
const RADIUS := VEHICLE_CONFIG.CAPSULE_RADIUS
const HEIGHT := VEHICLE_CONFIG.CAPSULE_HEIGHT
const CENTER_Y := VEHICLE_CONFIG.CAPSULE_CENTER_Y


static func scaled_dimensions(scale: float) -> Dictionary:
	var safe_scale := clampf(scale, 1.0, 5.0) if is_finite(scale) else 1.0
	var scaled_radius := RADIUS * safe_scale
	return {
		"radius": scaled_radius,
		"height": HEIGHT * safe_scale,
		# Grow upward while preserving the accepted body's road clearance.
		"center_y": CENTER_Y + RADIUS * (safe_scale - 1.0),
	}


static func configure(collision: CollisionShape3D, scale := 1.0) -> void:
	var dimensions := scaled_dimensions(float(scale))
	var capsule := CapsuleShape3D.new()
	capsule.radius = float(dimensions["radius"])
	capsule.height = float(dimensions["height"])
	collision.shape = capsule
	# Godot capsules are vertical on local Y. Rotate that axis onto the Jeep's
	# longitudinal Z axis; the capsule is symmetric front-to-rear.
	collision.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
		Vector3(0.0, float(dimensions["center_y"]), 0.0))


static func debug_mesh(shape: CapsuleShape3D) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = shape.radius
	mesh.height = shape.height
	mesh.radial_segments = 24
	mesh.rings = 8
	return mesh
