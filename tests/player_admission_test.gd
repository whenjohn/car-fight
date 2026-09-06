extends SceneTree

class AdmissionMarker extends Node:
	var admission_required := true

class AdmissionServerPeer extends MultiplayerPeerExtension:
	var disconnected: Array[int] = []
	func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
		return MultiplayerPeer.CONNECTION_CONNECTED
	func _get_unique_id() -> int:
		return 1
	func _is_server() -> bool:
		return true
	func _get_available_packet_count() -> int:
		return 0
	func _poll() -> void:
		pass
	func _disconnect_peer(peer_id: int, _force: bool) -> void:
		disconnected.append(peer_id)

var _failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	var clock := root.get_node("NetworkTime")
	clock.stop()
	var body = main._spawn_player({"id": 42, "slot": 1,
		"remote_generation": 700, "admission_required": true})
	main._players.add_child(body)
	await process_frame
	_check(not body.visible, "waiting vehicle is hidden")
	_check(body.freeze and body.collision_layer == 0 and body.collision_mask == 0,
		"waiting vehicle cannot participate in physics")
	if main.has_method("_admission_spawn_clear"):
		_check(main._admission_spawn_clear(body), "ordinary spawn is clear")
		var other: Node3D = main.local_player()
		var other_position := other.position
		other.position = body.position
		_check(not main._admission_spawn_clear(body), "occupied spawn cannot activate")
		other.position = other_position
		var reserved = main._spawn_player({"id": 43, "slot": 1,
			"remote_generation": 702, "admission_required": true})
		main._players.add_child(reserved)
		reserved.activate_for_generation(702, 100)
		_check(not main._admission_spawn_clear(body), "next-tick admission reserves its spawn")
		reserved.free()
		_check(main._admission_spawn_clear(body), "vacated spawn becomes available")
	else:
		_check(false, "admission checks spawn occupancy")
	var input: Node = body.get_node("Input")
	input.set("editing", false)
	input.set("homing_held", true)
	input.set("rc_fire_held", true)
	main._service_homing_missiles(100)
	main._service_rc_orbs(0.0, 100)
	_check(main._combat_shot_count == 0 and main._rc_shot_count == 0,
		"non-neutral client intent cannot fire from a waiting vehicle")
	var start: Vector3 = body.global_position - Vector3.RIGHT * 5.0
	var finish: Vector3 = body.global_position + Vector3.RIGHT * 5.0
	_check(main._segment_player_entry(start, finish, body) > 1.0,
		"waiting vehicle is excluded from projectile sweeps")
	body.apply_external_impact(Vector3.ONE, Vector3.ONE, 1.0, false)
	_check(body._pending_impact_hits == 0, "waiting vehicle rejects external impacts")
	var dot_id := 9999
	main._dots._dots = {dot_id: body.global_position}
	main._dots._on_tick(0.016, 100)
	_check(main._dots._dots.has(dot_id), "waiting vehicle cannot collect a pickup")
	var original_position: Vector3 = body.position
	body.position = main._troop_delivery.SOURCE_POSITION
	main._troop_delivery._service_source(1.0)
	_check(main._troop_delivery._troops.is_empty(), "waiting vehicle cannot recruit troops")
	body.position = main._troop_delivery.DESTINATION_POSITION
	main._troop_delivery._carried[42] = 3
	input.set("drop_troops", true)
	main._troop_delivery._service_deploy(1.0)
	_check(main._troop_delivery.carried_by(42) == 3, "waiting vehicle cannot deploy troops")
	body.position = original_position
	var indicators = load("res://ui/offscreen_indicators.gd").new()
	root.add_child(indicators)
	indicators.setup(main, null)
	for item in indicators._collect(0.016):
		_check(item["id"] != 42, "waiting vehicle has no offscreen marker")
	indicators.free()
	main._editor_stage = MeshInstance3D.new()
	main.add_child(main._editor_stage)
	for editing in [true, false]:
		main._combat_editor_active = editing
		main._update_editor_presentation(main.local_player())
		_check(not body.visible, "editor transitions cannot reveal a waiting vehicle")
	if body.has_method("activate_for_generation"):
		_check(not body.activate_for_generation(699, 100), "stale activation is rejected")
		_check(not body.activate_for_generation(700, -1), "invalid activation tick is rejected")
		_check(body.activate_for_generation(700, 100), "matching server activation accepted")
		_check(not body.activate_for_generation(700, 101), "duplicate cannot move activation tick")
		_check(not body.gameplay_active(99) and body.gameplay_active(100),
			"activation is derived from the simulated tick")
		body._apply_admission_physics(99)
		_check(body.freeze and body.collision_layer == 0, "replay before activation stays inert")
		body._apply_admission_physics(100)
		_check(not body.freeze and body.collision_layer == 1 and body.collision_mask == 1,
			"activation restores ordinary physics")
		body._apply_admission_physics(99)
		_check(body.freeze and body.collision_mask == 0, "rewind removes physics participation again")
	else:
		_check(false, "server activation contract exists")
	var replacement = main._spawn_player({"id": 42, "slot": 1,
		"remote_generation": 701, "admission_required": true})
	main._players.add_child(replacement)
	main._apply_player_activation(42, 700, 0)
	_check(replacement.activation_tick == -1, "old event cannot admit a same-ID replacement")
	root.get_node("NetworkEvents").enabled = false
	multiplayer_poll = false
	var peer := AdmissionServerPeer.new()
	root.multiplayer.multiplayer_peer = peer
	main._server_admission_enabled = true
	main._expire_player_admissions()
	_check(peer.disconnected.is_empty(), "fresh pending body is not expired")
	replacement.admission_started_msec = Time.get_ticks_msec() - 45000
	main._expire_player_admissions()
	_check(peer.disconnected == [42], "server retires an expired pending peer")
	peer.disconnected.clear()
	for index in range(15):
		var marker := AdmissionMarker.new()
		marker.name = "Capacity_%d" % index
		main._players.add_child(marker)
	main._on_peer_join(99)
	_check(peer.disconnected == [99], "admission cap includes waiting and active clients across transports")
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main._apply_player_activation(42, 701, 0)
	var partner = main._spawn_player({"id": 43, "slot": 2,
		"remote_generation": 703, "admission_required": true})
	main._players.add_child(partner)
	main._scripted = "converge"
	_check(main.scripted_input_for(replacement)["cursor_offset"] == Vector2.ZERO,
		"head-on fixture waits for both admitted cars before starting its collision scenario")
	partner.activate_for_generation(703, 0)
	_check(main.scripted_input_for(replacement)["cursor_offset"] != Vector2.ZERO,
		"head-on fixture starts once both cars can collide")
	partner.free()
	main._scripted = ""
	replacement._process(0.016)
	_check(replacement.visible, "activation reveals the remote vehicle during normal play")
	main._combat_editor_active = true
	replacement._admission_presented = false
	replacement._process(0.016)
	_check(not replacement.visible, "activation respects the observer's editor view")
	main.free()
	if not _failed:
		print("PLAYER_ADMISSION_TEST PASS")
	quit(1 if _failed else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("PLAYER_ADMISSION_TEST FAIL: %s" % message)
		_failed = true
