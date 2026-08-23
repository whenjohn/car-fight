extends SceneTree

func _initialize() -> void:
	var bundle := get_root().get_node("StateBundle")
	bundle._coalesce_bundle(10, false, PackedInt64Array([101]),
		PackedByteArray([0]), PackedInt32Array([-1]), [["a"]], 1)
	bundle._coalesce_bundle(11, false, PackedInt64Array([202]),
		PackedByteArray([0]), PackedInt32Array([-1]), [["b"]], 1)
	if bundle._pending_delta.size() != 2 \
			or not bundle._pending_delta.has(101) \
			or not bundle._pending_delta.has(202):
		push_error("STATE_BUNDLE_COALESCING_TEST FAIL: a sparse newer envelope evicted another route")
		quit(1)
		return
	bundle._coalesce_bundle(12, false, PackedInt64Array([101]),
		PackedByteArray([0]), PackedInt32Array([-1]), [["new"]], 1)
	if int(bundle._pending_delta[101]["tick"]) != 12 \
			or int(bundle._pending_delta[202]["tick"]) != 11:
		push_error("STATE_BUNDLE_COALESCING_TEST FAIL: per-route newest selection is wrong")
		quit(1)
		return
	_test_settled_route_selection(bundle)
	print("STATE_BUNDLE_COALESCING_TEST PASS")
	quit()


func _test_settled_route_selection(bundle: Node) -> void:
	bundle._pending_by_tick = {
		20: {2: [PackedInt64Array([1, 3]), PackedByteArray([0, 0]),
			PackedInt32Array([-1, -1]), [["current-1"], ["current-3"]]]},
		18: {2: [PackedInt64Array([1, 2, 3]), PackedByteArray([0, 1, 0]),
			PackedInt32Array([-1, 12, -1]), [["old-1"], ["settled-2"], ["old-3"]]]},
	}
	bundle._retain_newest_settled_entry_per_route()
	if bundle._pending_by_tick.size() != 2 \
			or not bundle._pending_by_tick.has(20) \
			or not bundle._pending_by_tick.has(18):
		push_error("STATE_BUNDLE_COALESCING_TEST FAIL: settled source ticks were lost")
		quit(1)
		return
	var current: Array = bundle._pending_by_tick[20][2]
	var replayed: Array = bundle._pending_by_tick[18][2]
	if current[0] != PackedInt64Array([1, 3]) \
			or replayed[0] != PackedInt64Array([2]) \
			or replayed[3] != [["settled-2"]]:
		push_error("STATE_BUNDLE_COALESCING_TEST FAIL: did not retain newest entry per route")
		quit(1)
