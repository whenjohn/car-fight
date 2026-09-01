extends MeshInstance3D
## Render-only contact shadow used when realtime shadow maps are unsafe on the
## Intel macOS Vulkan/MoltenVK path. It follows the visual body but never enters
## physics, rollback, or network state.

const GROUND_Y := 0.045

var _body: Node3D


func _ready() -> void:
	_body = get_parent() as Node3D
	top_level = true
	_update_transform()


func _process(_delta: float) -> void:
	_update_transform()


func _update_transform() -> void:
	if _body == null:
		return
	global_position = Vector3(_body.global_position.x, GROUND_Y, _body.global_position.z)
	global_rotation = Vector3(0.0, _body.global_rotation.y, 0.0)
	visible = _body.visible
