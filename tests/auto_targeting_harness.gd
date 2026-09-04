extends "res://Main.gd"
var rays := 0
var setups := 0
var seen_query: PhysicsRayQueryParameters3D
var reused := true

func _combat_dynamic_rids() -> Array[RID]:
	setups += 1
	return []

func _has_target_line_of_sight(_body: RigidBody3D, target: Node3D,
		query: PhysicsRayQueryParameters3D = null) -> bool:
	rays += 1
	if seen_query != null and seen_query != query:
		reused = false
	seen_query = query
	return target.get_meta("visible", true)

