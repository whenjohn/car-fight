extends SceneTree

const LOCAL_PRESENTATION := preload("res://player/local_presentation.gd")


func _init() -> void:
	var paused: Dictionary = LOCAL_PRESENTATION.advance(Transform3D.IDENTITY,
		Transform3D(Basis.IDENTITY, Vector3.ONE), Vector3.ZERO, Vector3.ZERO, 0.0)
	if bool(paused["snapped"]) or (paused["pose"] as Transform3D) != Transform3D.IDENTITY:
		_fail("zero-duration render callback was counted as a snap")
		return
	var target := Transform3D(Basis.IDENTITY, Vector3(1.0 / 6.0, 0.0, 0.0))
	var carried: Dictionary = LOCAL_PRESENTATION.advance(Transform3D.IDENTITY, target,
		Vector3(10.0, 0.0, 0.0), Vector3.ZERO, 1.0 / 60.0)
	if (carried["pose"] as Transform3D).origin.distance_to(target.origin) > 0.0001:
		_fail("constant-speed feed-forward introduced camera lag")
		return
	var reconciled: Dictionary = LOCAL_PRESENTATION.advance(Transform3D.IDENTITY,
		Transform3D(Basis.IDENTITY, Vector3(0.4, 0.0, 0.0)), Vector3.ZERO,
		Vector3.ZERO, LOCAL_PRESENTATION.POSITION_HALF_LIFE)
	var reconciled_x := (reconciled["pose"] as Transform3D).origin.x
	if bool(reconciled["snapped"]) or reconciled_x < 0.19 or reconciled_x > 0.21:
		_fail("ordinary correction did not decay by one half-life")
		return
	var teleported: Dictionary = LOCAL_PRESENTATION.advance(Transform3D.IDENTITY,
		Transform3D(Basis.IDENTITY, Vector3(LOCAL_PRESENTATION.SNAP_DISTANCE + 0.1,
			0.0, 0.0)), Vector3.ZERO, Vector3.ZERO, 1.0 / 60.0)
	if not bool(teleported["snapped"]) or \
			(teleported["pose"] as Transform3D).origin.x <= LOCAL_PRESENTATION.SNAP_DISTANCE:
		_fail("genuine teleport was hidden by local presentation")
		return
	print("LOCAL_PRESENTATION_TEST PASS")
	quit()


func _fail(message: String) -> void:
	push_error("LOCAL_PRESENTATION_TEST FAIL: %s" % message)
	quit(1)
