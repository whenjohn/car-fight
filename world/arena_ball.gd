extends "res://addons/netfox.extras/physics/network-rigid-body-3d.gd"
## One server-owned rollback body that cars can shove around the arena.

const RADIUS := 1.15
const MASS := 0.85
const BOUNCE := 0.72
const FRICTION := 0.08
const LINEAR_DAMP := 0.42
const SPAWN_POSITION := Vector3(-8.0, RADIUS + 0.04, 6.0)

@onready var _rollback_sync: Node = $RollbackSynchronizer
@onready var _interpolator: Node = $TickInterpolator


func _ready() -> void:
	# The server owns the physical state. Clients predict the same simple sphere
	# and reconcile through NetworkRigidBody3D.physics_state.
	set_multiplayer_authority(1)
	_rollback_sync.root = self
	_rollback_sync.enable_prediction = true
	# Keep this at netfox's project-wide/default setting, matching g2's prop
	# bodies. The ball has no input properties, so it sends no input traffic.
	_rollback_sync.enable_input_broadcast = true
	_rollback_sync.add_state(self, "physics_state")
	_rollback_sync.process_settings()
	_interpolator.root = self
	_interpolator.add_property(self, "global_transform")
	add_to_group("arena_ball")
