extends SceneTree

const AdaptiveDelay := preload("res://net/adaptive_presentation_delay.gd")


static func record_time_msec(record: Dictionary, fallback: int) -> int:
	if str(record.get("type", "")) == "batch":
		return int(record.get("arrival_msec", record.get("at_msec", fallback)))
	return int(record.get("at_msec", fallback))


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var trace_path := ""
	var expect := ""
	var i := 0
	while i < args.size():
		match args[i]:
			"--trace":
				i += 1
				trace_path = args[i]
			"--expect-clean":
				expect = "clean"
			"--expect-raise":
				expect = "raise"
		i += 1
	if trace_path.is_empty():
		printerr("usage: --trace PATH [--expect-clean|--expect-raise]")
		quit(2)
		return
	var records := _read_records(trace_path)
	if records.is_empty() or str(records[0].get("type", "")) != "config":
		printerr("PRESENTATION REPLAY: missing config record")
		quit(2)
		return
	var config: Dictionary = records[0]
	var minimum := float(config.get("minimum_msec", 75.0))
	var maximum := float(config.get("maximum_msec", 150.0))
	var state := {}
	AdaptiveDelay.configure(state, minimum, maximum,
		float(config.get("tickrate", 60.0)))
	var maximum_target := minimum
	var last_at := -1
	var transitions: Array = []
	for value in records.slice(1):
		var record: Dictionary = value
		var at := record_time_msec(record, last_at)
		last_at = maxi(last_at, at)
		var before := AdaptiveDelay.target_msec(state)
		match str(record.get("type", "")):
			"epoch":
				AdaptiveDelay.reset_epoch(state, at)
			"batch":
				AdaptiveDelay.observe_batch(state, int(record["sequence"]),
					int(record["tick"]), at,
					bool(record.get("hitch_contaminated", false)))
			"frame":
				AdaptiveDelay.observe_frame(state, at,
					float(record.get("delta_msec", 0.0)),
					record.get("bodies", []) as Array)
		var after := AdaptiveDelay.target_msec(state)
		if after != before:
			transitions.append({"at_msec": at, "from_msec": before,
				"to_msec": after, "reason": state.get("pressure_reason", "")})
		maximum_target = maxf(maximum_target, after)
	var summary := {"profile": AdaptiveDelay.PROFILE_VERSION,
		"trace": trace_path, "minimum_msec": minimum,
		"maximum_msec": maximum, "maximum_target_msec": maximum_target,
		"final_target_msec": AdaptiveDelay.target_msec(state),
		"transitions": transitions}
	print("[presentation-replay] %s" % JSON.stringify(summary))
	var failed := (expect == "clean" and maximum_target > minimum) \
		or (expect == "raise" and maximum_target <= minimum)
	quit(1 if failed else 0)


func _read_records(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var records: Array = []
	for line in file.get_as_text().split("\n"):
		if line.strip_edges().is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			records.append(parsed)
	file.close()
	return records
