extends SceneTree

const Schedule := preload("res://net/remote_position_schedule.gd")
const Interp := preload("res://net/remote_snapshot_interpolation.gd")
const Validation := preload("res://net/remote_position_validation.gd")
const Relevance := preload("res://net/remote_position_relevance.gd")
const MapLayout := preload("res://world/map_layout.gd")

var failed := false

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("REMOTE POSITION ASSERT: %s" % message)

func emitted_ticks(rate: int, ticks: Array[int]) -> Dictionary:
	var state := {}
	Schedule.configure(state, rate, 60)
	var emitted: Array[int] = []
	var skipped := 0
	for tick in ticks:
		var decision := Schedule.advance(state, tick)
		if bool(decision["due"]):
			emitted.append(int(decision["tick"]))
			skipped += int(decision["skipped"])
	return {"ticks": emitted, "skipped": skipped}

func payload_for(body_count: int) -> Array:
	var ids := PackedInt64Array()
	var generations := PackedInt32Array()
	var positions := PackedVector3Array()
	var rotations := PackedVector4Array()
	var linear_velocities := PackedVector3Array()
	var angular_velocities := PackedVector3Array()
	for i in body_count:
		ids.append(1000 + i)
		generations.append(i + 1)
		positions.append(Vector3(i * 13.25, 0.0, i * -7.5))
		rotations.append(Vector4(0.0, 0.0, 0.0, 1.0))
		linear_velocities.append(Vector3(4.0, 0.0, -2.0))
		angular_velocities.append(Vector3(0.0, 0.5, 0.0))
	return [77, 88, 12345, 0, ids, generations, positions, rotations,
		linear_velocities, angular_velocities]

func relevance_samples() -> Array:
	return [
		{"id": 10, "generation": 1, "map": 0, "position": Vector3(1, 0, 0)},
		{"id": 20, "generation": 2, "map": 0, "position": Vector3(2, 0, 0)},
		{"id": 30, "generation": 3, "map": 4, "position": Vector3(3, 0, 0)},
		# A drone is not the recipient's body even if a player requested it.
		{"id": 900001, "generation": 4, "map": 0, "position": Vector3(4, 0, 0)},
	]

func _initialize() -> void:
	var sequential: Array[int] = []
	for tick in range(1, 121):
		sequential.append(tick)
	check((emitted_ticks(60, sequential)["ticks"] as Array).size() == 120,
		"60 Hz scheduler did not emit once per healthy tick")
	check((emitted_ticks(30, sequential)["ticks"] as Array).size() == 60,
		"30 Hz scheduler cadence is wrong")
	check((emitted_ticks(20, sequential)["ticks"] as Array).size() == 40,
		"20 Hz scheduler cadence is wrong")

	# C and D instantiate the same scheduling function. Their emitted tick list
	# must remain bit-identical or the batching comparison is contaminated.
	var irregular: Array[int] = [1, 2, 3, 8, 9, 10, 14, 15, 21]
	var legacy20 := emitted_ticks(20, irregular)
	var batch20 := emitted_ticks(20, irregular)
	check(legacy20["ticks"] == batch20["ticks"], "legacy/batch sample ticks diverged")
	check(legacy20["ticks"] == [1, 8, 10, 14, 21],
		"20 Hz missed-deadline ticks were not collapsed onto final settled state")
	check(int(legacy20["skipped"]) == 2,
		"20 Hz skipped-interval count is wrong")

	check(int(emitted_ticks(60, [1, 2, 3, 8])["skipped"]) == 4,
		"60 Hz catch-up did not count four collapsed deadlines")
	check(int(emitted_ticks(30, [1, 2, 3, 8])["skipped"]) == 1,
		"30 Hz catch-up did not count one collapsed deadline")
	check(int(emitted_ticks(20, [1, 2, 3, 8])["skipped"]) == 1,
		"20 Hz catch-up did not count one collapsed deadline")
	check(emitted_ticks(20, [100, 101, 2])["ticks"] == [100, 2],
		"tick restart did not establish a fresh scheduling epoch")

	# Per-recipient selection is a pure read over one settled registry. Self
	# means only id == peer id; drones remain ordinary relevant remotes.
	var samples := relevance_samples()
	check(Relevance.select(samples, 10, 0, Relevance.MODE_ALL, true).size() == 4,
		"all+self did not preserve the shipping body set")
	var no_self := Relevance.select(samples, 10, 0, Relevance.MODE_ALL, false)
	check(no_self.map(func(s): return int(s["id"])) == [20, 30, 900001],
		"all without self selected the wrong bodies")
	var same_map := Relevance.select(samples, 10, 0, Relevance.MODE_SAME_MAP, false)
	check(same_map.map(func(s): return int(s["id"])) == [20, 900001],
		"same-map selection omitted a remote or retained an off-map body")
	check(Relevance.select(samples, 10, Relevance.UNKNOWN_MAP,
		Relevance.MODE_SAME_MAP, false).is_empty(),
		"unknown recipient map produced a nonempty relevant set")
	check(Relevance.select(samples, 10, 4, Relevance.MODE_SAME_MAP, false).map(
		func(s): return int(s["id"])) == [30],
		"recipient map transition did not replace the relevant set")
	var generations := PackedInt32Array([7, 8])
	var membership := Relevance.membership_from_arrays(PackedInt64Array([10, 10]), generations)
	check(membership.has("10:7") and membership.has("10:8") and membership.size() == 2,
		"membership did not distinguish reused body generations")
	var next_membership := Relevance.membership_from_arrays(
		PackedInt64Array([10, 30]), PackedInt32Array([8, 9]))
	var delta := Relevance.membership_delta(membership, next_membership)
	check((delta["left"] as Dictionary).has("10:7")
		and (delta["entered"] as Dictionary).has("30:9"),
		"complete-set delta did not leave old generation and enter fresh body")
	# A lost envelope changes nothing; applying the following complete set still
	# reaches the intended membership in one accepted publication.
	var after_loss := Relevance.membership_delta(membership, next_membership)
	check((after_loss["left"] as Dictionary).size() == 1
		and (after_loss["entered"] as Dictionary).size() == 1,
		"next complete set did not recover a lost membership transition")
	var empty_delta := Relevance.membership_delta(next_membership, {})
	check((empty_delta["left"] as Dictionary).size() == 2,
		"complete empty set did not remove every remote membership")

	# Receiver envelope validation: reject mismatched/oversized arrays and any
	# sequence or authoritative tick that moves backward.
	check(Validation.classify_batch(-1, -1, -1, 1, 1, 10, 0, 2, 2, 2) == "accept",
		"valid batch was rejected")
	check(Validation.classify_batch(-1, -1, -1, 1, 1, 10, 0, 2, 1, 2) == "malformed",
		"mismatched generation array was accepted")
	check(Validation.classify_batch(-1, -1, -1, 1, 1, 10, 0, 2, 2, 1) == "malformed",
		"mismatched position array was accepted")
	check(Validation.classify_batch(-1, -1, -1, 1, 1, 10, 0, 2, 2, 2, 1) == "malformed",
		"mismatched rotation array was accepted")
	check(Validation.classify_batch(-1, -1, -1, 1, 1, 10, 0, 2, 2, 2, 2, 1, 2) \
		== "malformed", "mismatched linear velocity array was accepted")
	check(Validation.classify_batch(-1, -1, -1, 1, 1, 10, 0, 2, 2, 2, 2, 2, 1) \
		== "malformed", "mismatched angular velocity array was accepted")
	check(Validation.classify_batch(-1, -1, -1, 1, 1, 10, 0,
		Validation.MAX_BODIES + 1, Validation.MAX_BODIES + 1,
		Validation.MAX_BODIES + 1) == "malformed",
		"oversized batch was accepted")
	check(Validation.classify_batch(4, 4, 40, 4, 5, 41, 0, 1, 1, 1) == "stale",
		"duplicate sequence was accepted")
	check(Validation.classify_batch(4, 4, 40, 5, 5, 40, 0, 1, 1, 1) == "stale",
		"duplicate authoritative tick was accepted")
	check(Validation.classify_batch(4, 4, 40, 5, 5, 39, 0, 1, 1, 1) == "stale",
		"backward authoritative tick was accepted")
	check(Validation.classify_batch(4, 4, 40, 5, 4, 41, 0, 1, 1, 1) == "stale",
		"duplicate global publication was accepted")
	check(Validation.classify_batch(-1, -1, -1, 1, 1, 10, -2, 0, 0, 0) == "malformed",
		"invalid recipient map was accepted")
	check(Validation.valid_recipient_map(-1, 5),
		"unknown recipient map was rejected")
	check(Validation.valid_recipient_map(4, 5),
		"highest valid recipient map was rejected")
	check(not Validation.valid_recipient_map(5, 5),
		"out-of-range recipient map was accepted")
	check(Validation.valid_recipient_map(MapLayout.CITY_AUDITION,
		MapLayout.CITY_AUDITION + 1),
		"LOW POLY CITY recipient map was rejected")
	check(not Validation.valid_recipient_map(MapLayout.CITY_AUDITION + 1,
		MapLayout.CITY_AUDITION + 1),
		"unknown map after LOW POLY CITY was accepted")
	check(Validation.has_valid_unique_membership(
		PackedInt64Array([10, 20]), PackedInt32Array([1, 2])),
		"valid unique membership was rejected")
	check(not Validation.has_valid_unique_membership(
		PackedInt64Array([10, 10]), PackedInt32Array([1, 1])),
		"duplicate membership entry was accepted")
	check(not Validation.has_valid_unique_membership(
		PackedInt64Array([-1]), PackedInt32Array([1])),
		"negative body id was accepted")
	check(not Validation.is_deliverable_body(null),
		"unknown body id was treated as deliverable")
	var unrelated_node := Node.new()
	check(not Validation.is_deliverable_body(unrelated_node),
		"non-pilotable node was treated as a remote body")
	unrelated_node.add_to_group("pilotable")
	check(not Validation.is_deliverable_body(unrelated_node),
		"pilotable node without a receiver was treated as deliverable")
	unrelated_node.free()

	# Body incarnation and teleport watermark validation uses the exact
	# predicate called by PlayerBody.receive_remote_position.
	check(Validation.accepts_body_sample(false, false, 7, 30, 20, 7, 31),
		"valid remote body sample was rejected")
	check(not Validation.accepts_body_sample(false, false, 7, 30, 20, 6, 31),
		"generation mismatch for reused body id was accepted")
	check(not Validation.accepts_body_sample(false, false, 7, 30, 20, 7, 30),
		"stale per-body tick was accepted")
	check(not Validation.accepts_body_sample(false, false, 7, 10, 40, 7, 40),
		"sample at teleport watermark was accepted")
	check(not Validation.accepts_body_sample(false, false, 7, 10, 40, 7, 39),
		"pre-teleport sample was accepted")
	check(Validation.accepts_body_sample(false, false, 7, 10, 40, 7, 41),
		"post-teleport sample was rejected")
	check(Validation.teleport_reset_required(39, 40),
		"teleport notification before the new-map batch did not request a reset")
	check(not Validation.teleport_reset_required(40, 40),
		"late teleport notification erased an already accepted same-tick batch")
	check(not Validation.teleport_reset_required(41, 40),
		"late teleport notification erased a newer post-teleport batch")
	check(not Validation.accepts_body_sample(true, false, 7, 10, 20, 7, 31),
		"server accepted a presentation sample")
	check(not Validation.accepts_body_sample(false, true, 7, 10, 20, 7, 31),
		"local authoritative body accepted a remote sample")

	# Ordinary clock discipline remains damped and monotonic. The body that owns
	# presentation history handles epoch rebases and invalidates warmup evidence.
	var ordinary_cursor := Interp.advance_cursor(100.0, 100.5, 1.0 / 60.0, 60.0)
	check(ordinary_cursor > 100.0 and ordinary_cursor < 102.0,
		"ordinary cursor correction was not damped")
	check(Interp.advance_cursor(100.0, 800.0, 1.0 / 60.0, 60.0) < 102.0,
		"cursor helper bypassed the body-owned epoch rebase")

	# Correlated-loss model: every body loses the same publication. Constant
	# velocity must remain continuous, and every affected history must enter the
	# same explicit interpolate/extrapolate/hold mode rather than pop.
	var one_loss := {0: Vector3.ZERO, 3: Vector3(3, 0, 0),
		9: Vector3(9, 0, 0), 12: Vector3(12, 0, 0)}
	for body in 4:
		var sample := Interp.sample(one_loss, 6.0, 3.0)
		check(sample["mode"] == Interp.MODE_INTERPOLATE,
			"body %d did not interpolate across one lost batch" % body)
		check((sample["position"] as Vector3).distance_to(Vector3(6, 0, 0)) < 0.0001,
			"body %d popped across one lost batch" % body)

	var two_losses := {0: Vector3.ZERO, 3: Vector3(3, 0, 0), 12: Vector3(12, 0, 0)}
	var extrapolated := Interp.sample(two_losses, 6.0, 3.0)
	var held := Interp.sample(two_losses, 10.0, 3.0)
	check(extrapolated["mode"] == Interp.MODE_INTERPOLATE,
		"arrived surrounding sample did not bridge two missing batches")
	check(held["mode"] == Interp.MODE_INTERPOLATE,
		"bracketed history unexpectedly held")
	# Arrival-timeline case before tick 12 arrives.
	two_losses.erase(12)
	extrapolated = Interp.sample(two_losses, 6.0, 3.0)
	held = Interp.sample(two_losses, 10.0, 3.0)
	check(extrapolated["mode"] == Interp.MODE_EXTRAPOLATE,
		"two-loss underrun did not extrapolate to its bound")
	check(held["mode"] == Interp.MODE_HOLD,
		"two-loss underrun did not hold past its bound")

	var rotations := {0: Quaternion.IDENTITY, 12: Quaternion(Vector3.UP, PI * 0.5)}
	var rotation_sample := Interp.sample_rotation(rotations,
		Interp.sample({0: Vector3.ZERO, 12: Vector3(12, 0, 0)}, 6.0, 3.0), 6.0)
	check(rotation_sample.angle_to(Quaternion(Vector3.UP, PI * 0.25)) < 0.001,
		"orientation did not slerp at the position sample's render tick")

	var predicted := Interp.predict_pose(Vector3(1, 0, 2), Quaternion.IDENTITY,
		Vector3(4, 0, -2), Vector3(0, 2, 0), 0.25)
	check(predicted.origin.distance_to(Vector3(2, 0, 1.5)) < 0.0001,
		"correlated velocity did not predict position to the current timeline")
	check(predicted.basis.get_rotation_quaternion().angle_to(
		Quaternion(Vector3.UP, 0.5)) < 0.001,
		"angular velocity did not predict orientation")
	var smoothed := Interp.smooth_pose(Transform3D.IDENTITY,
		Transform3D(Basis(Quaternion(Vector3.UP, 1.0)), Vector3(10, 0, 0)), 0.045)
	check(smoothed.origin.x > 4.9 and smoothed.origin.x < 5.1,
		"predictive reconciliation is not frame-rate independent at one half-life")
	check(smoothed.origin.x < 10.0,
		"predictive reconciliation snapped an ordinary correction")
	var sizes := {}
	for count in [6, 8, 16, 32]:
		sizes[count] = var_to_bytes(payload_for(count)).size()
		print("REMOTE POSITION SIZE bodies=%d logical_bytes=%d" % [count, sizes[count]])
	check(int(sizes[8]) < int(sizes[16]) and int(sizes[16]) < int(sizes[32]),
		"synthetic envelope size did not grow monotonically")
	# Logical payload only; the live capture remains authoritative for actual
	# fragmentation. This catches an accidental Variant-fat envelope at the
	# six-player acceptance size before a network run.
	check(int(sizes[6]) < 1000, "six-body logical envelope approaches MTU unexpectedly")

	print("REMOTE POSITION TRANSPORT: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
