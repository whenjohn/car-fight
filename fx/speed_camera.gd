extends RefCounted
## Client-local camera motion cues. This consumes presented vehicle state only;
## it never feeds movement, physics, rollback, or the wire.

const LEAD_START_SPEED := 5.0
const LEAD_FULL_SPEED := 18.0
const LEAD_DISTANCE := 7.5
const BOOST_LAG_DISTANCE := 5.0
const BOOST_LAG_RECOVERY := 7.5
const TOP_SPEED_SHAKE_START := 16.0
const TOP_SPEED_SHAKE_FULL := 28.0
const TOP_SPEED_SHAKE_DISTANCE := 0.16
const WALL_JOLT_DISTANCE := 0.72
const HIT_JOLT_DISTANCE := 0.95
const DRIFT_JOLT_DISTANCE := 0.30
const JOLT_RECOVERY := 5.8
const FOLLOW_RESPONSE := 5.5

var _offset := Vector3.ZERO
var _boost_lag := 0.0
var _jolt := 0.0
var _elapsed := 0.0
var _was_boosting := false
var _was_drifting := false
var _wall_bumps := 0
var _impact_hits := 0


static func lead_strength(speed: float) -> float:
	return smoothstep(LEAD_START_SPEED, LEAD_FULL_SPEED, maxf(speed, 0.0))


static func vibration_strength(speed: float) -> float:
	return smoothstep(TOP_SPEED_SHAKE_START, TOP_SPEED_SHAKE_FULL, maxf(speed, 0.0))


static func desired_offset(velocity: Vector3, boost_lag: float) -> Vector3:
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var speed := planar.length()
	if speed < 0.05:
		return Vector3.ZERO
	return planar / speed * (lead_strength(speed) * LEAD_DISTANCE - maxf(boost_lag, 0.0))


func reset() -> void:
	_offset = Vector3.ZERO
	_boost_lag = 0.0
	_jolt = 0.0
	_was_boosting = false
	_was_drifting = false
	_wall_bumps = 0
	_impact_hits = 0


func advance(body: RigidBody3D, delta: float) -> Vector3:
	if body == null:
		reset()
		return Vector3.ZERO
	_elapsed += maxf(delta, 0.0)
	var velocity := body.linear_velocity
	velocity.y = 0.0
	var boosting := bool(body.get("boost_active"))
	if boosting and not _was_boosting:
		_boost_lag = BOOST_LAG_DISTANCE
	_was_boosting = boosting
	var drifting := bool(body.get("drift_assist_latched"))
	if drifting and not _was_drifting:
		_jolt = maxf(_jolt, DRIFT_JOLT_DISTANCE)
	_was_drifting = drifting
	var wall_bumps := int(body.get("wall_bump_count"))
	if wall_bumps > _wall_bumps:
		_jolt = maxf(_jolt, WALL_JOLT_DISTANCE)
	_wall_bumps = wall_bumps
	var impact_hits := int(body.get("impact_hit_count"))
	if impact_hits > _impact_hits:
		_jolt = maxf(_jolt, HIT_JOLT_DISTANCE)
	_impact_hits = impact_hits
	_boost_lag = move_toward(_boost_lag, 0.0, BOOST_LAG_RECOVERY * maxf(delta, 0.0))
	var target := desired_offset(velocity, _boost_lag)
	_offset = _offset.lerp(target, 1.0 - exp(-FOLLOW_RESPONSE * maxf(delta, 0.0)))
	var direction := velocity.normalized() if velocity.length() > 0.05 else Vector3.FORWARD
	var side := Vector3.UP.cross(direction).normalized()
	var vibration := vibration_strength(velocity.length()) * TOP_SPEED_SHAKE_DISTANCE
	var shake := side * sin(_elapsed * 47.0) * vibration \
		+ direction * sin(_elapsed * 63.0 + 0.7) * vibration * 0.45
	var jolt_offset := (side * sin(_elapsed * 34.0) - direction * 0.55) * _jolt
	_jolt = move_toward(_jolt, 0.0, JOLT_RECOVERY * maxf(delta, 0.0))
	return _offset + shake + jolt_offset
