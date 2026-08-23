extends SceneTree

const MOTION_TRACE := preload("res://diagnostics/motion_trace.gd")

class FakeMain extends Node:
	var local: Node3D
	func local_player() -> Node3D:
		return local
	func motion_trace_context() -> Dictionary:
		return {"run_id": "motion-trace-test", "tick": 10, "fps": 60.0}

class FakeRemote extends RigidBody3D:
	var shown_position := Vector3.ZERO
	func presented_position() -> Vector3:
		return shown_position

func _init() -> void:
	var steady := MOTION_TRACE.bounded_expected_velocity(
		Vector2(18.0, 0.0), Vector2(18.0, 0.0), 1.0 / 60.0)
	if steady.distance_to(Vector2(18.0, 0.0)) > 0.0001:
		push_error("MOTION_TRACE_TEST FAIL: steady motion changed the expected velocity")
		quit(1)
		return
	var bounded := MOTION_TRACE.bounded_expected_velocity(
		Vector2.ZERO, Vector2(100.0, 0.0), 1.0 / 60.0)
	if absf(bounded.length() - MOTION_TRACE.EXPECTED_ACCEL_LIMIT / 60.0) > 0.0001:
		push_error("MOTION_TRACE_TEST FAIL: high-frequency movement was not isolated")
		quit(1)
		return
	var normal := MOTION_TRACE.bounded_expected_velocity(
		Vector2.ZERO, Vector2(0.4, 0.0), 1.0 / 60.0)
	if normal.distance_to(Vector2(0.4, 0.0)) > 0.0001:
		push_error("MOTION_TRACE_TEST FAIL: normal acceleration was treated as anomaly")
		quit(1)
		return
	var fake_main := FakeMain.new()
	root.add_child(fake_main)
	var players := Node3D.new()
	fake_main.add_child(players)
	var local := Node3D.new()
	local.name = "3"
	players.add_child(local)
	fake_main.local = local
	var remote := FakeRemote.new()
	remote.name = "2"
	players.add_child(remote)
	var camera := Camera3D.new()
	fake_main.add_child(camera)
	var trace := Node.new()
	trace.set_script(MOTION_TRACE)
	fake_main.add_child(trace)
	trace.call("setup", fake_main, players, camera)
	trace.call("start_capture")
	trace.call("_process", 1.0 / 60.0)
	remote.shown_position = Vector3(0.3, 1.0, 0.0)
	trace.call("_process", 1.0 / 60.0)
	var graph := trace.get("_graph") as Control
	var plotted: Array = graph.get("_longitudinal") if graph != null else []
	if graph == null or plotted.size() != 1:
		push_error("MOTION_TRACE_TEST FAIL: presented movement did not reach the heartbeat graph")
		quit(1)
		return
	trace.call("stop_capture")
	print("MOTION_TRACE_TEST PASS")
	quit()
