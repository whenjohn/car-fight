extends Node
## Small UDP relay used only by the headless latency gate.

var listen_port := 10081
var server_host := "127.0.0.1"
var server_port := 10080
var latency_ms := 0
var jitter_ms := 0
var loss_pct := 0.0

var _thread: Thread
var _loop := true
var _udp: PacketPeerUDP
var _client_peers := {}
var _client_to_server := []
var _server_to_client := []
var _rng := RandomNumberGenerator.new()

class PacketEntry:
	var data: PackedByteArray
	var release_at: int
	var port: int

	func _init(packet_data: PackedByteArray, release_time: int, source_port: int) -> void:
		data = packet_data
		release_at = release_time
		port = source_port

func start() -> void:
	_rng.seed = 0xCA4F19
	_udp = PacketPeerUDP.new()
	var error := _udp.bind(listen_port, "127.0.0.1")
	if error != OK:
		push_error("[proxy] bind :%d failed: %s" % [listen_port, error_string(error)])
		get_tree().quit(2)
		return
	print("[proxy] :%d -> %s:%d latency=%dms jitter=+/-%dms loss=%.1f%%" % [listen_port, server_host, server_port, latency_ms, jitter_ms, loss_pct])
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
		_client_to_server.push_back(PacketEntry.new(packet, _release_time(now), source_port))

	var keep_client := []
	for entry in _client_to_server:
		if now < entry.release_at:
			keep_client.push_back(entry)
		elif _passes():
			(_client_peers[entry.port] as PacketPeerUDP).put_packet(entry.data)
	_client_to_server = keep_client

	for client_port in _client_peers.keys():
		var peer := _client_peers[client_port] as PacketPeerUDP
		while peer.get_available_packet_count() > 0:
			var packet := peer.get_packet()
			if peer.get_packet_error() == OK:
				_server_to_client.push_back(PacketEntry.new(packet, _release_time(now), client_port))

	var keep_server := []
	for entry in _server_to_client:
		if now < entry.release_at:
			keep_server.push_back(entry)
		elif _passes():
			_udp.set_dest_address("127.0.0.1", entry.port)
			_udp.put_packet(entry.data)
	_server_to_client = keep_server

func _passes() -> bool:
	return loss_pct <= 0.0 or _rng.randf() >= loss_pct / 100.0

func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_loop = false
		_thread.wait_to_finish()

