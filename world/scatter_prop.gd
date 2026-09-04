extends "res://addons/netfox.extras/physics/network-rigid-body-3d.gd"
## A tiny server-owned rollback body. Its low configured mass lets ordinary
## rigid-body collision response—not a bespoke hit effect—scatter it.

@onready var _rollback_sync: Node = get_node_or_null("RollbackSynchronizer")
@onready var _interpolator: Node = get_node_or_null("TickInterpolator")
var prop_kind := "crate"
var route_id := -100


func _ready() -> void:
	set_multiplayer_authority(1)
	if _rollback_sync != null:
		_rollback_sync.root = self
		_rollback_sync.enable_prediction = true
		_rollback_sync.enable_input_broadcast = true
		_rollback_sync.add_state(self, "physics_state")
		_rollback_sync.process_settings()
	if _interpolator != null:
		_interpolator.root = self
		_interpolator.add_property(self, "global_transform")
	add_to_group("scatter_prop")
