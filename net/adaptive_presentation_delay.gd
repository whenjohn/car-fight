extends RefCounted

## Pure client-local estimator for adaptive remote-presentation delay. Callers
## provide timestamps and normalized observations so captured runs replay
## deterministically without touching networking, clocks, or physics.

const STATE_WARMUP := "warmup"
const STATE_STEADY := "steady"
const STATE_PRESSURE := "pressure"
const STATE_GROWING := "growing"
const STATE_RECOVERY_WAIT := "recovery_wait"
const STATE_SATURATED := "saturated"

const PROFILE_VERSION := "car-fight-apd-v1"
const WINDOW_MSEC := 3000
const WINDOW_SAMPLE_CAP := 180
const MIN_BATCH_SAMPLES := 6
const EPOCH_WARMUP_MSEC := 8000
const ARRIVAL_WARNING_P95_MSEC := 12.0
const HEADROOM_CONFIRM_MSEC := 12.0
const EXTRAPOLATE_CONFIRM_FRACTION := 0.20
const CRITICAL_HOLD_MSEC := 50.0
const PRESSURE_CONFIRM_MSEC := 100.0
const UPWARD_DWELL_MSEC := 5000.0
const RECOVERY_HEALTHY_MSEC := 20000.0


static func configure(state: Dictionary, minimum_msec: float, maximum_msec: float,
		tickrate: float) -> void:
	state.clear()
	state["minimum_msec"] = maxf(0.0, minimum_msec)
	state["maximum_msec"] = maxf(float(state["minimum_msec"]), maximum_msec)
	state["tickrate"] = maxf(1.0, tickrate)
	state["tiers"] = _build_tiers(float(state["minimum_msec"]),
		float(state["maximum_msec"]))
	reset_epoch(state, 0)


static func reset_epoch(state: Dictionary, now_msec: int) -> void:
	state["target_msec"] = float(state.get("minimum_msec", 75.0))
	state["controller_state"] = STATE_WARMUP
	state["last_sequence"] = -1
	state["last_tick"] = -1
	state["last_arrival_msec"] = -1
	state["batch_samples"] = 0
	state["epoch_first_batch_msec"] = -1
	state["epoch_warmup_complete"] = false
	state["sequence_gaps"] = 0
	state["recent_gap_samples"] = []
	state["recent_sequence_gaps"] = 0
	state["variation_samples"] = []
	state["variation_p50_msec"] = 0.0
	state["variation_p95_msec"] = 0.0
	state["variation_max_msec"] = 0.0
	state["hitch_contaminated_samples"] = 0
	state["last_hitch_contaminated_msec"] = -1
	state["pressure_age_msec"] = 0.0
	state["healthy_age_msec"] = 0.0
	state["last_raise_msec"] = now_msec
	state["pressure_reason"] = "warmup"
	state["headroom_min_msec"] = 0.0
	state["headroom_median_msec"] = 0.0
	state["headroom_p10_msec"] = 0.0
	state["cursor_spread_ticks"] = 0.0
	state["effective_msec"] = float(state["target_msec"])
	state["eligible_bodies"] = 0
	state["warming_bodies"] = 0
	state["interp_fraction"] = 0.0
	state["extrapolate_fraction"] = 0.0
	state["hold_fraction"] = 0.0
	state["max_consecutive_hold_msec"] = 0.0
	state["hold_runs"] = {}


static func observe_batch(state: Dictionary, sequence: int, tick: int,
		arrival_msec: int, hitch_contaminated: bool) -> void:
	if int(state.get("epoch_first_batch_msec", -1)) < 0:
		state["epoch_first_batch_msec"] = arrival_msec
	var previous_sequence := int(state.get("last_sequence", -1))
	var previous_tick := int(state.get("last_tick", -1))
	var previous_arrival := int(state.get("last_arrival_msec", -1))
	if previous_sequence >= 0 and sequence > previous_sequence + 1:
		var gap_count := sequence - previous_sequence - 1
		state["sequence_gaps"] = int(state.get("sequence_gaps", 0)) + gap_count
		var gaps: Array = state["recent_gap_samples"]
		gaps.append({"at_msec": arrival_msec, "count": gap_count})
	_prune_gaps(state, arrival_msec)
	if previous_tick >= 0 and previous_arrival >= 0 and tick > previous_tick:
		var arrival_gap := float(arrival_msec - previous_arrival)
		var source_gap := float(tick - previous_tick) * 1000.0 \
			/ float(state.get("tickrate", 60.0))
		if hitch_contaminated:
			state["hitch_contaminated_samples"] = int(
				state.get("hitch_contaminated_samples", 0)) + 1
			state["last_hitch_contaminated_msec"] = arrival_msec
		else:
			var samples: Array = state["variation_samples"]
			samples.append({"at_msec": arrival_msec,
				"value_msec": maxf(0.0, arrival_gap - source_gap)})
			_prune_variations(samples, arrival_msec)
			_update_variation_stats(state)
	state["last_sequence"] = sequence
	state["last_tick"] = tick
	state["last_arrival_msec"] = arrival_msec
	state["batch_samples"] = int(state.get("batch_samples", 0)) + 1


static func observe_frame(state: Dictionary, now_msec: int, delta_msec: float,
		body_samples: Array) -> void:
	var eligible: Array = []
	var warming := 0
	for sample in body_samples:
		if bool(sample.get("eligible", false)):
			eligible.append(sample)
		elif bool(sample.get("warming", false)):
			warming += 1
	state["eligible_bodies"] = eligible.size()
	state["warming_bodies"] = warming

	var headrooms: Array[float] = []
	var effective_delays: Array[float] = []
	var render_ticks: Array[float] = []
	var interp_count := 0
	var extra_count := 0
	var hold_count := 0
	var hold_runs: Dictionary = state["hold_runs"]
	var live_ids := {}
	var max_hold_run := 0.0
	for sample in eligible:
		var id := str(sample.get("id", ""))
		live_ids[id] = true
		headrooms.append(float(sample.get("headroom_msec", 0.0)))
		effective_delays.append(float(sample.get("effective_msec", state["target_msec"])))
		render_ticks.append(float(sample.get("render_tick", 0.0)))
		var mode := str(sample.get("mode", ""))
		interp_count += 1 if mode == "interp" else 0
		extra_count += 1 if mode == "extra" else 0
		hold_count += 1 if mode == "hold" else 0
		var run := float(hold_runs.get(id, 0.0))
		run = run + delta_msec if mode == "hold" else 0.0
		hold_runs[id] = run
		max_hold_run = maxf(max_hold_run, run)
	for id in hold_runs.keys():
		if not live_ids.has(id):
			hold_runs.erase(id)

	if not eligible.is_empty():
		headrooms.sort()
		effective_delays.sort()
		render_ticks.sort()
		state["headroom_min_msec"] = headrooms[0]
		state["headroom_p10_msec"] = _percentile_sorted(headrooms, 0.10)
		state["headroom_median_msec"] = _percentile_sorted(headrooms, 0.50)
		state["effective_msec"] = _percentile_sorted(effective_delays, 0.50)
		state["cursor_spread_ticks"] = render_ticks[-1] - render_ticks[0]
		var count := float(eligible.size())
		state["interp_fraction"] = float(interp_count) / count
		state["extrapolate_fraction"] = float(extra_count) / count
		state["hold_fraction"] = float(hold_count) / count
	else:
		state["interp_fraction"] = 0.0
		state["extrapolate_fraction"] = 0.0
		state["hold_fraction"] = 0.0
		state["cursor_spread_ticks"] = 0.0
	state["max_consecutive_hold_msec"] = max_hold_run
	_update_target(state, now_msec, delta_msec)


static func target_msec(state: Dictionary) -> float:
	return float(state.get("target_msec", state.get("minimum_msec", 75.0)))


static func snapshot(state: Dictionary) -> Dictionary:
	return state.duplicate(true)


static func _update_target(state: Dictionary, now_msec: int, delta_msec: float) -> void:
	if not bool(state.get("epoch_warmup_complete", false)):
		var first_batch := int(state.get("epoch_first_batch_msec", -1))
		if first_batch < 0 or now_msec - first_batch < EPOCH_WARMUP_MSEC:
			state["controller_state"] = STATE_WARMUP
			state["pressure_reason"] = "epoch_warmup"
			return
		state["epoch_warmup_complete"] = true
		state["variation_samples"] = []
		state["variation_p50_msec"] = 0.0
		state["variation_p95_msec"] = 0.0
		state["variation_max_msec"] = 0.0
		state["recent_gap_samples"] = []
		state["recent_sequence_gaps"] = 0
		state["batch_samples"] = 0
		state["last_raise_msec"] = now_msec
		state["controller_state"] = STATE_WARMUP
		state["pressure_reason"] = "post_epoch_samples"
		return
	if int(state.get("batch_samples", 0)) < MIN_BATCH_SAMPLES:
		state["controller_state"] = STATE_WARMUP
		state["pressure_reason"] = "batch_warmup"
		return

	var has_bodies := int(state.get("eligible_bodies", 0)) > 0
	var warning := float(state.get("variation_p95_msec", 0.0)) \
		>= ARRIVAL_WARNING_P95_MSEC or int(state.get("recent_sequence_gaps", 0)) > 0
	var low_headroom := has_bodies and float(state.get("headroom_min_msec", INF)) \
		<= HEADROOM_CONFIRM_MSEC
	var extrapolating := has_bodies and float(state.get("extrapolate_fraction", 0.0)) \
		>= EXTRAPOLATE_CONFIRM_FRACTION
	var critical := has_bodies and float(state.get("max_consecutive_hold_msec", 0.0)) \
		>= CRITICAL_HOLD_MSEC
	var pressured := critical or (warning and (low_headroom or extrapolating))

	if pressured:
		state["pressure_age_msec"] = float(state.get("pressure_age_msec", 0.0)) + delta_msec
		state["healthy_age_msec"] = 0.0
		state["pressure_reason"] = "hold" if critical else (
			"arrival+headroom+extra" if low_headroom and extrapolating else (
			"arrival+headroom" if low_headroom else "arrival+extra"))
	else:
		state["pressure_age_msec"] = 0.0
		var clean_transport := float(state.get("variation_p95_msec", 0.0)) \
			< ARRIVAL_WARNING_P95_MSEC and int(state.get("recent_sequence_gaps", 0)) == 0
		var last_hitch := int(state.get("last_hitch_contaminated_msec", -1))
		var hitch_quiet := last_hitch < 0 or now_msec - last_hitch > 100
		if clean_transport and hitch_quiet and (not has_bodies or (
				float(state.get("extrapolate_fraction", 0.0)) == 0.0
				and float(state.get("hold_fraction", 0.0)) == 0.0)):
			state["healthy_age_msec"] = float(state.get("healthy_age_msec", 0.0)) + delta_msec
		else:
			state["healthy_age_msec"] = 0.0

	var current := target_msec(state)
	var maximum := float(state.get("maximum_msec", current))
	if pressured and (critical or float(state["pressure_age_msec"]) >= PRESSURE_CONFIRM_MSEC):
		if current < maximum and now_msec - int(state.get("last_raise_msec", 0)) \
				>= int(UPWARD_DWELL_MSEC):
			state["target_msec"] = _next_higher_tier(state, current)
			state["last_raise_msec"] = now_msec
			state["pressure_age_msec"] = 0.0
			state["controller_state"] = STATE_GROWING
			return
		state["controller_state"] = STATE_GROWING if current >= maximum \
			and float(state.get("effective_msec", current)) < current - 2.0 \
			else (STATE_SATURATED if current >= maximum else STATE_PRESSURE)
		return

	var minimum := float(state.get("minimum_msec", current))
	if current > minimum:
		if float(state.get("effective_msec", current)) < current - 2.0:
			state["controller_state"] = STATE_GROWING
			state["pressure_reason"] = "actuator_slew"
		elif float(state.get("healthy_age_msec", 0.0)) >= RECOVERY_HEALTHY_MSEC:
			state["target_msec"] = _next_lower_tier(state, current)
			state["healthy_age_msec"] = 0.0
			state["controller_state"] = STATE_STEADY
			state["pressure_reason"] = "healthy_release"
		else:
			state["controller_state"] = STATE_RECOVERY_WAIT
			state["pressure_reason"] = "recovery_dwell"
	else:
		state["controller_state"] = STATE_STEADY
		state["pressure_reason"] = "healthy"


static func _build_tiers(minimum_msec: float, maximum_msec: float) -> Array[float]:
	var tiers: Array[float] = [minimum_msec]
	for candidate in [100.0, 125.0, 150.0]:
		if candidate > minimum_msec and candidate < maximum_msec:
			tiers.append(candidate)
	if maximum_msec > minimum_msec:
		tiers.append(maximum_msec)
	return tiers


static func _next_higher_tier(state: Dictionary, current: float) -> float:
	for tier in state["tiers"]:
		if float(tier) > current:
			return float(tier)
	return current


static func _next_lower_tier(state: Dictionary, current: float) -> float:
	var previous := float(state.get("minimum_msec", current))
	for tier in state["tiers"]:
		if float(tier) >= current:
			return previous
		previous = float(tier)
	return previous


static func _prune_variations(samples: Array, now_msec: int) -> void:
	while not samples.is_empty() and (now_msec - int(samples[0]["at_msec"]) > WINDOW_MSEC
			or samples.size() > WINDOW_SAMPLE_CAP):
		samples.pop_front()


static func _prune_gaps(state: Dictionary, now_msec: int) -> void:
	var samples: Array = state["recent_gap_samples"]
	while not samples.is_empty() and now_msec - int(samples[0]["at_msec"]) > WINDOW_MSEC:
		samples.pop_front()
	var total := 0
	for sample in samples:
		total += int(sample["count"])
	state["recent_sequence_gaps"] = total


static func _update_variation_stats(state: Dictionary) -> void:
	var values: Array[float] = []
	for sample in state["variation_samples"]:
		values.append(float(sample["value_msec"]))
	values.sort()
	state["variation_p50_msec"] = _percentile_sorted(values, 0.50)
	state["variation_p95_msec"] = _percentile_sorted(values, 0.95)
	state["variation_max_msec"] = values[-1] if not values.is_empty() else 0.0


static func _percentile_sorted(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var index := clampi(int(ceil(fraction * float(values.size()))) - 1, 0,
		values.size() - 1)
	return values[index]
