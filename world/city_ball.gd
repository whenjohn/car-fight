extends "res://addons/netfox.extras/physics/network-rigid-body-3d.gd"
## One server-owned rollback body that cars can shove around the city.

const RADIUS := 1.15
const MASS := 0.85
const BOUNCE := 0.72
const FRICTION := 0.08
const LINEAR_DAMP := 0.42
const SPAWN_POSITION := Vector3(-8.0, RADIUS + 0.04, 6.0)

@onready var _rollback_sync: Node = get_node_or_null("RollbackSynchronizer")
@onready var _interpolator: Node = get_node_or_null("TickInterpolator")
var pending_impulse := Vector3.ZERO


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
	add_to_group("city_ball")
	add_to_group("tractorable")


func _physics_rollback_tick(_delta: float, _tick: int) -> void:
	if direct_state == null:
		return
	if pending_impulse.length_squared() > 0.0:
		direct_state.apply_central_impulse(pending_impulse)
		pending_impulse = Vector3.ZERO


func apply_external_impulse(impulse: Vector3) -> void:
	pending_impulse += impulse


func tractor_radius() -> float:
	return RADIUS
