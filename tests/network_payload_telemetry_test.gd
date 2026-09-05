extends SceneTree

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var performance := root.get_node("NetworkPerformance")
	performance.set_app_telemetry_enabled(true)
	var small := [1, PackedByteArray([1, 2])]
	var large := [1, PackedByteArray(range(128))]
	var small_bytes := var_to_bytes(small).size()
	var large_bytes := var_to_bytes(large).size()
	performance.record_app_message("out", "input", large, 3)
	performance.record_app_message("out", "input", small)
	performance.record_app_message("in", "input", small)
	performance.record_app_message("out", "ignored", large, 0)
	performance.record_app_state_bundle("out", large, 8)
	performance.record_app_state_bundle("out", small, 2)
	var snapshot: Dictionary = performance.get_app_telemetry_snapshot(100)
	_check(snapshot.payload_bytes["out:input"] == large_bytes * 3 + small_bytes,
		"existing byte accounting retains recipient fan-out")
	_check(snapshot.get("payload_max_bytes", {}).get("out:input", -1) == large_bytes,
		"maximum message measures one payload, not multiplied copies")
	_check(snapshot.get("payload_max_bytes", {}).get("in:input", -1) == small_bytes,
		"direction-specific maximum is independent")
	_check(not snapshot.get("payload_max_bytes", {}).has("out:ignored"), "zero-copy calls remain ignored")
	_check(snapshot.get("bundle_max_bytes", {}).get("out", -1) == large_bytes,
		"maximum bundle survives a later smaller envelope")
	_check("payload_max=" in performance.build_app_telemetry_report(100), "NETAPP exposes maximum payloads")
	_check("bundle_max=" in performance.build_app_telemetry_report(100), "NETAPP exposes maximum bundles")
	performance._reset_app_telemetry_window()
	snapshot = performance.get_app_telemetry_snapshot(100)
	_check(snapshot.get("payload_max_bytes", {}).is_empty() and snapshot.get("bundle_max_bytes", {}).is_empty(),
		"maximums reset with the existing reporting window")
	performance.set_app_telemetry_enabled(false)
	performance.record_app_message("out", "input", large)
	performance.record_app_state_bundle("out", large, 8)
	_check(performance.get_app_telemetry_snapshot(100).is_empty() and performance.build_app_telemetry_report(100).is_empty(),
		"disabled telemetry records and reports nothing")
	print("NETWORK_PAYLOAD_TELEMETRY_TEST %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr("FAIL: %s" % message)
