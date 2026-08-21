extends RefCounted
## Packed wire codec for Car Fight's rollback input stream.
##
## The cursor command is encoded as a planar angle plus distance and the twelve
## held controls share one bit mask. Receive is type-driven, so legacy Variant
## arrays and packed peers can coexist during an A/B rollout.

const MAGIC := 0xB7
const FORMAT_VERSION := 1
const SNAPSHOT_BYTES := 6
const CURSOR_DISTANCE_MAX := 655.35

const BOOL_PROPS := [
	"Input:burst", "Input:reverse", "Input:cloak_held", "Input:shield_held",
	"Input:det", "Input:area_arm_held", "Input:area_fire", "Input:homing_held",
	"Input:rc_fire_held", "Input:rc_detonate_held", "Input:tractor", "Input:editing",
]
const EXPECTED_ORDER := [
	"Input:cursor_offset", "Input:burst", "Input:reverse", "Input:cloak_held",
	"Input:shield_held", "Input:det", "Input:area_arm_held", "Input:area_fire",
	"Input:homing_held", "Input:rc_fire_held", "Input:rc_detonate_held",
	"Input:tractor", "Input:editing",
]


static func quantize_cursor_offset(value: Vector2) -> Vector2:
	var distance := roundi(clampf(value.length(), 0.0, CURSOR_DISTANCE_MAX) * 100.0) / 100.0
	if distance <= 0.0:
		return Vector2.ZERO
	var angle_q := int(roundf(value.angle() * 65536.0 / TAU)) & 0xFFFF
	var angle := angle_q * TAU / 65536.0
	return Vector2(cos(angle), sin(angle)) * distance


static func quantize_input(input: Node) -> void:
	input.cursor_offset = quantize_cursor_offset(input.cursor_offset)


static func can_pack(properties: Array) -> bool:
	if properties.size() != EXPECTED_ORDER.size():
		return false
	for index in properties.size():
		if properties[index].to_string() != EXPECTED_ORDER[index]:
			return false
	return true


## Pack the RedundantHistoryEncoder's flat snapshots plus trailing version.
static func pack(data: Array, properties: Array) -> Array:
	if data.is_empty() or not can_pack(properties):
		return data
	var property_count := EXPECTED_ORDER.size()
	var snapshot_count := (data.size() - 1) / property_count
	if snapshot_count <= 0 or snapshot_count > 255 \
			or (data.size() - 1) % property_count != 0:
		return data
	var bytes := PackedByteArray()
	bytes.resize(4 + snapshot_count * SNAPSHOT_BYTES)
	bytes[0] = MAGIC
	bytes[1] = FORMAT_VERSION
	bytes[2] = int(data[-1]) & 0xFF
	bytes[3] = snapshot_count
	var offset := 4
	for snapshot_index in snapshot_count:
		var base := snapshot_index * property_count
		var cursor: Vector2 = data[base]
		bytes.encode_u16(offset, int(roundf(cursor.angle() * 65536.0 / TAU)) & 0xFFFF)
		bytes.encode_u16(offset + 2,
			roundi(clampf(cursor.length(), 0.0, CURSOR_DISTANCE_MAX) * 100.0))
		var mask := 0
		for bool_index in BOOL_PROPS.size():
			var property_index := EXPECTED_ORDER.find(BOOL_PROPS[bool_index])
			if bool(data[base + property_index]):
				mask |= 1 << bool_index
		bytes.encode_u16(offset + 4, mask)
		offset += SNAPSHOT_BYTES
	return [bytes]


static func is_packed(data: Array) -> bool:
	return data.size() == 1 and data[0] is PackedByteArray \
		and (data[0] as PackedByteArray).size() >= 4 and data[0][0] == MAGIC


## Rebuild the exact flat Variant array expected by RedundantHistoryEncoder.
static func unpack(data: Array) -> Array:
	if not is_packed(data):
		return data
	var bytes := data[0] as PackedByteArray
	if bytes[1] != FORMAT_VERSION:
		return []
	var snapshot_count := int(bytes[3])
	if snapshot_count <= 0 or bytes.size() != 4 + snapshot_count * SNAPSHOT_BYTES:
		return []
	var property_count := EXPECTED_ORDER.size()
	var output := []
	output.resize(snapshot_count * property_count + 1)
	var offset := 4
	for snapshot_index in snapshot_count:
		var base := snapshot_index * property_count
		var angle := bytes.decode_u16(offset) * TAU / 65536.0
		var distance := bytes.decode_u16(offset + 2) / 100.0
		output[base] = Vector2.ZERO if distance <= 0.0 \
			else Vector2(cos(angle), sin(angle)) * distance
		var mask := bytes.decode_u16(offset + 4)
		for bool_index in BOOL_PROPS.size():
			var property_index := EXPECTED_ORDER.find(BOOL_PROPS[bool_index])
			output[base + property_index] = (mask & (1 << bool_index)) != 0
		offset += SNAPSHOT_BYTES
	output[snapshot_count * property_count] = int(bytes[2])
	return output
