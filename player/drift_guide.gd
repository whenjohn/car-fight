extends Node3D
## Local driving language around the Jeep: speed fills the forward ring, peak
## braking brightens it, and the two rear-corner bands teach the assisted drift
## timing window without adding another control.

const FOLLOW := preload("res://player/follow_controller.gd")
const RING_RADIUS := 3.05
const RING_THICKNESS := 0.055
const BOOST_RADIUS := 3.20
const ZONE_INNER_RADIUS := 1.30
const ZONE_OUTER_RADIUS := 9.00
const ZONE_METER_RADIUS := 9.12
const ZONE_METER_THICKNESS := 0.18
const ZONE_START := FOLLOW.DRIFT_ASSIST_ZONE_INNER
const ZONE_END := FOLLOW.DRIFT_ASSIST_ZONE_OUTER
const SPEED_ARC_START := deg_to_rad(-135.0)
const SPEED_ARC_END := deg_to_rad(135.0)
const ARC_SEGMENTS := 48
const SPEED_COLOR := Color("63d8ff")
const BRAKE_COLOR := Color("fff1b8")
const BOOST_COLOR := Color("ff742e")
const LEFT_ZONE_COLOR := Color("67e8b1")
const RIGHT_ZONE_COLOR := Color("d688ff")

var _body: RigidBody3D
var _base_ring: MeshInstance3D
var _speed_ring: MeshInstance3D
var _boost_ring: MeshInstance3D
var _left_zone: MeshInstance3D
var _right_zone: MeshInstance3D
var _left_meter: MeshInstance3D
var _right_meter: MeshInstance3D
var _max_label: Label3D
var _assist_label: Label3D
var _base_material: StandardMaterial3D
var _speed_material: StandardMaterial3D
var _boost_material: StandardMaterial3D
var _left_zone_material: StandardMaterial3D
var _right_zone_material: StandardMaterial3D
var _last_speed_step := -1
var _last_boost_step := -1
var _last_charge_step := -1

func _ready() -> void:
	_body = get_parent() as RigidBody3D
	_base_material = _material(Color(SPEED_COLOR, 0.13), 0.20)
	_speed_material = _material(Color(SPEED_COLOR, 0.72), 1.1)
	_boost_material = _material(Color(BOOST_COLOR, 0.86), 1.8)
	_left_zone_material = _material(Color(LEFT_ZONE_COLOR, 0.075), 0.20)
	_right_zone_material = _material(Color(RIGHT_ZONE_COLOR, 0.075), 0.20)
	_base_ring = _mesh_node("SpeedRingBase",
		_arc_mesh(RING_RADIUS, RING_THICKNESS, SPEED_ARC_START, SPEED_ARC_END, 1.0),
		_base_material)
	_speed_ring = _mesh_node("SpeedRingFill", ImmediateMesh.new(), _speed_material)
	_boost_ring = _mesh_node("BurstRingFill", ImmediateMesh.new(), _boost_material)
	_left_zone = _mesh_node("LeftDriftZone",
		_sector_mesh(ZONE_INNER_RADIUS, ZONE_OUTER_RADIUS,
			ZONE_START, ZONE_END),
		_left_zone_material)
	_right_zone = _mesh_node("RightDriftZone",
		_sector_mesh(ZONE_INNER_RADIUS, ZONE_OUTER_RADIUS,
			-ZONE_START, -ZONE_END),
		_right_zone_material)
	_left_meter = _mesh_node("LeftDriftMeter", ImmediateMesh.new(),
		_material(Color(LEFT_ZONE_COLOR, 0.88), 2.0))
	_right_meter = _mesh_node("RightDriftMeter", ImmediateMesh.new(),
		_material(Color(RIGHT_ZONE_COLOR, 0.88), 2.0))
	_max_label = Label3D.new()
	_max_label.name = "DriftMaxLabel"
	_max_label.text = "MAX  →  GAS"
	_max_label.position = Vector3(0.0, 0.26, 4.25)
	_max_label.font_size = 26
	_max_label.outline_size = 7
	_max_label.modulate = Color("fff3c4")
	_max_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_max_label.no_depth_test = true
	_max_label.visible = false
	add_child(_max_label)
	_assist_label = Label3D.new()
	_assist_label.name = "DriftAssistLabel"
	_assist_label.text = "DRIFT ASSIST"
	_assist_label.font_size = 30
	_assist_label.outline_size = 8
	_assist_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_assist_label.no_depth_test = true
	_assist_label.visible = false
	add_child(_assist_label)
	_update_dynamic_meshes(0.0, 0.0, 0.0)

func _process(_delta: float) -> void:
	if _body == null:
		return
	var main := get_tree().current_scene
	visible = main == null or not (main.has_method("combat_editor_active") \
		and bool(main.call("combat_editor_active", _body)))
	if not visible:
		return
	var road_speed := Vector2(_body.linear_velocity.x, _body.linear_velocity.z).length()
	var brake := clampf(float(_body.get("brake_skid_amount")), 0.0, 1.0)
	var charge := clampf(float(_body.get("drift_assist_charge")), 0.0, 1.0)
	var side := float(_body.get("drift_assist_side"))
	var assist := clampf(float(_body.get("drift_assist_amount")), 0.0, 1.0)
	var latched := bool(_body.get("drift_assist_latched"))
	var rearm_ready := bool(_body.get("drift_assist_rearm_ready"))
	var hold_fraction := clampf(float(_body.get("drift_assist_hold")) \
		/ FOLLOW.DRIFT_ASSIST_ARM_TIME, 0.0, 1.0)
	var ready := FOLLOW.drift_assist_ready_fraction(road_speed)
	if not rearm_ready:
		# A completed drift stays visibly spent until forward acceleration rearms
		# it, matching the one-corner control rule instead of inviting a circle.
		ready *= 0.08
		assist = 0.0
		hold_fraction = 0.0
	_update_dynamic_meshes(road_speed, charge, side)
	var brake_glow := smoothstep(0.65, 1.0, brake)
	_speed_material.albedo_color = Color(SPEED_COLOR.lerp(BRAKE_COLOR, brake_glow),
		lerpf(0.72, 0.98, brake_glow))
	_speed_material.emission = SPEED_COLOR.lerp(BRAKE_COLOR, brake_glow)
	_speed_material.emission_energy_multiplier = lerpf(1.1, 3.3, brake_glow)
	_base_material.albedo_color.a = lerpf(0.13, 0.38, brake_glow)
	var resting_alpha := lerpf(0.008, 0.115, ready)
	var left_active := maxf(hold_fraction, assist) if side > 0.0 else 0.0
	var right_active := maxf(hold_fraction, assist) if side < 0.0 else 0.0
	var left_latched := latched and side > 0.0
	var right_latched := latched and side < 0.0
	var inactive_alpha := minf(resting_alpha, 0.025) if latched else resting_alpha
	_left_zone_material.albedo_color.a = 0.68 if left_latched \
		else lerpf(inactive_alpha, 0.29, left_active)
	_right_zone_material.albedo_color.a = 0.68 if right_latched \
		else lerpf(inactive_alpha, 0.29, right_active)
	_left_zone_material.emission_energy_multiplier = 4.5 if left_latched \
		else lerpf(0.08, 1.55, left_active)
	_right_zone_material.emission_energy_multiplier = 4.5 if right_latched \
		else lerpf(0.08, 1.55, right_active)
	_assist_label.visible = latched and not is_zero_approx(side)
	if _assist_label.visible:
		_assist_label.position = Vector3(-3.7 * side, 0.30, 3.7)
		_assist_label.modulate = LEFT_ZONE_COLOR if side > 0.0 else RIGHT_ZONE_COLOR
	_max_label.visible = charge >= 0.985 and not is_zero_approx(side)
	if _max_label.visible:
		_max_label.position.x = -4.15 * side
		_max_label.position.z = 4.15

func _update_dynamic_meshes(road_speed: float, charge: float, side: float) -> void:
	var speed_step := clampi(roundi(speed_fraction(road_speed) * ARC_SEGMENTS), 0, ARC_SEGMENTS)
	if speed_step != _last_speed_step:
		_last_speed_step = speed_step
		_speed_ring.mesh = _arc_mesh(RING_RADIUS, RING_THICKNESS * 1.9,
			SPEED_ARC_START, SPEED_ARC_END, float(speed_step) / ARC_SEGMENTS)
	var boost_step := clampi(roundi(boost_fraction(road_speed) * ARC_SEGMENTS), 0, ARC_SEGMENTS)
	if boost_step != _last_boost_step:
		_last_boost_step = boost_step
		_boost_ring.mesh = _arc_mesh(BOOST_RADIUS, RING_THICKNESS * 1.3,
			SPEED_ARC_START, SPEED_ARC_END, float(boost_step) / ARC_SEGMENTS)
	var charge_step := clampi(roundi(clampf(charge, 0.0, 1.0) * 16.0), 0, 16)
	if charge_step != _last_charge_step:
		_last_charge_step = charge_step
		var meter_fraction := float(charge_step) / 16.0
		_left_meter.mesh = _arc_mesh(ZONE_METER_RADIUS, ZONE_METER_THICKNESS,
			ZONE_START, ZONE_END, meter_fraction)
		_right_meter.mesh = _arc_mesh(ZONE_METER_RADIUS, ZONE_METER_THICKNESS,
			-ZONE_START, -ZONE_END, meter_fraction)
	_left_meter.visible = side > 0.0 and charge > 0.001
	_right_meter.visible = side < 0.0 and charge > 0.001

static func speed_fraction(road_speed: float) -> float:
	return clampf(road_speed / FOLLOW.SPEED, 0.0, 1.0)

static func boost_fraction(road_speed: float) -> float:
	return clampf((road_speed - FOLLOW.SPEED) / (FOLLOW.BURST_SPEED - FOLLOW.SPEED),
		0.0, 1.0)

func _mesh_node(node_name: String, mesh: Mesh,
		material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _arc_mesh(radius: float, thickness: float, start_angle: float,
		end_angle: float, fraction: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var amount := clampf(fraction, 0.0, 1.0)
	if amount <= 0.0001:
		return mesh
	var steps := maxi(1, ceili(ARC_SEGMENTS * amount))
	var outer := radius + thickness * 0.5
	var inner := radius - thickness * 0.5
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in range(steps):
		var t0 := float(step) / ARC_SEGMENTS
		var t1 := minf(float(step + 1) / ARC_SEGMENTS, amount)
		var angle0 := lerpf(start_angle, end_angle, t0)
		var angle1 := lerpf(start_angle, end_angle, t1)
		var inner0 := _arc_point(inner, angle0)
		var outer0 := _arc_point(outer, angle0)
		var inner1 := _arc_point(inner, angle1)
		var outer1 := _arc_point(outer, angle1)
		for point in [inner0, outer0, outer1, inner0, outer1, inner1]:
			mesh.surface_add_vertex(point)
	mesh.surface_end()
	return mesh

func _sector_mesh(inner_radius: float, outer_radius: float, start_angle: float,
		end_angle: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in range(ARC_SEGMENTS):
		var angle0 := lerpf(start_angle, end_angle, float(step) / ARC_SEGMENTS)
		var angle1 := lerpf(start_angle, end_angle, float(step + 1) / ARC_SEGMENTS)
		var inner0 := _arc_point(inner_radius, angle0)
		var outer0 := _arc_point(outer_radius, angle0)
		var inner1 := _arc_point(inner_radius, angle1)
		var outer1 := _arc_point(outer_radius, angle1)
		for point in [inner0, outer0, outer1, inner0, outer1, inner1]:
			mesh.surface_add_vertex(point)
	mesh.surface_end()
	return mesh

func _arc_point(radius: float, angle: float) -> Vector3:
	return Vector3(-sin(angle) * radius, 0.02, -cos(angle) * radius)

func _material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = emission_energy
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
