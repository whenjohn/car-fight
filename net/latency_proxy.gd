extends Node
## Test-only UDP relay for measurable latency, jitter, reordering, and loss.

var listen_port := 10081
var server_host := "127.0.0.1"
var server_port := 10080
var latency_ms := 0
var jitter_ms := 0
var loss_pct := 0.0
var seed := 0xCA4F19
var telemetry_interval_ms := 1000

var _thread: Thread
var _loop := true
var _udp: PacketPeerUDP
var _client_peers := {}
var _client_to_server := []
var _server_to_client := []
var _rng := RandomNumberGenerator.new()
var _next_c2s_sequence := 0
var _next_s2c_sequence := 0
var _last_c2s_sequence := -1
var _last_s2c_sequence := -1
var _received_c2s := 0
var _received_s2c := 0
var _forwarded_c2s := 0
var _forwarded_s2c := 0
var _dropped_c2s := 0
var _dropped_s2c := 0
var _reordered_c2s := 0
var _reordered_s2c := 0
var _queue_high_c2s := 0
var _queue_high_s2c := 0
var _last_telemetry_msec := 0

class PacketEntry:
	var data: PackedByteArray
	var release_at: int
	var port: int
	var sequence: int

	func _init(packet_data: PackedByteArray, release_time: int, source_port: int,
			packet_sequence: int) -> void:
		data = packet_data
		release_at = release_time
		port = source_port
		sequence = packet_sequence

func start() -> void:
	latency_ms = maxi(0, latency_ms)
	jitter_ms = maxi(0, jitter_ms)
	loss_pct = clampf(loss_pct, 0.0, 100.0)
	telemetry_interval_ms = maxi(100, telemetry_interval_ms)
	_rng.seed = seed
	_udp = PacketPeerUDP.new()
	var error := _udp.bind(listen_port, "127.0.0.1")
	if error != OK:
		push_error("[proxy] bind :%d failed: %s" % [listen_port, error_string(error)])
		get_tree().quit(2)
		return
	print("[proxy] :%d -> %s:%d latency=%dms jitter=+/-%dms loss=%.2f%% seed=%d" % [listen_port, server_host, server_port, latency_ms, jitter_ms, loss_pct, seed])
	_last_telemetry_msec = Time.get_ticks_msec()
	_thread = Thread.new()
	_thread.start(_loop_packets)

func _loop_packets() -> void:
	while _loop:
		_pump()
		OS.delay_msec(1)

func _release_time(now: int) -> int:
	if jitter_ms <= 0:
		return now + latency_ms
	return now + maxi(0, latency_ms + _rng.randi_range(-jitter_ms, jitter_ms))

func _pump() -> void:
	var now := Time.get_ticks_msec()
	while _udp.get_available_packet_count() > 0:
		var packet := _udp.get_packet()
		if _udp.get_packet_error() != OK:
			continue
		var source_port := _udp.get_packet_port()
		if not _client_peers.has(source_port):
			var peer := PacketPeerUDP.new()
			peer.set_dest_address(server_host, server_port)
			_client_peers[source_port] = peer
		_received_c2s += 1
		_client_to_server.push_back(PacketEntry.new(packet, _release_time(now), source_port,
			_next_c2s_sequence))
		_next_c2s_sequence += 1
		_queue_high_c2s = maxi(_queue_high_c2s, _client_to_server.size())

	var keep_client := []
	for entry in _client_to_server:
		if now < entry.release_at:
			keep_client.push_back(entry)
		elif _passes(true):
			(_client_peers[entry.port] as PacketPeerUDP).put_packet(entry.data)
			_forwarded_c2s += 1
			if entry.sequence < _last_c2s_sequence:
				_reordered_c2s += 1
			_last_c2s_sequence = maxi(_last_c2s_sequence, entry.sequence)
	_client_to_server = keep_client

	for client_port in _client_peers.keys():
		var peer := _client_peers[client_port] as PacketPeerUDP
		while peer.get_available_packet_count() > 0:
			var packet := peer.get_packet()
			if peer.get_packet_error() == OK:
				_received_s2c += 1
				_server_to_client.push_back(PacketEntry.new(packet, _release_time(now), client_port,
					_next_s2c_sequence))
				_next_s2c_sequence += 1
				_queue_high_s2c = maxi(_queue_high_s2c, _server_to_client.size())

	var keep_server := []
	for entry in _server_to_client:
		if now < entry.release_at:
			keep_server.push_back(entry)
		elif _passes(false):
			_udp.set_dest_address("127.0.0.1", entry.port)
			_udp.put_packet(entry.data)
			_forwarded_s2c += 1
			if entry.sequence < _last_s2c_sequence:
				_reordered_s2c += 1
			_last_s2c_sequence = maxi(_last_s2c_sequence, entry.sequence)
	_server_to_client = keep_server

	if now - _last_telemetry_msec >= telemetry_interval_ms:
		_last_telemetry_msec = now
		_print_telemetry()

func _passes(client_to_server: bool) -> bool:
	var passed := loss_pct <= 0.0 or _rng.randf() >= loss_pct / 100.0
	if not passed:
		if client_to_server:
			_dropped_c2s += 1
		else:
			_dropped_s2c += 1
	return passed

func _print_telemetry() -> void:
	print("[proxy-stats] recv=%d/%d fwd=%d/%d drop=%d/%d reorder=%d/%d queue=%d/%d high=%d/%d clients=%d" % [
		_received_c2s, _received_s2c,
		_forwarded_c2s, _forwarded_s2c,
		_dropped_c2s, _dropped_s2c,
		_reordered_c2s, _reordered_s2c,
		_client_to_server.size(), _server_to_client.size(),
		_queue_high_c2s, _queue_high_s2c, _client_peers.size(),
	])

func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_loop = false
		_thread.wait_to_finish()
	_print_telemetry()
