extends Node3D
## Presentation-only projected caps for the ramp supports that the camera hides
## under its upper roads. They reveal collision affordance only when a local
## Jeep is close or about to reach a support on its current path.

const ELEVATED_COURSE := preload("res://world/elevated_course.gd")
const VEHICLE_CONFIG := preload("res://player/vehicle_config.gd")
const CLOSE_RANGE := 3.0
const REACTION_SECONDS := 0.60
const REACTION_FADE_SECONDS := 0.12
const MIN_PREDICTION_SPEED := 0.75
const FADE_RATE := 12.0
const OUTLINE_THICKNESS := 0.075
const OUTLINE_PAD := 0.10
const HINT_COLOR := Color(0.36, 0.84, 1.0, 0.90)

var _players: Node3D
var _material: StandardMaterial3D
var _records: Array[Dictionary] = []

func setup(players: Node3D) -> void:

	_players = players

func _ready() -> void:

	if DisplayServer.get_name() == "headless":
		queue_free()
		return
	_material = _outline_material()
	for support in ELEVATED_COURSE.supports():
		_add_hint(support)

func _process(delta: float) -> void:

	if _players == null:
		return
	var local := _players.get_node_or_null(str(multiplayer.get_unique_id())) as RigidBody3D
	var under_deck := local != null and local.global_position.y < ELEVATED_COURSE.ROAD_SURFACE_Y - 0.35
	var position := Vector3.ZERO if local == null else local.global_position
	var velocity := Vector3.ZERO if local == null else local.linear_velocity
	for record in _records:
		var target := visibility_strength(position, velocity, record["position"] as Vector3,
			record["size"] as Vector3, under_deck)
		var amount := move_toward(float(record["amount"]), target, FADE_RATE * delta)
		record["amount"] = amount
		var root := record["root"] as Node3D
		root.visible = amount > 0.001
		for mesh in record["meshes"] as Array[MeshInstance3D]:
			mesh.modulate.a = amount

## A stopped Jeep gets a small proximity warning. While driving, the hint
## reaches farther only through the car's actual travel corridor, not merely
## because a support happens to be nearby off to one side.
static func visibility_strength(body_position: Vector3, velocity: Vector3,
		support_position: Vector3, support_size: Vector3, under_deck: bool) -> float:

	if not under_deck:
		return 0.0
	var offset := Vector2(support_position.x - body_position.x,
		support_position.z - body_position.z)
	var distance := offset.length()
	var close := 1.0 - smoothstep(CLOSE_RANGE, CLOSE_RANGE + 0.75, distance)
	var planar_velocity := Vector2(velocity.x, velocity.z)
	var speed := planar_velocity.length()
	if speed < MIN_PREDICTION_SPEED:
		return close
	var direction := planar_velocity / speed
	var ahead := offset.dot(direction)
	if ahead <= 0.0:
		return close
	var time_to_support := ahead / speed
	var lateral := (offset - direction * ahead).length()
	var support_radius := Vector2(support_size.x, support_size.z).length() * 0.5
	var corridor := support_radius + VEHICLE_CONFIG.COLLISION_RADIUS + 0.20
	var approaching := 1.0 - smoothstep(REACTION_SECONDS,
		REACTION_SECONDS + REACTION_FADE_SECONDS, time_to_support)
	var on_course := 1.0 - smoothstep(corridor, corridor + 0.45, lateral)
	return maxf(close, approaching * on_course)

func _add_hint(support: Dictionary) -> void:

	var root := Node3D.new()
	root.name = "%sProjectedHint" % str(support["name"])
	root.position = support["position"] as Vector3
	root.position.y = ELEVATED_COURSE.ROAD_SURFACE_Y + OUTLINE_THICKNESS * 0.5 + 0.006
	root.visible = false
	add_child(root)
	var size := support["size"] as Vector3
	var half_x := size.x * 0.5 + OUTLINE_PAD
	var half_z := size.z * 0.5 + OUTLINE_PAD
	var meshes: Array[MeshInstance3D] = []
	meshes.append(_outline_bar(root, Vector3(0.0, 0.0, -half_z),
		Vector3(half_x * 2.0 + OUTLINE_THICKNESS, OUTLINE_THICKNESS, OUTLINE_THICKNESS)))
	meshes.append(_outline_bar(root, Vector3(0.0, 0.0, half_z),
		Vector3(half_x * 2.0 + OUTLINE_THICKNESS, OUTLINE_THICKNESS, OUTLINE_THICKNESS)))
	meshes.append(_outline_bar(root, Vector3(-half_x, 0.0, 0.0),
		Vector3(OUTLINE_THICKNESS, OUTLINE_THICKNESS, half_z * 2.0)))
	meshes.append(_outline_bar(root, Vector3(half_x, 0.0, 0.0),
		Vector3(OUTLINE_THICKNESS, OUTLINE_THICKNESS, half_z * 2.0)))
	_records.append({"root": root, "meshes": meshes, "position": support["position"],
		"size": size, "amount": 0.0})

func _outline_bar(parent: Node3D, position: Vector3, size: Vector3) -> MeshInstance3D:

	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _outline_material() -> StandardMaterial3D:

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = HINT_COLOR
	material.emission_enabled = true
	material.emission = HINT_COLOR
	material.emission_energy_multiplier = 1.25
	return material
