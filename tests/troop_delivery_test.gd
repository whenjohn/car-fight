extends SceneTree

func _init() -> void:
	var source := FileAccess.get_file_as_string("res://world/troop_delivery.gd")
	var spawn_start := source.find("func _troop_spawn_local")
	var child_first := source.find("add_child(visual)", spawn_start)
	var position_after_child := source.find("visual.global_position", child_first)
	# Keep the contract focused and headless-safe; Main's parse gate compiles the
	# script after its NetworkTime autoload is active.
	if "const COLLECTION_RADIUS := 8.0" in source \
			and "const DROP_RADIUS := 9.0" in source \
			and "const EMIT_RATE := 3.0" in source \
			and "const DEPLOY_RATE := 4.0" in source \
			and spawn_start >= 0 and child_first > spawn_start \
			and position_after_child > child_first \
			and "Input.is_key_pressed(KEY_F)" in FileAccess.get_file_as_string("res://player/player_input.gd") \
			and not "RigidBody3D" in source and not "Area3D" in source:
		print("TROOP_DELIVERY_TEST PASS")
		quit(0)
		return
	push_error("TROOP_DELIVERY_TEST FAIL: pickup/drop radius contract is broken")
	quit(1)
