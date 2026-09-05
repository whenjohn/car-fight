extends RefCounted

## Pure render-only sampling helpers. Storage stays on PlayerBody: this selects from the existing
## tick -> authoritative-position history and is deliberately independent of networking/physics.

const MODE_INTERPOLATE := "interp"
const MODE_EXTRAPOLATE := "extra"
const MODE_HOLD := "hold"

## This opt-in targets ordinary frame pacing only. Keep long-pause recovery on
## the existing engine-delta/rebase path instead of spending seconds of backlog.
static func elapsed_cursor_delta(now_usec: int, previous_usec: int, engine_delta: float) -> float:
	if previous_usec < 0 or now_usec - previous_usec > 250000:
		return engine_delta
	return maxf(0.0, float(now_usec - previous_usec) / 1000000.0)

## Predict a pose from one correlated authoritative sample. Velocities use the
## same units as RigidBody3D (world units/sec and radians/sec). The caller owns
## the age bound so a stalled connection cannot extrapolate forever.
static func predict_pose(position: Vector3, rotation: Quaternion,
		linear_velocity: Vector3, angular_velocity: Vector3,
		lead_seconds: float) -> Transform3D:
	var lead := maxf(0.0, lead_seconds)
	var predicted_rotation := rotation.normalized()
	var angular_speed := angular_velocity.length()
	if angular_speed > 0.0001 and lead > 0.0:
		var delta_rotation := Quaternion(angular_velocity / angular_speed,
			angular_speed * lead)
		predicted_rotation = (delta_rotation * predicted_rotation).normalized()
	return Transform3D(Basis(predicted_rotation), position + linear_velocity * lead)

## Frame-rate-independent visual reconciliation. This smooths packet-to-packet
## target changes without imposing a hard distance leash or changing physics.
static func smooth_pose(current: Transform3D, target: Transform3D,
		delta_seconds: float, position_half_life := 0.045,
		rotation_half_life := 0.060) -> Transform3D:
	if delta_seconds <= 0.0:
		return current
	var position_alpha := 1.0 - pow(0.5,
		delta_seconds / maxf(position_half_life, 0.0001))
	var rotation_alpha := 1.0 - pow(0.5,
		delta_seconds / maxf(rotation_half_life, 0.0001))
	var current_rotation := current.basis.get_rotation_quaternion().normalized()
	var target_rotation := target.basis.get_rotation_quaternion().normalized()
	return Transform3D(Basis(current_rotation.slerp(target_rotation,
		rotation_alpha).normalized()), current.origin.lerp(target.origin, position_alpha))

## Advance a presentation timeline without reversing it during ordinary clock discipline. The synchronized
## network clock is allowed to recalibrate; applying every small correction directly to render_tick produces
## a one-frame forward/back hull pop. Instead, advance at nominal real time and absorb ordinary clock error
## through a damped follower. Epoch discontinuities are handled by the body that owns the history, because
## rebasing also has to invalidate that body's warmup evidence.
static func advance_cursor(current_tick: float, desired_tick: float, delta_seconds: float,
		tickrate: float, correction_ticks_per_second := 3.0,
		correction_time_seconds := 1.0) -> float:
	if delta_seconds <= 0.0 or tickrate <= 0.0:
		return current_tick
	var nominal := delta_seconds * tickrate
	var candidate := current_tick + nominal
	var correction_limit := delta_seconds * maxf(0.0, correction_ticks_per_second)
	var correction_blend := clampf(
		delta_seconds / maxf(correction_time_seconds, delta_seconds), 0.0, 1.0)
	var damped_correction := (desired_tick - candidate) * correction_blend
	var correction := clampf(damped_correction, -correction_limit, correction_limit)
	return maxf(current_tick, candidate + correction)

static func insert_bounded(history: Dictionary, tick: int, value: Variant, newest_tick: int,
		retain_ticks := 64) -> void:
	history[tick] = value # Dictionary gives duplicate replacement and out-of-order insertion for free.
	var cutoff := newest_tick - retain_ticks
	for old_tick in history.keys():
		if int(old_tick) < cutoff:
			history.erase(old_tick)

## Returns {position, mode, left_tick, right_tick}. Extrapolation uses the newest two distinct samples,
## stops at max_extrapolation_ticks, then reports HOLD at the same bounded position.
static func sample(history: Dictionary, render_tick: float, max_extrapolation_ticks: float) -> Dictionary:
	if history.is_empty():
		return {}
	var ticks: Array = history.keys()
	ticks.sort()
	var oldest_tick := int(ticks[0])
	var newest_tick := int(ticks[-1])

	if render_tick < float(oldest_tick):
		return _result(history[oldest_tick], MODE_HOLD, oldest_tick, oldest_tick)

	var left_tick := oldest_tick
	var right_tick := oldest_tick
	for raw_tick in ticks:
		var tick := int(raw_tick)
		if float(tick) <= render_tick:
			left_tick = tick
		if float(tick) >= render_tick:
			right_tick = tick
			break
	if right_tick > left_tick:
		var alpha := (render_tick - float(left_tick)) / float(right_tick - left_tick)
		return _result((history[left_tick] as Vector3).lerp(history[right_tick] as Vector3, alpha),
			MODE_INTERPOLATE, left_tick, right_tick)
	if right_tick == left_tick and is_equal_approx(render_tick, float(left_tick)):
		return _result(history[left_tick], MODE_INTERPOLATE, left_tick, right_tick)
	if render_tick <= float(newest_tick):
		return _result(history[newest_tick], MODE_INTERPOLATE, newest_tick, newest_tick)

	var previous_tick := -1
	for i in range(ticks.size() - 2, -1, -1):
		var candidate := int(ticks[i])
		if candidate < newest_tick:
			previous_tick = candidate
			break
	if previous_tick < 0 or max_extrapolation_ticks <= 0.0:
		return _result(history[newest_tick], MODE_HOLD, newest_tick, newest_tick)
	var velocity := ((history[newest_tick] as Vector3) - (history[previous_tick] as Vector3)) \
		/ float(newest_tick - previous_tick)
	var requested_lead := render_tick - float(newest_tick)
	var bounded_lead := minf(requested_lead, max_extrapolation_ticks)
	var mode := MODE_EXTRAPOLATE if requested_lead <= max_extrapolation_ticks else MODE_HOLD
	return _result((history[newest_tick] as Vector3) + velocity * bounded_lead, mode,
		previous_tick, newest_tick)

## Sample orientation from the exact left/right ticks selected for position. Extrapolated position holds
## the newest authoritative orientation instead of borrowing the body's live basis from another moment.
static func sample_rotation(history: Dictionary, position_sample: Dictionary,
		render_tick: float) -> Quaternion:
	if history.is_empty() or position_sample.is_empty():
		return Quaternion.IDENTITY
	var left_tick := int(position_sample["left_tick"])
	var right_tick := int(position_sample["right_tick"])
	var fallback_tick := int(history.keys().max())
	var left: Quaternion = history.get(left_tick, history[fallback_tick])
	if right_tick <= left_tick or not history.has(right_tick):
		return left.normalized()
	var right: Quaternion = history[right_tick]
	var alpha := clampf((render_tick - float(left_tick)) /
		float(right_tick - left_tick), 0.0, 1.0)
	return left.normalized().slerp(right.normalized(), alpha).normalized()

static func _result(pos: Vector3, mode: String, left_tick: int, right_tick: int) -> Dictionary:
	return {"position": pos, "mode": mode, "left_tick": left_tick, "right_tick": right_tick}
