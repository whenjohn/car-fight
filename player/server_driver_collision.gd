extends RefCounted
## Experimental server-driven Jeep collider. This stays isolated from normal
## rollback-controlled players while networking-1 evaluates collision readability.

const RADIUS := 1.05
const HEIGHT := 3.40
const CENTER_Y := -0.50


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
