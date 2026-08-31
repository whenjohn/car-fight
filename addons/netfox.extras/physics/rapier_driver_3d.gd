extends PhysicsDriver

class_name RapierDriver3D

func _init_physics_space() -> void:
	physics_space = get_viewport().world_3d.space
	PhysicsServer3D.space_set_active(physics_space, false)

func _physics_step(delta: float) -> void:
	RapierPhysicsServer3D.space_step(physics_space, delta)
	RapierPhysicsServer3D.space_flush_queries(physics_space)
	
## Car Fight configures rollback_physics_space=false and restores each
## NetworkRigidBody3D's physics_state through RollbackSynchronizer instead of
## serializing the complete Rapier space.
func _snapshot_space(_tick: int) -> void:
	pass

func _rollback_space(_tick: int) -> void:
	pass
