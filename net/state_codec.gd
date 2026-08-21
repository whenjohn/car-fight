extends RefCounted
## Packed wire codec for the rollback STATE stream (opt-in via --packed-state / ?packedState=1).
##
## WHY: `physics_state` is `[Vector3 origin, Quaternion quat, Vector3 lin_vel, Vector3 ang_vel, bool
## sleeping]` and Godot Variant serialization ships it at ~85-90B per value — every diff, every full,
## every key, for every body. The Phase 4 sweep priced that at crate 6.7 / orb 3.5 / drone 13.5 KB/s
## per body at 20Hz. This codec packs the same value into a 26B fixed block (~3.2x), and its deadband
## drops diff entries whose packed bytes equal the packed reference — so the float-noise jitter of
## `can_sleep=false` bodies (whole-property diffing ships the entire array for a 1e-7 wiggle) collapses
## to an empty diff instead of 20Hz of full physics arrays.
##
## WIRE-ONLY (plan correction C1): the server's sim and its own history NEVER round. The receiver applies
## quantized values — that is the reconciliation floor, bounded at half a quantum per component (origin
## 0.005u, three orders of magnitude under the MISPRED warn levels). Contrast with input_codec.gd, which
## quantizes at the SOURCE (_gather) because the owner must predict exactly what the wire carries; state
## has no owner-side prediction of REMOTE bodies, so wire-only is correct here and bit-exactness is not
## the contract — within-half-quantum is (state_codec_selftest.gd asserts exactly that).
##
## TYPE-DRIVEN, NOT SCHEMA-KEYED: physics_state is the only Array-typed property in g2's registered state
## surface, and `[Vector3, Quaternion, Vector3, Vector3, bool]` cannot alias any scalar. So pack sniffs
## values by exact shape and unpack is driven by the magic byte — no property-index bookkeeping, no
## coupling to _DiffHistoryEncoder's hash-probed idx assignment (the idx passes through opaquely).
##
## FORMATS (all little-endian):
##   physics block (26B fixed):
##     s24 x3  origin      0.01u steps, ABSOLUTE (+/-83,886u — covers the ~1800u far-map offsets with
##                         orders of magnitude to spare; chosen over map-relative int16 so the codec
##                         stays STATELESS: no map_id fallback, no body-contextual decode)
##     u32     quat        smallest-three: bits 30-31 = index of the largest component, 3x 10-bit signed
##                         remaining components scaled by 511/sqrt(0.5); largest is reconstructed
##                         non-negative (q and -q are the same rotation) and the result re-normalized
##     s16 x3  lin_vel     1/200 u/s steps (+/-163 u/s; bolt-punted orbs measured ~80)
##     s16 x3  ang_vel     1/100 rad/s steps (+/-327 rad/s)
##     u8      flags       bit0 = SLEEPING — BIT-EXACT passthrough, never quantized (D-012: the sleeping
##                         flag restore is load-bearing; the selftest asserts it bit-exact)
##   full payload value (replaces the physics_state Variant inside the snapshot encoder's flat Array):
##     PackedByteArray [MAGIC, FORMAT_VERSION, 26B block]           (28B; type-driven receive — a legacy
##                                                                   Variant Array can never alias it)
##   diff payload (whole-buffer transcode of _DiffHistoryEncoder's [u8 version][u8 idx + put_var]*):
##     [MAGIC, FORMAT_VERSION, orig_version, entries*]
##     entry: [u8 idx][u8 kind][payload]  kind 0 = raw put_var bytes, kind 1 = 26B physics block
##   unpack_diff rebuilds the EXACT original buffer (put_var(get_var(x)) is deterministic for g2's
##   scalar surface), so _DiffHistoryEncoder.decode() sees the wire it has always seen.
##
## Malformed handling: pack side FAILS OPEN (returns the legacy payload untouched and counts a fallback —
## the wire stays valid); unpack side FAILS LOUD (reject, the caller applies nothing — never garbage into
## the sim). Same contract as input_codec.gd.

const MAGIC := 0xB8            # a raw diff's first byte is _DiffHistoryEncoder's property-set version,
                               # which increments from 0 once per add_properties call — deterministically
                               # tiny in g2 (properties register once per configure). unpack_diff still
                               # guards: a magic match that fails to parse is a counted reject.
const FORMAT_VERSION := 1
const BLOCK_BYTES := 26
const FULL_VALUE_BYTES := 2 + BLOCK_BYTES

const ORIGIN_STEP := 0.01      # s24 -> +/-83,886u
const LIN_VEL_STEP := 0.005    # s16 -> +/-163.8 u/s
const ANG_VEL_STEP := 0.01     # s16 -> +/-327.67 rad/s
const QUAT_SCALE := 511.0 / 0.70710678  # smallest-three components live in [-1/sqrt2, 1/sqrt2]

## Diagnostic counters, printed periodically by StateBundle as `[packed-state] ...` (allowlisted in
## webrtc_stats.mjs). Deadband/clamps/fallbacks count on the sender, rejects on the receiver.
static var deadband_dropped := 0
static var clamped := 0
static var pack_fallbacks := 0
static var rejects := 0

## The physics_state shape, exactly (network-rigid-body-3d.gd): nothing else in g2's state surface is an
## Array, and no scalar can match this. The belt-and-braces for the type-driven design.
static func looks_like_physics_state(v: Variant) -> bool:
	if not (v is Array):
		return false
	var a := v as Array
	return a.size() == 5 and a[0] is Vector3 and a[1] is Quaternion \
		and a[2] is Vector3 and a[3] is Vector3 and typeof(a[4]) == TYPE_BOOL

static func is_packed_full_value(v: Variant) -> bool:
	if not (v is PackedByteArray):
		return false
	var b := v as PackedByteArray
	return b.size() == FULL_VALUE_BYTES and b[0] == MAGIC and b[1] == FORMAT_VERSION

# -- scalar helpers ----------------------------------------------------------------------------------

static func _quant(f: float, step: float, lo: int, hi: int) -> int:
	var q := roundi(f / step)
	if q < lo or q > hi:
		clamped += 1
		q = clampi(q, lo, hi)
	return q

static func _enc_s24(b: PackedByteArray, off: int, v: int) -> void:
	b[off] = v & 0xFF
	b[off + 1] = (v >> 8) & 0xFF
	b[off + 2] = (v >> 16) & 0xFF

static func _dec_s24(b: PackedByteArray, off: int) -> int:
	var v := b[off] | (b[off + 1] << 8) | (b[off + 2] << 16)
	return v - 0x1000000 if v >= 0x800000 else v

# -- the 26B physics block ---------------------------------------------------------------------------

## Returns the 26B block, or an EMPTY array when `state` is not the physics_state shape.
static func pack_physics(state: Variant) -> PackedByteArray:
	if not looks_like_physics_state(state):
		return PackedByteArray()
	var origin: Vector3 = state[0]
	var quat: Quaternion = state[1]
	var lin: Vector3 = state[2]
	var ang: Vector3 = state[3]
	var b := PackedByteArray()
	b.resize(BLOCK_BYTES)
	_enc_s24(b, 0, _quant(origin.x, ORIGIN_STEP, -8388608, 8388607))
	_enc_s24(b, 3, _quant(origin.y, ORIGIN_STEP, -8388608, 8388607))
	_enc_s24(b, 6, _quant(origin.z, ORIGIN_STEP, -8388608, 8388607))
	b.encode_u32(9, _pack_quat(quat))
	b.encode_s16(13, _quant(lin.x, LIN_VEL_STEP, -32768, 32767))
	b.encode_s16(15, _quant(lin.y, LIN_VEL_STEP, -32768, 32767))
	b.encode_s16(17, _quant(lin.z, LIN_VEL_STEP, -32768, 32767))
	b.encode_s16(19, _quant(ang.x, ANG_VEL_STEP, -32768, 32767))
	b.encode_s16(21, _quant(ang.y, ANG_VEL_STEP, -32768, 32767))
	b.encode_s16(23, _quant(ang.z, ANG_VEL_STEP, -32768, 32767))
	b[25] = 1 if state[4] else 0
	return b

static func unpack_physics(b: PackedByteArray, off: int) -> Array:
	if off + BLOCK_BYTES > b.size():
		return []
	var origin := Vector3(_dec_s24(b, off) * ORIGIN_STEP, _dec_s24(b, off + 3) * ORIGIN_STEP,
		_dec_s24(b, off + 6) * ORIGIN_STEP)
	var quat := _unpack_quat(b.decode_u32(off + 9))
	var lin := Vector3(b.decode_s16(off + 13) * LIN_VEL_STEP, b.decode_s16(off + 15) * LIN_VEL_STEP,
		b.decode_s16(off + 17) * LIN_VEL_STEP)
	var ang := Vector3(b.decode_s16(off + 19) * ANG_VEL_STEP, b.decode_s16(off + 21) * ANG_VEL_STEP,
		b.decode_s16(off + 23) * ANG_VEL_STEP)
	return [origin, quat, lin, ang, b[off + 25] != 0]

static func _pack_quat(q: Quaternion) -> int:
	var c := [q.x, q.y, q.z, q.w]
	var largest := 0
	for i in 4:
		if absf(c[i]) > absf(c[largest]):
			largest = i
	if c[largest] < 0.0:  # q and -q are the same rotation; force the dropped component non-negative
		for i in 4:
			c[i] = -c[i]
	var packed := largest << 30
	var shift := 20
	for i in 4:
		if i == largest:
			continue
		var v := clampi(roundi(c[i] * QUAT_SCALE), -511, 511)
		packed |= (v & 0x3FF) << shift
		shift -= 10
	return packed

static func _unpack_quat(packed: int) -> Quaternion:
	var largest := (packed >> 30) & 0x3
	var c := [0.0, 0.0, 0.0, 0.0]
	var shift := 20
	var sum_sq := 0.0
	for i in 4:
		if i == largest:
			continue
		var raw := (packed >> shift) & 0x3FF
		if raw >= 512:
			raw -= 1024
		c[i] = raw / QUAT_SCALE
		sum_sq += c[i] * c[i]
		shift -= 10
	c[largest] = sqrt(maxf(0.0, 1.0 - sum_sq))
	return Quaternion(c[0], c[1], c[2], c[3]).normalized()

# -- FULL payloads (the snapshot encoder's flat Variant Array + trailing version int) ----------------

## Replaces every physics_state value with the 28B tagged block; everything else (scalars + the trailing
## version) passes through untouched. Returns a NEW array — the caller's stays legacy-shaped.
static func pack_full(data: Array) -> Array:
	var out := data.duplicate()
	for i in out.size():
		if looks_like_physics_state(out[i]):
			var block := pack_physics(out[i])
			var tagged := PackedByteArray([MAGIC, FORMAT_VERSION])
			tagged.append_array(block)
			out[i] = tagged
	return out

## Type-driven: rebuilds the legacy flat array. Returns [] on a malformed tagged value — the caller
## counts a reject and applies nothing.
static func unpack_full(data: Array) -> Array:
	var out := data.duplicate()
	for i in out.size():
		if out[i] is PackedByteArray and (out[i] as PackedByteArray).size() >= 2 \
				and out[i][0] == MAGIC:
			if not is_packed_full_value(out[i]):
				rejects += 1
				return []
			var state := unpack_physics(out[i], 2)
			if state.is_empty():
				rejects += 1
				return []
			out[i] = state
	return out

# -- DIFF payloads (_DiffHistoryEncoder's [u8 version][u8 idx + put_var]* buffer) --------------------

## `ref_block`: the packed 26B block of the reference-tick physics_state (or empty to disable the
## deadband). A physics entry whose packed bytes EQUAL the reference's is dropped: the receiver's merge()
## keeps its reference value, which is bit-identical at the grid — sub-quantum jitter becomes an empty
## diff. Parse trouble fails OPEN (legacy payload returned, fallback counted): the sender's own diff
## encoder produced this buffer, so a parse failure means the netfox wire format changed underneath us.
static func pack_diff(data: PackedByteArray, ref_block: PackedByteArray) -> PackedByteArray:
	if data.is_empty():
		return data
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	var version := buffer.get_u8()
	var out := StreamPeerBuffer.new()
	out.put_u8(MAGIC)
	out.put_u8(FORMAT_VERSION)
	out.put_u8(version)
	while buffer.get_available_bytes() > 0:
		if buffer.get_available_bytes() < 2:
			pack_fallbacks += 1
			return data
		var idx := buffer.get_u8()
		var before := buffer.get_position()
		var value: Variant = buffer.get_var()
		# null doubles as the malformed-var signal: no registered g2 state property is ever null.
		if buffer.get_position() <= before or value == null:
			pack_fallbacks += 1
			return data
		if looks_like_physics_state(value):
			var block := pack_physics(value)
			if not ref_block.is_empty() and block == ref_block:
				deadband_dropped += 1
				continue
			out.put_u8(idx)
			out.put_u8(1)
			out.put_data(block)
		else:
			out.put_u8(idx)
			out.put_u8(0)
			out.put_var(value)
	return out.data_array

## Passthrough when not magic-tagged (legacy peers / packing off). Returns the rebuilt legacy buffer,
## or null on a malformed payload — the caller counts a reject and applies nothing.
static func unpack_diff(data: PackedByteArray) -> Variant:
	if data.is_empty() or data[0] != MAGIC:
		return data
	if data.size() < 3 or data[1] != FORMAT_VERSION:
		rejects += 1
		return null
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	buffer.seek(2)
	var out := StreamPeerBuffer.new()
	out.put_u8(buffer.get_u8())  # the original diff version byte
	while buffer.get_available_bytes() > 0:
		if buffer.get_available_bytes() < 2:
			rejects += 1
			return null
		var idx := buffer.get_u8()
		var kind := buffer.get_u8()
		if kind == 1:
			if buffer.get_available_bytes() < BLOCK_BYTES:
				rejects += 1
				return null
			var state := unpack_physics(buffer.data_array, buffer.get_position())
			buffer.seek(buffer.get_position() + BLOCK_BYTES)
			out.put_u8(idx)
			out.put_var(state)
		elif kind == 0:
			var before := buffer.get_position()
			var value: Variant = buffer.get_var()
			# null doubles as the malformed/truncated-var signal (no g2 state property is null).
			if buffer.get_position() <= before or value == null:
				rejects += 1
				return null
			out.put_u8(idx)
			out.put_var(value)
		else:
			rejects += 1
			return null
	return out.data_array
