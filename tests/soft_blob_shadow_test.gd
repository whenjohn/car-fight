extends SceneTree

const SOFT_BLOB_SHADOW := preload("res://fx/soft_blob_shadow.gd")
const SOFT_BLOB_SHADER := preload("res://fx/soft_blob_shadow.gdshader")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var body := Node3D.new()
	body.position = Vector3(3.0, 1.6, -4.0)
	root.add_child(body)
	var blob := MeshInstance3D.new()
	blob.set_script(SOFT_BLOB_SHADOW)
	body.add_child(blob)
	await process_frame
	_check(blob.top_level, "contact shadow is independent of body roll and pitch")
	_check(blob.global_position.is_equal_approx(Vector3(3.0, 0.045, -4.0)),
		"contact shadow follows the vehicle on the ground plane")
	body.position = Vector3(-8.0, 3.0, 11.0)
	await process_frame
	_check(blob.global_position.is_equal_approx(Vector3(-8.0, 0.045, 11.0)),
		"contact shadow follows subsequent vehicle motion")
	_check(SOFT_BLOB_SHADER is Shader, "soft radial shadow shader loads")
	body.free()
	print("SOFT_BLOB_SHADOW_TEST PASS")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("SOFT_BLOB_SHADOW_TEST FAIL: %s" % message)
	quit(1)
