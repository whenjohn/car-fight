class_name CorrectionClassifier
extends RefCounted

const STALL_FRAME_MS := 50.0
const STALE_STATE_AGE_TICKS := 64
const RECENT_RECOVERY_TICKS := 120
const RECENT_CONTACT_TICKS := 60
const RECENT_MAP_TRANSITION_TICKS := 60


static func signals(sample: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if float(sample.get("frame_ms_current", 0.0)) >= STALL_FRAME_MS \
			or float(sample.get("frame_ms_max", 0.0)) >= STALL_FRAME_MS \
			or float(sample.get("process_ms", 0.0)) >= STALL_FRAME_MS:
		result.append("stall")
	var recovery_recent := _recent(int(sample.get("fresh_key_age_ticks", -1)),
		RECENT_RECOVERY_TICKS) or _recent(int(sample.get("fast_forward_age_ticks", -1)),
		RECENT_RECOVERY_TICKS)
	var source_stale := int(sample.get("source_tick", -1)) \
		< int(sample.get("history_start", -1))
	var applied_stale := int(sample.get("applied_state_age_ticks", -1)) \
		>= STALE_STATE_AGE_TICKS
	if recovery_recent or source_stale or applied_stale:
		result.append("stale")
	if _recent(int(sample.get("contact_age_ticks", -1)), RECENT_CONTACT_TICKS):
		result.append("impact")
	if _recent(int(sample.get("map_transition_age_ticks", -1)),
			RECENT_MAP_TRANSITION_TICKS):
		result.append("map")
	if result.is_empty():
		result.append("unknown")
	return result


static func _recent(age_ticks: int, maximum_ticks: int) -> bool:
	return age_ticks >= 0 and age_ticks <= maximum_ticks

