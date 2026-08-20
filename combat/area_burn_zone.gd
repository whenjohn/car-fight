extends Node3D
## Lightweight event-driven hazard: no rollback body/history per pool.

var owner_id := 0
var radius := 1.64
var lifetime := 3.6
var _age := 0.0
var _damage_clock := 0.0

func configure(owner: int, centre: Vector3, zone_radius: float) -> void:
	owner_id = owner
	global_position = centre
	radius = zone_radius

func _ready() -> void:
	NetworkTime.on_tick.connect(_tick)

func _exit_tree() -> void:
	if NetworkTime.on_tick.is_connected(_tick):
		NetworkTime.on_tick.disconnect(_tick)

func _tick(delta: float, tick: int) -> void:
	_age += delta
	_damage_clock += delta
	if _damage_clock >= 0.5:
		_damage_clock = 0.0
		var main := get_tree().current_scene
		if main != null and main.has_method("apply_area_burn"):
			main.call("apply_area_burn", owner_id, global_position, radius, tick)
	if _age >= lifetime:
		queue_free()
