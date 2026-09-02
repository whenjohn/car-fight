extends PhysicsDriver

class_name RapierDriver3D

func _init_physics_space() -> void:
	physics_space = get_viewport().world_3d.space
	PhysicsServer3D.space_set_active(physics_space, false)

func _physics_step(delta) -> void:
	RapierPhysicsServer3D.space_step(physics_space, delta)
	RapierPhysicsServer3D.space_flush_queries(physics_space)
	
## Rapier 0.8.39 removed whole-space binary export/import. Car Fight configures
## rollback_physics_space=false and restores each NetworkRigidBody3D's
## physics_state through RollbackSynchronizer instead.
func _snapshot_space(_tick: int) -> void:
	pass

func _rollback_space(_tick) -> void:
	pass
