extends CanvasLayer
## Compatibility-safe local boost blur adapted from g2. It samples only the
## current frame, lives below the HUD, and owns no gameplay or network state.

const BOOST_BLUR_SHADER := preload("res://fx/boost_velocity_blur.gdshader")
const CONNECTION_STATE := preload("res://net/connection_state.gd")
const MIN_EFFECT_SPEED := 2.0
const FULL_EFFECT_SPEED := 18.0
const RISE_SPEED := 8.5
const FALL_SPEED := 5.5

var _players: Node
var _camera: Camera3D
var _material: ShaderMaterial
var _rect: ColorRect
var _strength := 0.0
var _last_direction := Vector2.RIGHT

func setup(players: Node, camera: Camera3D) -> void:
	_players = players
	_camera = camera

func _ready() -> void:
	layer = 5
	_rect = ColorRect.new()
	_rect.name = "BoostVelocityBlurRect"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_material = ShaderMaterial.new()
	_material.shader = BOOST_BLUR_SHADER
	_rect.material = _material
	_rect.visible = false
	add_child(_rect)

func _process(delta: float) -> void:
	var target_strength := 0.0
	var direction := _last_direction
	var local_player := _local_player()
	if local_player != null and _camera != null:
		var horizontal_velocity := Vector3(local_player.linear_velocity.x, 0.0,
			local_player.linear_velocity.z)
		var speed := horizontal_velocity.length()
		target_strength = effect_strength(bool(local_player.get("boost_active")), speed)
		if target_strength > 0.0:
			var screen_start := _camera.unproject_position(local_player.global_position)
			var screen_end := _camera.unproject_position(
				local_player.global_position + horizontal_velocity.normalized())
			var screen_motion := screen_end - screen_start
			if screen_motion.length_squared() > 0.0001:
				direction = screen_motion.normalized()
				_last_direction = direction
	var response := RISE_SPEED if target_strength > _strength else FALL_SPEED
	_strength = move_toward(_strength, target_strength, delta * response)
	_material.set_shader_parameter("motion_direction", direction)
	_material.set_shader_parameter("strength", _strength)
	_rect.visible = _strength > 0.002

static func effect_strength(boosting: bool, speed: float) -> float:
	if not boosting or speed <= MIN_EFFECT_SPEED:
		return 0.0
	return smoothstep(MIN_EFFECT_SPEED, FULL_EFFECT_SPEED, speed)

func _local_player() -> RigidBody3D:
	if _players == null or not CONNECTION_STATE.has_connected_peer(multiplayer):
		return null
	return _players.get_node_or_null(str(multiplayer.get_unique_id())) as RigidBody3D
