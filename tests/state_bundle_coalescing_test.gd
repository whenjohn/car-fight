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
	print("STATE_BUNDLE_COALESCING_TEST PASS")
	quit()
