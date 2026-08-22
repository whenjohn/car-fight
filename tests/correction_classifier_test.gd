extends SceneTree

const CLASSIFIER := preload("res://player/correction_classifier.gd")


func _initialize() -> void:
	_expect({"frame_ms_max": 70.0}, ["stall"], "frame stall")
	_expect({"source_tick": 99, "history_start": 100}, ["stale"], "stale origin")
	_expect({"source_tick": 100, "history_start": 100,
		"fresh_key_age_ticks": 20}, ["stale"], "recent recovery")
	_expect({"source_tick": 100, "history_start": 100,
		"contact_age_ticks": 8}, ["impact"], "recent impact")
	_expect({"frame_ms_current": 55.0, "contact_age_ticks": 2},
		["stall", "impact"], "multi-signal correction")
	_expect({"map_transition_age_ticks": 3}, ["map"], "map transition")
	_expect({"source_tick": 100, "history_start": 100,
		"contact_age_ticks": 61, "fresh_key_age_ticks": 121},
		["unknown"], "unattributed correction")
	print("CORRECTION_CLASSIFIER_TEST PASS")
	quit()


func _expect(sample: Dictionary, expected: Array[String], label: String) -> void:
	var actual: Array[String] = CLASSIFIER.signals(sample)
	if actual != expected:
		push_error("CORRECTION_CLASSIFIER_TEST FAIL %s expected=%s actual=%s" % [
			label, expected, actual])
		quit(1)

