extends Node
## Server-owned strike clock. It has no render dependency, so the same delayed
## bomb order and persistent burn behaviour run in headless gates.

const WEAPON := preload("res://combat/area_weapon.gd")
const CALL_DELAY := 1.25
const BURN_DURATION := 3.6

var owner_id := 0
var impacts := PackedVector3Array()
var radius := WEAPON.TAP_RADIUS
var _elapsed := 0.0
var _released := 0

func configure(owner: int, strike_impacts: PackedVector3Array, strike_radius: float) -> void:
	owner_id = owner
	impacts = strike_impacts
	radius = strike_radius

func _ready() -> void:
	NetworkTime.on_tick.connect(_tick)

func _exit_tree() -> void:
	if NetworkTime.on_tick.is_connected(_tick):
		NetworkTime.on_tick.disconnect(_tick)

func _tick(delta: float, tick: int) -> void:
	_elapsed += delta
	while _released < impacts.size() and _elapsed >= _impact_time(_released):
		var main := get_tree().current_scene
		if main != null and main.has_method("resolve_area_bomb"):
			main.call("resolve_area_bomb", owner_id, impacts[_released], radius, tick)
		_released += 1
	if _elapsed >= CALL_DELAY + BURN_DURATION:
		queue_free()

func _impact_time(index: int) -> float:
	return CALL_DELAY * (0.68 + float(index) * 0.06)
