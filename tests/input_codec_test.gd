extends SceneTree

const CODEC := preload("res://net/input_codec.gd")

class FakeProperty extends RefCounted:
	var path := ""
	func _init(value: String) -> void:
		path = value
	func _to_string() -> String:
		return path

var _failed := false


func _init() -> void:
	var properties := []
	for path in CODEC.EXPECTED_ORDER:
		properties.append(FakeProperty.new(path))
	var snapshot := [Vector2(12.345, -7.891)]
	for index in CODEC.BOOL_PROPS.size():
		snapshot.append(index % 3 == 0)
	var wire := snapshot.duplicate()
	wire.append(9)
	var packed: Array = CODEC.pack(wire, properties)
	_check(CODEC.is_packed(packed), "packed payload is recognized")
	_check((packed[0] as PackedByteArray).size() == 4 + CODEC.SNAPSHOT_BYTES,
		"one snapshot uses the fixed wire size")
	var unpacked := CODEC.unpack(packed)
	_check(unpacked.size() == wire.size() and int(unpacked[-1]) == 9,
		"snapshot count and encoder version round-trip")
	_check((unpacked[0] as Vector2).distance_to(
		CODEC.quantize_cursor_offset(snapshot[0])) < 0.0002,
		"cursor command round-trips on the source quantization grid")
	for index in CODEC.BOOL_PROPS.size():
		_check(bool(unpacked[index + 1]) == bool(snapshot[index + 1]),
			"control bit %d round-trips" % index)
	var wrong_properties := properties.duplicate()
	wrong_properties.pop_back()
	_check(CODEC.pack(wire, wrong_properties) == wire,
		"unknown input surfaces fall back to legacy Variants")
	var malformed_bytes := (packed[0] as PackedByteArray).duplicate()
	malformed_bytes[1] = 99
	var malformed := [malformed_bytes]
	_check(CODEC.unpack(malformed).is_empty(), "version mismatch rejects")
	if _failed:
		quit(1)
	else:
		print("INPUT_CODEC_TEST PASS")
		quit()


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	push_error("INPUT_CODEC_TEST FAIL: %s" % label)
	_failed = true
