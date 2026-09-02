extends SceneTree
## Socket-free assertions for net/state_codec.gd (run by scripts/state_codec_test.sh).
##
## The load-bearing contracts — DIFFERENT from the input codec's, on purpose:
##  - roundtrip is WITHIN HALF A QUANTUM of the unquantized original, NOT bit-exact: state packing is
##    wire-only (C1 — the server's sim never rounds), so the receiver's value may differ from the
##    server's by up to origin 0.005u / lin_vel 0.0025 / ang_vel 0.005 per component. That IS the
##    reconciliation floor; this file is where its bound is pinned.
##  - physics_state[4] (SLEEPING) is BIT-EXACT, asserted here, never quantized (D-012).
##  - the diff transcode is verified against a REAL _DiffHistoryEncoder instance, so a netfox wire-format
##    change breaks THIS gate instead of silently corrupting state.
##
## STRUCTURE: pure-codec tests run from _init; the netfox-dependent section is DEFERRED and loads the
## netfox scripts at runtime — under `--script` the SceneTree's _init runs BEFORE autoloads register, so
## a top-level preload of anything referencing NetworkRollback fails to compile and the whole selftest
## dies without ever quitting (the first draft hung exactly this way). A watchdog timer guarantees the
## gate can fail but never hang.

const CODEC := preload("res://net/state_codec.gd")

var failures := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok: %s" % label)
	else:
		failures += 1
		printerr("  FAIL: %s" % label)

func make_state(origin: Vector3, quat: Quaternion, lin: Vector3, ang: Vector3, sleeping: bool) -> Array:
	return [origin, quat, lin, ang, sleeping]

## Half-quantum bounds + f32 headroom (Vector3 components are f32; at 1800u an ulp is ~0.0005).
func physics_close(a: Array, b: Array, origin_tol := 0.0056, vel_tol := 0.0031) -> bool:
	if a.size() != 5 or b.size() != 5:
		return false
	for axis in 3:
		if absf(a[0][axis] - b[0][axis]) > origin_tol:
			printerr("    origin axis %d: %f vs %f" % [axis, a[0][axis], b[0][axis]])
			return false
		if absf(a[2][axis] - b[2][axis]) > vel_tol:
			printerr("    lin_vel axis %d: %f vs %f" % [axis, a[2][axis], b[2][axis]])
			return false
		if absf(a[3][axis] - b[3][axis]) > 0.0056:
			printerr("    ang_vel axis %d: %f vs %f" % [axis, a[3][axis], b[3][axis]])
			return false
	var dot := absf((a[1] as Quaternion).dot(b[1] as Quaternion))
	if dot < 0.999995:
		printerr("    quat dot %f" % dot)
		return false
	if a[4] != b[4]:
		printerr("    sleeping flag %s vs %s" % [a[4], b[4]])
		return false
	return true

func _init() -> void:
	# -- physics block roundtrip: city, far-map, spinning, fast ---------------------------------------
	var cases := [
		make_state(Vector3.ZERO, Quaternion.IDENTITY, Vector3.ZERO, Vector3.ZERO, false),
		make_state(Vector3(42.37, 0.5, -61.02), Quaternion(Vector3.UP, 1.234), Vector3(18.3, 0.0, -9.7),
			Vector3(0.0, 4.2, 0.0), false),
		make_state(Vector3(-1800.25, 0.0, 1799.99), Quaternion(Vector3(0.267, 0.535, 0.802).normalized(),
			2.9), Vector3(-80.1, 3.3, 79.9), Vector3(6.1, -6.1, 6.1), false),
		make_state(Vector3(7.77, -0.01, 7.77), Quaternion(Vector3.RIGHT, -0.7071), Vector3.ZERO,
			Vector3.ZERO, true),
		# worst case for smallest-three: all components equal magnitude
		make_state(Vector3.ONE, Quaternion(0.5, 0.5, 0.5, 0.5), Vector3.ONE, Vector3.ONE, false),
		# negative-largest canonicalization (q == -q)
		make_state(Vector3.ONE, Quaternion(0.1, 0.2, 0.3, -0.927).normalized(), Vector3.ONE,
			Vector3.ONE, true),
	]
	for i in cases.size():
		var block: PackedByteArray = CODEC.pack_physics(cases[i])
		check(block.size() == CODEC.BLOCK_BYTES, "case %d packs to %dB" % [i, CODEC.BLOCK_BYTES])
		var back: Array = CODEC.unpack_physics(block, 0)
		check(physics_close(cases[i], back), "case %d within half-quantum (sleeping bit-exact)" % i)

	# -- sleeping flag both ways, explicitly (D-012) --------------------------------------------------
	for sleeping in [true, false]:
		var st := make_state(Vector3.ONE, Quaternion.IDENTITY, Vector3.ZERO, Vector3.ZERO, sleeping)
		var back2: Array = CODEC.unpack_physics(CODEC.pack_physics(st), 0)
		check(back2[4] == sleeping, "sleeping=%s survives BIT-EXACT" % sleeping)

	# -- clamps are counted, never silent -------------------------------------------------------------
	CODEC.clamped = 0
	var extreme := make_state(Vector3(90000.0, 0.0, -90000.0), Quaternion.IDENTITY,
		Vector3(500.0, 0.0, 0.0), Vector3.ZERO, false)
	var extreme_back: Array = CODEC.unpack_physics(CODEC.pack_physics(extreme), 0)
	check(CODEC.clamped >= 3, "out-of-range origin/velocity increments the clamp counter (got %d)"
		% CODEC.clamped)
	check(absf(extreme_back[0].x - 83886.07) < 0.02, "clamped origin lands on the range edge")

	# -- quantizer idempotence: pack(unpack(pack(x))) is stable ---------------------------------------
	var q_once: PackedByteArray = CODEC.pack_physics(cases[1])
	var q_twice: PackedByteArray = CODEC.pack_physics(CODEC.unpack_physics(q_once, 0))
	check(q_once == q_twice, "pack/unpack/pack is byte-stable (grid is a fixed point)")

	# -- shape guard ----------------------------------------------------------------------------------
	check(CODEC.pack_physics([Vector3.ZERO, 1.0, 2.0]).is_empty(), "non-physics array refuses to pack")
	check(not CODEC.looks_like_physics_state([Vector3.ZERO, Quaternion.IDENTITY, Vector3.ZERO,
		Vector3.ZERO, 1]), "int in the sleeping slot is not physics_state")

	# -- FULL payload: flat snapshot array [physics, scalars..., version] -----------------------------
	var full := [cases[2].duplicate(), 3, 0.75, true, 7]   # physics + carrier-ish scalars + version int
	var packed_full: Array = CODEC.pack_full(full)
	check(packed_full.size() == full.size(), "pack_full preserves element count")
	check(CODEC.is_packed_full_value(packed_full[0]), "physics entry becomes the 28B tagged value")
	check(packed_full[1] == 3 and packed_full[2] == 0.75 and packed_full[3] == true
		and packed_full[4] == 7, "scalars + trailing version pass through untouched")
	check(CODEC.looks_like_physics_state(full[0]), "caller's array is not mutated")
	var unpacked_full: Array = CODEC.unpack_full(packed_full)
	check(physics_close(full[0], unpacked_full[0]), "full roundtrip physics within half-quantum")
	check(unpacked_full[1] == 3 and unpacked_full[4] == 7, "full roundtrip scalars bit-exact")
	var legacy_full := [1, 2.0, false, 9]
	check(CODEC.unpack_full(legacy_full) == legacy_full, "legacy full array passes through")
	CODEC.rejects = 0
	var bad_full := packed_full.duplicate()
	bad_full[0] = (bad_full[0] as PackedByteArray).slice(0, 10)
	check(CODEC.unpack_full(bad_full) == [] and CODEC.rejects == 1, "truncated tagged value rejects loud")

	# The netfox-dependent section needs autoloads (NetworkRollback et al), which register AFTER this
	# _init under --script. Defer it; the watchdog turns any mid-section error into a FAIL, not a hang.
	create_timer(20.0).timeout.connect(_watchdog)
	_netfox_section.call_deferred()

func _watchdog() -> void:
	printerr("STATE_CODEC_SELFTEST: FAIL (watchdog timeout — netfox section never finished)")
	quit(1)

func _netfox_section() -> void:
	var DiffEncoder := load("res://addons/netfox/encoder/diff-history-encoder.gd")
	var HistoryBuffer := load("res://addons/netfox/properties/property-history-buffer.gd")
	var Cache := load("res://addons/netfox/properties/property-cache.gd")

	# Minimal body carrying prop_body.gd's registered surface, root-relative like production.
	var body := Node.new()
	body.name = "7"
	body.set_script(_fake_body_script())
	root.add_child(body)
	var cache = Cache.new(body)
	for path in [":physics_state", ":carrier_id"]:
		cache.get_entry(path)
	# properties() hands back the Array[PropertyEntry] the encoder's typed signatures demand — this
	# script cannot name that type itself (it compiles before the class cache is trustworthy here).
	var props = cache.properties()
	var history = HistoryBuffer.new()
	var state_a := make_state(Vector3(12.5, 0.0, -30.25), Quaternion(Vector3.UP, 0.5),
		Vector3(5.0, 0.0, -2.5), Vector3(0.0, 1.5, 0.0), false)
	var jitter := Vector3(1e-4, -1e-4, 1e-4)   # sub-quantum float noise, the idle-crate signature
	var state_b := make_state(state_a[0] + jitter, state_a[1], state_a[2] + jitter, state_a[3], false)
	history.set_snapshot(10, {":physics_state": state_a, ":carrier_id": 0})
	history.set_snapshot(11, {":physics_state": state_b, ":carrier_id": 4})
	var encoder = DiffEncoder.new(history, cache)
	encoder.add_properties(props)
	var diff: PackedByteArray = encoder.encode(11, 10, props)
	check(not diff.is_empty(), "real encoder emits a diff for jitter + scalar change")

	# no deadband: transcode must hand the receiver's real decoder a buffer it parses identically —
	# except the physics value, which lands on the quantized grid
	var packed_diff: PackedByteArray = CODEC.pack_diff(diff, PackedByteArray())
	check(packed_diff[0] == CODEC.MAGIC, "packed diff is magic-tagged")
	check(packed_diff.size() < diff.size(), "packed diff is smaller (%d -> %dB)"
		% [diff.size(), packed_diff.size()])
	var rebuilt: Variant = CODEC.unpack_diff(packed_diff)
	check(rebuilt is PackedByteArray, "unpack_diff rebuilds a legacy buffer")
	var receiver = DiffEncoder.new(HistoryBuffer.new(), cache)
	receiver.add_properties(props)
	var snapshot = receiver.decode(rebuilt, props)
	check(snapshot.get_value(":carrier_id") == 4, "scalar diff entry survives transcode bit-exact")
	check(physics_close(state_b, snapshot.get_value(":physics_state")),
		"physics diff entry survives transcode within half-quantum")

	# -- deadband: sub-quantum jitter vs the reference drops the entry --------------------------------
	CODEC.deadband_dropped = 0
	var ref_block: PackedByteArray = CODEC.pack_physics(state_a)
	var deadbanded: PackedByteArray = CODEC.pack_diff(diff, ref_block)
	check(CODEC.deadband_dropped == 1, "sub-quantum physics jitter is deadband-dropped")
	var db_snapshot = receiver.decode(CODEC.unpack_diff(deadbanded), props)
	check(db_snapshot.get_value(":carrier_id") == 4 and not db_snapshot.has(":physics_state"),
		"deadbanded diff keeps the scalar and omits physics (receiver merge() keeps its reference)")

	# a real move (above one quantum) must NOT deadband
	var state_c := make_state(state_a[0] + Vector3(0.02, 0.0, 0.0), state_a[1], state_a[2],
		state_a[3], false)
	history.set_snapshot(12, {":physics_state": state_c, ":carrier_id": 4})
	var move_diff: PackedByteArray = encoder.encode(12, 10, props)
	CODEC.deadband_dropped = 0
	var move_packed: PackedByteArray = CODEC.pack_diff(move_diff, ref_block)
	check(CODEC.deadband_dropped == 0, "an above-quantum move is never deadband-dropped")
	var move_snapshot = receiver.decode(CODEC.unpack_diff(move_packed), props)
	check(physics_close(state_c, move_snapshot.get_value(":physics_state")),
		"the moved state arrives within half-quantum")

	# -- diff edge cases ------------------------------------------------------------------------------
	check(CODEC.pack_diff(PackedByteArray(), PackedByteArray()) == PackedByteArray(),
		"empty diff stays empty")
	var legacy_diff := PackedByteArray([1, 42])   # version byte + garbage idx, no value: fail-open
	CODEC.pack_fallbacks = 0
	check(CODEC.pack_diff(legacy_diff, PackedByteArray()) == legacy_diff
		and CODEC.pack_fallbacks == 1, "unparseable send-side diff fails OPEN + counted")
	check(CODEC.unpack_diff(diff) == diff, "legacy (non-magic) diff passes through unpack")
	CODEC.rejects = 0
	var truncated_diff := packed_diff.slice(0, packed_diff.size() - 5)
	check(CODEC.unpack_diff(truncated_diff) == null and CODEC.rejects == 1,
		"truncated packed diff rejects loud")
	var bad_version := packed_diff.duplicate()
	bad_version[1] = 99
	check(CODEC.unpack_diff(bad_version) == null, "format-version mismatch rejects")
	var bad_kind := packed_diff.duplicate()
	# entry layout after the 3-byte header: [idx][kind]... — corrupt the first entry's kind
	bad_kind[4] = 9
	check(CODEC.unpack_diff(bad_kind) == null, "unknown entry kind rejects")

	if failures == 0:
		print("STATE_CODEC_SELFTEST: PASS")
		quit(0)
	else:
		printerr("STATE_CODEC_SELFTEST: FAIL (%d)" % failures)
		quit(1)

## Built at runtime for the same reason the netfox loads are: nothing here may compile before autoloads.
func _fake_body_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar physics_state: Array = []\nvar carrier_id: int = 0\n"
	script.reload()
	return script
