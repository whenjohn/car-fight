extends SceneTree

const STATE_CODEC := preload("res://net/state_codec.gd")
const SAMPLES := 11

class RouteProxy extends Node:
	var route_id := 0

# An in-memory link captures real SceneMultiplayer serialization and path-cache
# negotiation. It deliberately does not model ENet, SCTP, encryption or loss.
class ProbePeer extends MultiplayerPeerExtension:
	var local_id := 1
	var partner: WeakRef
	var incoming: Array[Dictionary] = []
	var sent: Array[Dictionary] = []
	var mode := MultiplayerPeer.TRANSFER_MODE_RELIABLE
	var channel := 0
	var closed := false

	func _put_packet_script(data: PackedByteArray) -> Error:
		var packet := {"data": data.duplicate(), "mode": mode, "channel": channel}
		sent.append(packet)
		partner.get_ref().incoming.append(packet)
		return OK

	func _get_packet_script() -> PackedByteArray:
		return incoming.pop_front().data

	func _get_available_packet_count() -> int:
		return incoming.size()

	func _get_packet_peer() -> int:
		return 3 - local_id

	func _get_packet_channel() -> int:
		return 0 if incoming.is_empty() else int(incoming[0].channel)

	func _get_packet_mode() -> MultiplayerPeer.TransferMode:
		return MultiplayerPeer.TRANSFER_MODE_RELIABLE if incoming.is_empty() else incoming[0].mode

	func _set_target_peer(_peer: int) -> void:
		pass

	func _set_transfer_channel(value: int) -> void:
		channel = value

	func _get_transfer_channel() -> int:
		return channel

	func _set_transfer_mode(value: MultiplayerPeer.TransferMode) -> void:
		mode = value

	func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
		return mode

	func _get_unique_id() -> int:
		return local_id

	func _get_max_packet_size() -> int:
		return 16777216

	func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
		return MultiplayerPeer.CONNECTION_DISCONNECTED if closed else MultiplayerPeer.CONNECTION_CONNECTED

	func _is_server() -> bool:
		return local_id == 1

	func _is_server_relay_supported() -> bool:
		return true

	func _poll() -> void:
		pass

	func _close() -> void:
		closed = true
		incoming.clear()

var _failed := false
var _server: Dictionary
var _client: Dictionary
var _main: Node
var _templates := {}
var _rows: Array[Dictionary] = []
var _schemas := {}
var _route_roots: Array[Node] = []
var _last_capture_usec := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_main = load("res://Main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main
	await process_frame
	root.get_node("NetworkEvents").enabled = false
	multiplayer_poll = false
	_main._role = "server"
	var player: Node = _main._spawn_player({"id": 2})
	_main._players.add_child(player)
	var ball: Node = _main._spawn_ball({"name": "CityBall"})
	var existing_ball: Node = _main._balls.get_node_or_null("CityBall")
	if existing_ball != null:
		_main._balls.remove_child(existing_ball)
		existing_ball.free()
	_main._balls.add_child(ball)
	var prop: Node = _main._spawn_scatter_prop({"name": "100", "kind": "crate", "route_id": -100, "position": Vector2(20, 0)})
	_main._scatter_props.add_child(prop)
	_main._role = "offline"
	await process_frame
	root.get_node("NetworkTime").stop()
	for entry in [["player", player, 34], ["ball", ball, 1], ["prop", prop, 1]]:
		_templates[entry[0]] = _encode_schema(entry[0], entry[1], entry[2])
	_server = _side("PacketServer", 1)
	_client = _side("PacketClient", 2)
	_server.peer.partner = weakref(_client.peer)
	_client.peer.partner = weakref(_server.peer)
	_server.peer.peer_connected.emit(2)
	_client.peer.peer_connected.emit(1)
	_pump()
	_make_routes()
	root.get_node("NetworkPerformance").set_app_telemetry_enabled(true)
	var sampled: Array = _server.pose._sample_bodies()
	var template: Dictionary = sampled.filter(func(sample): return sample.id == 2)[0]
	for count in [2, 4, 8, 16, 32, 64]:
		_measure_pose(count, template)
	for players in [2, 4, 8, 16]:
		for props in [0, 16, 64]:
			for packed in [false, true]:
				for state in ["physics_diff", "all_fields_diff", "full_key"]:
					_measure_bundle(players, props, packed, state)
	_measure_pressure()
	_write_report()
	_finish()


func _encode_schema(label: String, body: Node, expected_count: int) -> Dictionary:
	var sync = body.get_node("RollbackSynchronizer")
	var properties: Array[PropertyEntry] = sync._state_property_config.get_properties_owned_by(1)
	_check(properties.size() == expected_count, "%s live schema changed; review the size baseline" % label)
	_schemas[label] = properties.map(func(property): return property.property)
	var history = load("res://addons/netfox/properties/property-history-buffer.gd").new()
	var cache := PropertyCache.new(body)
	var full = load("res://addons/netfox/encoder/snapshot-history-encoder.gd").new(history, cache)
	var diff = load("res://addons/netfox/encoder/diff-history-encoder.gd").new(history, cache)
	full.set_properties(properties)
	diff.add_properties(properties)
	for tick in [100, 101, 102]:
		var snapshot := _PropertySnapshot.new()
		for property in properties:
			var value: Variant = property.get_value()
			if property.property == "physics_state":
				value = [Vector3(10.0 + tick - 100, 1, 5), Quaternion.IDENTITY,
					Vector3(4, 0, -2), Vector3(0, 0.5, 0), false]
			elif tick == 102:
				match typeof(value):
					TYPE_BOOL: value = not value
					TYPE_INT: value += 1
					TYPE_FLOAT: value += 0.25
					_: _check(false, "new scalar type needs a representative changing value")
			snapshot.set_value(property.to_string(), value)
		history.set_snapshot(tick, snapshot)
	var result := {"full_key": full.encode(102, properties),
		"physics_diff": diff.encode(101, 100, properties),
		"all_fields_diff": diff.encode(102, 100, properties)}
	_check(full.decode(result.full_key.duplicate(true), properties).equals(history.get_snapshot(102)),
		"%s full snapshot comes from the real encoder" % label)
	return result


func _make_routes() -> void:
	for group in ["Players", "Balls", "ScatterProps"]:
		var parent := Node.new()
		parent.name = group
		_server.root.add_child(parent)
		var count := 16 if group == "Players" else (1 if group == "Balls" else 64)
		for index in range(count):
			var proxy := RouteProxy.new()
			proxy.name = "CityBall" if group == "Balls" else str(index + 2)
			proxy.route_id = -100 - index
			parent.add_child(proxy)
			_route_roots.append(proxy)


func _measure_pose(count: int, template: Dictionary) -> void:
	var samples := []
	var by_id := {}
	for index in range(count):
		var sample := template.duplicate(true)
		sample.id = index + 2
		samples.append(sample)
		by_id[sample.id] = sample
	for mode in ["batch", "legacy"]:
		var call_send := func():
			if mode == "batch":
				_server.pose._send_relevant_batch(2, 300, 24001, samples, {0: samples}, by_id)
			else:
				_server.pose._send_legacy(2, 300, 24001, samples)
		var row := _measure(call_send)
		row.merge({"category": "pose_" + mode, "players": count, "props": 0,
			"body_cap_stress_only": count > 16, "projected_recipients": count})
		_check(row.rpc_messages == (1 if mode == "batch" else count), "pose dispatch count follows actual production path")
		row["all_recipient_rpc_bytes_projection"] = row.rpc_bytes * count
		_rows.append(row)
		print("PACKET_SIZE ", JSON.stringify(row))


func _measure_bundle(players: int, props: int, packed: bool, state: String, under_pressure := false) -> void:
	var bundle = _server.bundle
	bundle._enabled = true
	bundle.state_packing = packed
	var tick := 24000 if state == "full_key" else 24001
	var kind: int = bundle.FULL if state == "full_key" else bundle.DIFF
	var entries := []
	for index in range(players + 1 + props):
		var label := "player" if index < players else ("ball" if index == players else "prop")
		var route_index := index if index < players else (16 if index == players else 17 + index - players - 1)
		var payload: Variant = _templates[label][state]
		payload = bundle.pack_state_full(payload, 2) if kind == bundle.FULL else bundle.pack_state_diff(payload, PackedByteArray(), 2)
		entries.append({"root": _route_roots[route_index], "payload": payload})
	var call_send := func():
		for entry in entries:
			_check(bundle.queue_state(2, tick, entry.root, kind, entry.payload, -1 if kind == bundle.FULL else tick - 1),
				"production bundler accepts registered route shape")
		bundle._flush_tick(tick)
	var row := _measure(call_send)
	row.merge({"category": state, "players": players, "balls": 1, "props": props, "packed_state": packed,
		"under_queue_pressure": under_pressure, "all_recipient_rpc_bytes_projection": row.rpc_bytes * players})
	_check(row.rpc_messages == (2 if kind == bundle.FULL else 1), "key includes reliable copy plus ordinary mirror")
	_check(_client.bundle.received.size() == row.rpc_messages, "real RPC decoder receives every envelope")
	for received in _client.bundle.received:
		_check(received.routes == entries.size() and received.sender == 1, "decoded bundle retains routes and authority")
	if kind == bundle.FULL:
		_check(row.modes == [MultiplayerPeer.TRANSFER_MODE_RELIABLE, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED],
			"recovery key transfer modes remain unchanged")
	_rows.append(row)
	print("PACKET_SIZE ", JSON.stringify(row))


func _measure(send: Callable) -> Dictionary:
	var initial := _capture(send)
	var times: Array[int] = []
	var packets := []
	var performance := root.get_node("NetworkPerformance")
	for index in range(SAMPLES):
		performance._reset_app_telemetry_window()
		_client.bundle.received.clear()
		packets = _capture(send)
		times.append(_last_capture_usec)
	var sizes := packets.map(func(packet): return packet.bytes)
	times.sort()
	return {"rpc_messages": packets.size(), "rpc_max_bytes": sizes.max(),
		"rpc_bytes": sizes.reduce(func(total, size): return total + size, 0),
		"first_dispatch_rpc_max_bytes": initial.map(func(packet): return packet.bytes).max(),
		"modes": packets.map(func(packet): return packet.mode),
		"dispatch_p50_usec": times[SAMPLES / 2], "dispatch_max_usec": times[-1],
		"logical_maxima": performance.get_app_telemetry_snapshot(24001).payload_max_bytes,
		"logical_bundle_maxima": performance.get_app_telemetry_snapshot(24001).bundle_max_bytes}


func _measure_pressure() -> void:
	_server.bundle.set_send_pressure_provider(func(_peer): return 65537)
	_server.peer.sent.clear()
	_server.bundle.queue_state(2, 24001, _route_roots[0], _server.bundle.DIFF, _templates.player.physics_diff, 24000)
	_server.bundle._flush_tick(24001)
	_check(_server.peer.sent.is_empty(), "ordinary state drops under the existing queue-pressure guard")
	_measure_bundle(16, 64, false, "full_key", true)
	_server.bundle.set_send_pressure_provider(Callable())
	_check(STATE_CODEC.pack_fallbacks == 0 and STATE_CODEC.rejects == 0, "real state schema never silently falls back or rejects")


func _write_report() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--packet-size-report="):
			var file := FileAccess.open(arg.trim_prefix("--packet-size-report="), FileAccess.WRITE)
			_check(file != null, "report file opens")
			if file != null:
				file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "schemas": _schemas,
					"scope": "in-memory real RPC encoding, not transport fragmentation or live-player load", "rows": _rows}, "\t"))


func _side(node_name: String, local_id: int) -> Dictionary:
	var branch := Node.new()
	branch.name = node_name
	root.add_child(branch)
	var api := SceneMultiplayer.new()
	api.root_path = branch.get_path()
	set_multiplayer(api, branch.get_path())
	var peer := ProbePeer.new()
	peer.local_id = local_id
	api.multiplayer_peer = peer
	var pose = load("res://net/remote_position_transport.gd").new()
	pose.name = "RemoteState"
	branch.add_child(pose)
	var bundle = load("res://net/state_bundle.gd" if local_id == 1 else "res://tests/network_packet_bundle_sink.gd").new()
	bundle.name = "StateBundle"
	branch.add_child(bundle)
	return {"root": branch, "api": api, "peer": peer, "pose": pose, "bundle": bundle}


func _pump() -> void:
	for index in range(8):
		_server.api.poll()
		_client.api.poll()
	_check(_server.peer.incoming.is_empty() and _client.peer.incoming.is_empty(), "probe link drains")


func _capture(send: Callable) -> Array:
	_server.peer.sent.clear()
	var started := Time.get_ticks_usec()
	send.call()
	_last_capture_usec = Time.get_ticks_usec() - started
	_pump()
	var packets := []
	for packet in _server.peer.sent:
		# Godot 4.7 SceneMultiplayer command mask: low 3 bits, RPC command = 0.
		if not packet.data.is_empty() and (packet.data[0] & 7) == 0:
			packets.append({"bytes": packet.data.size(), "mode": packet.mode})
	_check(not packets.is_empty(), "production RPC dispatch reaches the capture peer")
	return packets


func _finish() -> void:
	root.get_node("NetworkPerformance").set_app_telemetry_enabled(false)
	for side in [_server, _client]:
		side.peer.close()
		side.api.multiplayer_peer = null
		set_multiplayer(null, side.root.get_path())
		side.root.free()
	_main.free()
	print("NETWORK_PACKET_SIZE_TEST %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr("FAIL: %s" % message)
