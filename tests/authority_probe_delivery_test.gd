extends SceneTree

var _failed := false


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://Main.gd")
	var function_start := source.find("func _send_settled_authority_probes() -> void:")
	var function_end := source.find("\nfunc ", function_start + 1)
	_check(function_start >= 0 and function_end > function_start,
		"authority-probe service function exists")
	if function_start < 0 or function_end <= function_start:
		quit(1)
		return
	var delivery := source.substr(function_start, function_end - function_start)
	var dequeue_index := delivery.find("_authority_probe_queue.pop_front()")
	var schedule_index := delivery.find("_authority_probe_queue.append(")
	_check("const AUTHORITY_PROBE_SEND_DELAY_TICKS := 20" in source,
		"settled samples retain the accepted client-history delay")
	_check("while not _authority_probe_queue.is_empty()" in delivery \
		and "AUTHORITY_PROBE_SEND_DELAY_TICKS" in delivery,
		"mature queued samples are consumed")
	_check(dequeue_index >= 0 and schedule_index > dequeue_index,
		"mature samples are delivered before the next sample is queued")
	_check("multiplayer.get_peers().has(peer_id)" in delivery,
		"delivery rechecks that each sampled peer is still connected")
	_check("_receive_authority_probe.rpc_id(peer_id" in delivery,
		"each connected owner receives its delayed same-tick sample")
	if _failed:
		quit(1)
		return
	print("AUTHORITY_PROBE_DELIVERY_TEST PASS delay_ticks=20")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("AUTHORITY_PROBE_DELIVERY_TEST FAIL: %s" % message)
