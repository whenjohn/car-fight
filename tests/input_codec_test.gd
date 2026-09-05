extends SceneTree

const CODEC := preload("res://net/input_codec.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Exercise the production factory and _ready registration, without opening sockets.
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._role = "server"
	var body: Node = main._spawn_player({"id": 2})
	main._players.add_child(body)
	main._role = "offline"
	await process_frame
	var sync = body.get_node("RollbackSynchronizer")
	var properties: Array[PropertyEntry] = sync._input_property_config.get_properties_owned_by(2)
	_check(properties.size() == 14, "live player registers all 14 inputs")
	_check(CODEC.can_pack(properties), "codec supports the live registered player schema")
	if not CODEC.can_pack(properties):
		_finish(main)
		return
	var snapshot := []
	for property in properties:
		snapshot.append(property.get_value())
	snapshot[0] = Vector2(12.345, -7.891)
	var wire := snapshot.duplicate()
	wire.append(9)
	var packed: Array = CODEC.pack(wire, properties)
	_check(CODEC.is_packed(packed), "packed payload is recognized")
	_check((packed[0] as PackedByteArray).size() == 4 + CODEC.SNAPSHOT_BYTES,
		"one snapshot uses the fixed wire size")
	_check(packed[0][1] == 2, "changed bit layout uses version 2")
	var unpacked := CODEC.unpack(packed, properties)
	_check(unpacked.size() == wire.size() and int(unpacked[-1]) == 9,
		"snapshot count and encoder version round-trip")
	_check((unpacked[0] as Vector2).distance_to(
		CODEC.quantize_cursor_offset(snapshot[0])) < 0.0002,
		"cursor command round-trips on the source quantization grid")
	for index in range(1, properties.size()):
		_check(unpacked[index] == snapshot[index],
			"control %s round-trips" % properties[index])
	var wrong_properties := properties.duplicate()
	wrong_properties.pop_back()
	_check(CODEC.pack(wire, wrong_properties) == wire,
		"unknown input surfaces fall back to legacy Variants")
	_check(CODEC.unpack(packed, wrong_properties).is_empty(), "receiver schema mismatch rejects")
	var swapped := properties.duplicate()
	swapped[11] = properties[12]
	swapped[12] = properties[11]
	_check(CODEC.pack(wire, swapped) == wire, "reordered send schema falls back")
	_check(CODEC.unpack(packed, swapped).is_empty(), "reordered receive schema rejects")
	_check(CODEC.unpack(wire, properties) == wire, "legacy Variants pass through unchanged")
	_test_controls(properties)
	_test_history(properties, body)
	_test_malformed(packed, wire, properties)
	_test_routing(wire, properties, wrong_properties, sync._history_transmitter)
	_finish(main)


func _test_controls(properties: Array[PropertyEntry]) -> void:
	# Every mask, using the registered properties rather than the codec's own list.
	for mask in range(1 << (properties.size() - 1)):
		var wire := [Vector2.ZERO]
		for index in range(1, properties.size()):
			wire.append((mask & (1 << (index - 1))) != 0)
		wire.append(255)
		var packed := CODEC.pack(wire, properties)
		_check(CODEC.unpack(packed, properties) == wire, "all control combinations: %d" % mask)
	# Pin the wire meaning separately from the implementation's BOOL_PROPS list.
	var bit_positions := {"drop_troops": 10, "tractor": 11, "editing": 12}
	for control in bit_positions:
		var wire := [Vector2.ZERO]
		for index in range(1, properties.size()):
			wire.append(properties[index].property == control)
		wire.append(0)
		var packed := CODEC.pack(wire, properties)
		var bit: int = bit_positions[control]
		_check(packed[0].decode_u16(8) == 1 << bit, "version 2 bit assignment: %s" % control)
	for cursor in [Vector2.ZERO, Vector2(0.001, 0), Vector2(-20, 0),
			Vector2(0, -12), Vector2(900, 0), Vector2(12.345, -7.891)]:
		var wire := [cursor]
		for index in range(1, properties.size()):
			wire.append(false)
		wire.append(0)
		var decoded := CODEC.unpack(CODEC.pack(wire, properties), properties)
		_check(decoded[0].distance_to(CODEC.quantize_cursor_offset(cursor)) < 0.0002,
			"cursor boundary round-trip: %s" % cursor)


func _test_history(properties: Array[PropertyEntry], body: Node) -> void:
	var cache := PropertyCache.new(body)
	# Load after autoloads initialize; these netfox scripts reference their singletons.
	var history = load("res://addons/netfox/properties/property-history-buffer.gd").new()
	var receiver_history = load("res://addons/netfox/properties/property-history-buffer.gd").new()
	var encoder = load("res://addons/netfox/encoder/redundant-history-encoder.gd").new(history, cache)
	var decoder = load("res://addons/netfox/encoder/redundant-history-encoder.gd").new(receiver_history, cache)
	encoder.set_properties(properties)
	encoder.redundancy = 3
	var tick: int = root.get_node("NetworkRollback").history_start + 8
	for age in range(3):
		var snapshot := _PropertySnapshot.new()
		for property in properties:
			snapshot.set_value(property.to_string(), Vector2.ZERO if property.property == "cursor_offset"
				else (property.property == ["drop_troops", "tractor", "editing"][age]))
		history.set_snapshot(tick - age, snapshot)
	var wire: Array = encoder.encode(tick, properties)
	var packed := CODEC.pack(wire, properties)
	_check(packed[0].size() == 22, "three redundant snapshots use 22 payload bytes")
	var decoded: Array = decoder.decode(CODEC.unpack(packed, properties), properties)
	_check(decoded.size() == 3, "netfox decodes all redundant snapshots")
	_check(decoder.apply(tick, decoded, 2) == tick - 2, "input owner passes netfox sanitization")
	for age in range(3):
		_check(receiver_history.get_snapshot(tick - age).equals(history.get_snapshot(tick - age)),
			"netfox history preserves controls and redundancy order: %d" % age)


func _test_malformed(packed: Array, wire: Array, properties: Array) -> void:
	var bytes: PackedByteArray = packed[0]
	_check(CODEC.unpack([bytes, 1], properties).is_empty(), "invalid packed envelope rejects")
	for length in range(bytes.size()):
		_check(CODEC.unpack([bytes.slice(0, length)], properties).is_empty(),
			"truncated payload rejects at byte %d" % length)
	for version in [0, 1, 3, 99, 255]:
		var bad := bytes.duplicate()
		bad[1] = version
		_check(CODEC.unpack([bad], properties).is_empty(), "incompatible version %d rejects" % version)
	for change in [[0, 0], [3, 0], [3, 2], [9, 128]]:
		var bad := bytes.duplicate()
		bad[change[0]] = change[1]
		_check(CODEC.unpack([bad], properties).is_empty(), "bad magic/count/reserved mask rejects")
	var extended := bytes.duplicate()
	extended.append(0)
	_check(CODEC.unpack([extended], properties).is_empty(), "trailing bytes reject")
	_check(CODEC.pack([], properties).is_empty(), "empty input stays empty")
	_check(CODEC.unpack([], properties).is_empty(), "empty receive stays empty")
	for change in [[0, Vector3.ZERO], [0, Vector2(INF, 0)], [0, Vector2(NAN, 0)],
			[1, 1], [-1, -1], [-1, 256], [-1, "1"]]:
		var bad := wire.duplicate()
		bad[change[0]] = change[1]
		_check(not CODEC.is_packed(CODEC.pack(bad, properties)), "invalid values fall back without coercion")
	var incomplete := wire.duplicate()
	incomplete.pop_front()
	_check(CODEC.pack(incomplete, properties) == incomplete, "partial snapshot falls back")
	var limit := []
	for index in range(255):
		limit.append_array(wire.slice(0, -1))
	limit.append(0)
	_check(CODEC.unpack(CODEC.pack(limit, properties), properties).size() == limit.size(),
		"maximum snapshot count round-trips")
	limit.pop_back()
	limit.append_array(wire.slice(0, -1))
	limit.append(0)
	_check(CODEC.pack(limit, properties) == limit, "too many snapshots fall back")


func _test_routing(wire: Array, properties: Array, wrong: Array, transmitter: Node) -> void:
	var bundle = root.get_node("StateBundle")
	var before: Dictionary = bundle.input_codec_stats.duplicate()
	_check(bundle.pack_input(wire, properties, 2) == wire, "disabled packing preserves legacy wire")
	_check(bundle.input_codec_stats == before, "disabled send does not count a fallback")
	bundle.input_packing = true
	var packed: Array = bundle.pack_input(wire, properties, 2)
	var fallback: Array = bundle.pack_input(wire, wrong, 2)
	_check(bundle.input_codec_stats.packed == before.packed + 1, "counts actual packed attempts")
	_check(bundle.input_codec_stats.fallbacks == before.fallbacks + 1, "counts schema fallbacks")
	_check(bundle.input_codec_stats.encoded_bytes == before.encoded_bytes
		+ var_to_bytes(packed).size() + var_to_bytes(fallback).size(), "counts actual encoded bytes")
	_check(transmitter._input_backpressure_bytes(packed) == 4096, "packed wire gets packed threshold")
	_check(transmitter._input_backpressure_bytes(fallback) == 16384, "fallback gets Variant threshold")
	bundle.input_packing = false
	_check(bundle.unpack_input(packed, properties).size() == wire.size(), "receiver ignores send flag")
	_check(bundle.input_codec_stats.received == before.received + 1, "counts valid packed receives")
	_check(bundle.unpack_input([PackedByteArray([0])], properties).is_empty(), "wrapper rejects malformed bytes")
	_check(bundle.input_codec_stats.rejects == before.rejects + 1, "counts malformed receives")
	# Keep existing mux recipient policy: native server broadcasts use Variants.
	bundle.input_packing = true
	bundle.set_peer_transport_provider(func(peer: int): return "enet" if peer == 2 else "webrtc")
	_check(bundle.pack_input(wire, properties, 2) == wire, "mux ENet recipient retains legacy policy")
	_check(CODEC.is_packed(bundle.pack_input(wire, properties, 3)), "mux WebRTC recipient packs")
	bundle.set_peer_transport_provider(Callable())
	bundle.input_packing = false


func _finish(main: Node) -> void:
	main.free()
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
