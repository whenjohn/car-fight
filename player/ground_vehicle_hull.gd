extends Node3D
## Presentation-only vehicle models. Chassis lean and wheel animation are
## derived locally; the rollback collider remains one equal-mass sphere.

const VEHICLE_SPLITTER := preload("res://player/jeep_mesh_splitter.gd")
const CLOAK_DISSOLVE_SHADER := preload("res://fx/vehicle_cloak_dissolve.gdshader")
const CLOAK_GHOST_SHADER := preload("res://fx/vehicle_cloak_ghost.gdshader")
const CLOAK_DUST_SCRIPT := preload("res://fx/vehicle_cloak_dust.gd")
const TIRE_SKID_TRAILS_SCRIPT := preload("res://player/tire_skid_trails.gd")
const JEEP_SCALE := 0.45
const WHEEL_RADIUS := 0.31
const MODEL_SCALE_MIN := 1.0
const MODEL_SCALE_MAX := 5.0
const OCCLUDED_SILHOUETTE_COLOR := Color(0.34, 0.76, 1.0, 1.0)
const VEHICLES := [
	{"name": "Jeep", "scene": preload("res://assets/ground_vehicle/Jeep.fbx"), "scale": 0.45},
	{"name": "Pickup", "scene": preload("res://assets/ground_vehicle/Pickup.fbx"), "scale": 0.33},
	{"name": "Sedan", "scene": preload("res://assets/ground_vehicle/Sedan.fbx"), "scale": 0.33},
	{"name": "Wagon", "scene": preload("res://assets/ground_vehicle/Wagon.fbx"), "scale": 0.33},
	{"name": "Bus", "scene": preload("res://assets/ground_vehicle/Bus.fbx"), "scale": 0.175},
	{"name": "Humvee M242", "scene": preload("res://assets/ground_vehicle/humvee_m242/HumveeM242.fbx"),
		"scale": 0.53, "separated_meshes": true, "wheel_surfaces": 1},
	{"name": "Combat Vehicle", "scene": preload("res://assets/ground_vehicle/combat_vehicle/CombatVehicle.glb"),
		"scale": 0.0094, "multi_mesh": true, "wheel_surfaces": 1, "materials": {
			"V_body": {
				"albedo": preload("res://assets/ground_vehicle/combat_vehicle/body_albedo.png"),
				"normal": preload("res://assets/ground_vehicle/combat_vehicle/body_normal.png"),
				"metallic": preload("res://assets/ground_vehicle/combat_vehicle/body_metallic.png"),
				"ao": preload("res://assets/ground_vehicle/combat_vehicle/body_occlusion.png"),
				"roughness": 0.58,
			},
			"tire": {
				"albedo": preload("res://assets/ground_vehicle/combat_vehicle/Materials/tire.png"),
				"normal": preload("res://assets/ground_vehicle/combat_vehicle/tire_normal.png"),
				"roughness": 0.82,
			},
		}},
	{"name": "Apocalypse Bus", "scene": preload("res://assets/ground_vehicle/apocalypse_bus/ApocalypseBus.glb"),
		"scale": 0.0039, "bounded_wheels": true, "wheel_surfaces": 1,
		"wheel_materials": ["3"],
		"source_yaw": -PI * 0.5,
		"wheel_boxes": {
			"front_positive_x": AABB(Vector3(134.0, 0.0, -87.0), Vector3(72.0, 71.0, 25.0)),
			"front_negative_x": AABB(Vector3(134.0, 0.0, 62.0), Vector3(72.0, 71.0, 25.0)),
			"rear_positive_x": AABB(Vector3(-187.0, 0.0, -87.0), Vector3(72.0, 71.0, 25.0)),
			"rear_negative_x": AABB(Vector3(-187.0, 0.0, 62.0), Vector3(72.0, 71.0, 25.0)),
		},
		"materials": {
			"1": {
				"albedo": preload("res://assets/ground_vehicle/apocalypse_bus/material_1_albedo.png"),
				"normal": preload("res://assets/ground_vehicle/apocalypse_bus/material_1_normal.png"),
				"metallic": preload("res://assets/ground_vehicle/apocalypse_bus/material_1_metallic.png"),
				"roughness_texture": preload("res://assets/ground_vehicle/apocalypse_bus/material_1_roughness.png"),
			},
			"2": {
				"albedo": preload("res://assets/ground_vehicle/apocalypse_bus/material_2_albedo.png"),
				"normal": preload("res://assets/ground_vehicle/apocalypse_bus/material_2_normal.png"),
				"metallic": preload("res://assets/ground_vehicle/apocalypse_bus/material_2_metallic.png"),
				"roughness_texture": preload("res://assets/ground_vehicle/apocalypse_bus/material_2_roughness.png"),
			},
			"3": {
				"albedo": preload("res://assets/ground_vehicle/apocalypse_bus/material_3_albedo.png"),
				"normal": preload("res://assets/ground_vehicle/apocalypse_bus/material_3_normal.png"),
				"metallic": preload("res://assets/ground_vehicle/apocalypse_bus/material_3_metallic.png"),
				"roughness_texture": preload("res://assets/ground_vehicle/apocalypse_bus/material_3_roughness.png"),
			},
			"4": {
				"albedo": preload("res://assets/ground_vehicle/apocalypse_bus/material_4_albedo.png"),
				"normal": preload("res://assets/ground_vehicle/apocalypse_bus/material_4_normal.png"),
				"metallic": preload("res://assets/ground_vehicle/apocalypse_bus/material_4_metallic.png"),
				"roughness_texture": preload("res://assets/ground_vehicle/apocalypse_bus/material_4_roughness.png"),
			},
		}},
]
const MAX_VISUAL_STEER := deg_to_rad(30.0)
const STEER_RATE_REFERENCE := 1.85
const BODY_ROLL_MAX := deg_to_rad(11.0)
const BODY_ROLL_SPEED_REF := 8.0
const BODY_BRAKE_PITCH_MAX := deg_to_rad(18.0)
const BODY_BRAKE_PITCH_SPEED_REF := 12.0
const BODY_BRAKE_PITCH_ONSET := 0.72
const BODY_BRAKE_PITCH_FULL := 0.98
const BODY_BRAKE_PITCH_RESPONSE := 4.5
const BODY_ACCEL_PITCH_MAX := deg_to_rad(7.0)
const BODY_DYNAMIC_ROLL_MAX := deg_to_rad(15.0)
const BODY_SUSPENSION_TRAVEL := 0.055
const LONGITUDINAL_LOAD_REFERENCE := 14.0
const LOCKED_WHEEL_ROLL_SCALE := 0.0
const BOOST_ECHO_COUNT := 4
const BOOST_ECHO_INTERVAL := 0.075
const BOOST_ECHO_LIFETIME := 0.34
const BOOST_ECHO_MIN_SPEED := 1.0
const BOOST_ECHO_COLOR := Color(1.0, 0.38, 0.08, 0.28)
const CLOAK_FADE_TIME := 0.38
const CLOAK_CUT_FRONT := 2.10
const CLOAK_CUT_BACK := -2.10
const OIL_FX_FLASH_SPEED := 16.0
const OIL_FX_AMBER := Color(1.0, 0.27, 0.015, 1.0)
const OIL_FX_MAGENTA := Color(1.0, 0.02, 0.34, 1.0)
const BOOST_SKID_PULSE_TIME := 0.24
const BOOST_RELEASE_NO_SKID_TIME := 0.55
const DRIFT_SKID_PULSE_TIME := 0.44

var _body: Node3D
var _chassis_lean: Node3D
var _front_steer_nodes: Array[Node3D] = []
var _wheel_spin_nodes: Array[Node3D] = []
var _wheel_records: Array[Dictionary] = []
var _wheel_spin_angle := 0.0
var _wheel_radius := WHEEL_RADIUS
var _vehicle_scale := JEEP_SCALE
var _model_scale_multiplier := 1.0
var _last_signed_speed := 0.0
var _has_speed_sample := false
var _smoothed_longitudinal_load := 0.0
var _animation_preview_state := {}
var _vehicle_index := 0
var _visual_parts: Array[Node3D] = []
var _boost_echoes: Array[Node3D] = []
var _boost_echo_materials: Array[StandardMaterial3D] = []
var _boost_echo_ages: Array[float] = []
var _boost_echo_cursor := 0
var _boost_echo_accum := 0.0
var _cloak_surfaces: Array[Dictionary] = []
var _cloak_strength := 0.0
var _cloak_override_active := false
var _cloak_dust: Node3D
var _cloak_ghost: Node3D
var _cloak_ghost_material: ShaderMaterial
var _occlusion_material: StandardMaterial3D
var _occlusion_meshes: Array[MeshInstance3D] = []
var _occlusion_enabled := true
var _oil_fx_root: Node3D
var _oil_fx_amber: StandardMaterial3D
var _oil_fx_magenta: StandardMaterial3D
var _oil_fx_ring: StandardMaterial3D
var _oil_fx_time := 0.0
var _tire_skid_trails: Node3D
var _boost_skid_pulse := 0.0
var _boost_was_active := false
var _boost_release_no_skid := 0.0
var _drift_skid_pulse := 0.0
var _drift_peel_armed := true
var _drift_assist_was_latched := false

func _ready() -> void:
	_body = get_parent() as Node3D
	_build_selected_vehicle()
	_prepare_cloak_meshes(self)
	_prepare_occlusion_overlay(self)
	_build_cloak_dust()
	_build_cloak_ghost()
	_build_boost_echoes()
	_build_oil_slip_fx()
	_build_tire_skid_trails()

func _process(delta: float) -> void:
	if _body == null:
		return
	var rigid := _body as RigidBody3D
	if rigid != null and _chassis_lean != null:
		var inputs := _animation_inputs(rigid, delta)
		var planar_speed := float(inputs["speed"])
		var signed_speed := float(inputs["signed_speed"])
		var brake_skid := float(inputs["brake"])
		var steer_fraction := float(inputs["steer"])
		var drift_signed := float(inputs["drift"])
		var target_roll := chassis_dynamic_roll_target(float(inputs["yaw_rate"]),
			planar_speed, drift_signed)
		_chassis_lean.rotation.z = lerp_angle(_chassis_lean.rotation.z, target_roll, 1.0 - exp(-9.0 * delta))
		var target_pitch := chassis_dynamic_pitch_target(brake_skid, planar_speed,
			float(inputs["longitudinal_load"]), bool(inputs["boosting"]))
		_chassis_lean.rotation.x = lerp_angle(_chassis_lean.rotation.x, target_pitch,
			1.0 - exp(-BODY_BRAKE_PITCH_RESPONSE * delta))
		_chassis_lean.position.y = lerpf(_chassis_lean.position.y,
			chassis_heave_target(float(inputs["longitudinal_load"]), absf(drift_signed)),
			1.0 - exp(-8.0 * delta))
		_update_wheel_pose(steer_fraction, drift_signed,
			float(inputs["longitudinal_load"]), target_roll, delta)
		_wheel_spin_angle = fposmod(_wheel_spin_angle + signed_speed / _wheel_radius * delta \
			* wheel_roll_scale(brake_skid), TAU)
		for spin_node in _wheel_spin_nodes:
			spin_node.rotation.x = _wheel_spin_angle
		_update_tire_skid_trails(inputs, delta)
		_update_boost_echoes(delta, bool(inputs["boosting"]), planar_speed)
		_update_cloak(delta, rigid)
	_update_oil_slip_fx(delta)


## Presentation-only hazard flash. The effect reads synchronized oil amount but
## owns no gameplay state, collision, light, or network object.
static func oil_fx_flash_state(amount: float, elapsed: float) -> Dictionary:
	var strength := clampf(amount, 0.0, 1.0)
	var wave := 0.5 + 0.5 * sin(elapsed * OIL_FX_FLASH_SPEED)
	return {
		"active": strength > 0.01,
		"amber": strength * (0.12 + 0.88 * wave),
		"magenta": strength * (0.12 + 0.88 * (1.0 - wave)),
		"ring": strength * (0.34 + 0.66 * absf(wave * 2.0 - 1.0)),
	}


func _build_oil_slip_fx() -> void:
	_oil_fx_root = Node3D.new()
	_oil_fx_root.name = "OilSlipFX"
	_oil_fx_root.visible = false
	add_child(_oil_fx_root)
	_oil_fx_amber = _oil_fx_material(OIL_FX_AMBER)
	_oil_fx_magenta = _oil_fx_material(OIL_FX_MAGENTA)
	_oil_fx_ring = _oil_fx_material(Color(1.0, 0.12, 0.025, 1.0))
	var ring := MeshInstance3D.new()
	ring.name = "SlipWarningRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.72
	torus.outer_radius = 1.92
	torus.rings = 32
	torus.ring_segments = 6
	ring.mesh = torus
	ring.position.y = -1.42
	ring.material_override = _oil_fx_ring
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_oil_fx_root.add_child(ring)
	var beacon_mesh := SphereMesh.new()
	beacon_mesh.radius = 0.14
	beacon_mesh.height = 0.28
	beacon_mesh.radial_segments = 10
	beacon_mesh.rings = 5
	var positions := [
		Vector3(-1.18, 0.82, -0.78), Vector3(1.18, 0.82, -0.78),
		Vector3(-1.18, 0.82, 0.78), Vector3(1.18, 0.82, 0.78),
	]
	for index in range(positions.size()):
		var beacon := MeshInstance3D.new()
		beacon.name = "SlipBeacon%d" % index
		beacon.mesh = beacon_mesh
		beacon.position = positions[index]
		beacon.material_override = _oil_fx_amber if index % 2 == 0 else _oil_fx_magenta
		beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_oil_fx_root.add_child(beacon)


func _oil_fx_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 5.0
	material.no_depth_test = false
	material.render_priority = 2
	return material


func _update_oil_slip_fx(delta: float) -> void:
	if _oil_fx_root == null:
		return
	var amount := clampf(float(_body.get("oil_slick_amount")), 0.0, 1.0)
	_oil_fx_time += delta
	var flash := oil_fx_flash_state(amount, _oil_fx_time)
	_oil_fx_root.visible = bool(flash["active"])
	if not _oil_fx_root.visible:
		return
	_set_oil_fx_material(_oil_fx_amber, OIL_FX_AMBER, float(flash["amber"]))
	_set_oil_fx_material(_oil_fx_magenta, OIL_FX_MAGENTA, float(flash["magenta"]))
	_set_oil_fx_material(_oil_fx_ring, Color(1.0, 0.12, 0.025, 1.0),
		float(flash["ring"]))
	_oil_fx_root.scale = Vector3.ONE * (1.0 + float(flash["ring"]) * 0.10)


func _set_oil_fx_material(material: StandardMaterial3D, color: Color,
		intensity: float) -> void:
	material.albedo_color = Color(color.r, color.g, color.b,
		clampf(0.12 + intensity * 0.88, 0.0, 1.0))
	material.emission_energy_multiplier = 1.5 + intensity * 7.5


func _build_tire_skid_trails() -> void:
	_tire_skid_trails = Node3D.new()
	_tire_skid_trails.name = "TireSkidTrails"
	_tire_skid_trails.set_script(TIRE_SKID_TRAILS_SCRIPT)
	add_child(_tire_skid_trails)


func _update_tire_skid_trails(inputs: Dictionary, delta: float) -> void:
	if _tire_skid_trails == null:
		return
	var brake := float(inputs["brake"])
	var player_input := _body.get_node_or_null("Input")
	var reverse_held := player_input != null and bool(player_input.get("reverse"))
	brake = maxf(brake, TIRE_SKID_TRAILS_SCRIPT.reverse_brake_strength(
		reverse_held, float(inputs["signed_speed"])))
	var measured_slide := TIRE_SKID_TRAILS_SCRIPT.sustained_slide(
		float(inputs["drift"]),
		float(_body.get("drift_assist_amount")),
		float(_body.get("drift_assist_charge")))
	var oil := clampf(float(_body.get("oil_slick_amount")), 0.0, 1.0)
	var boosting := bool(inputs["boosting"])
	if boosting and not _boost_was_active:
		_boost_skid_pulse = BOOST_SKID_PULSE_TIME
	elif not boosting and _boost_was_active:
		# Returning from burst speed makes the FOLLOW controller report hard
		# automatic braking. That is speed normalization, not a tire-lock event.
		_boost_skid_pulse = 0.0
		_drift_skid_pulse = 0.0
		_boost_release_no_skid = BOOST_RELEASE_NO_SKID_TIME
	_boost_was_active = boosting
	var suppress_release_mark := _boost_release_no_skid > 0.0
	if suppress_release_mark:
		brake = 0.0
	var boost_pulse := clampf(_boost_skid_pulse / BOOST_SKID_PULSE_TIME, 0.0, 1.0)
	var assist_latched := bool(_body.get("drift_assist_latched"))
	var assist_just_latched := assist_latched and not _drift_assist_was_latched
	if not assist_latched and measured_slide < TIRE_SKID_TRAILS_SCRIPT.PEEL_REARM:
		_drift_peel_armed = true
	if not suppress_release_mark \
			and TIRE_SKID_TRAILS_SCRIPT.should_start_peel(_drift_peel_armed,
			assist_just_latched, measured_slide, oil):
		_drift_skid_pulse = DRIFT_SKID_PULSE_TIME
		_drift_peel_armed = false
	_drift_assist_was_latched = assist_latched
	var drift_peel := measured_slide \
		if _drift_skid_pulse > 0.0 and not suppress_release_mark else 0.0
	# A tight donut has substantial velocity at each tire even when the body's
	# center travels slowly. Include that rotational contact speed.
	var speed := maxf(float(inputs["speed"]), absf(float(inputs["yaw_rate"])) * 1.8)
	var half_width := maxf(0.075, _wheel_radius * 0.42)
	for record in _wheel_records:
		var anchor := record["node"] as Node3D
		var front := bool(record["front"])
		var strength := TIRE_SKID_TRAILS_SCRIPT.skid_strength(brake, drift_peel, oil,
			speed, front, boost_pulse)
		var contact := _tire_ground_contact(anchor) \
			if strength >= TIRE_SKID_TRAILS_SCRIPT.MIN_STRENGTH else {}
		if contact.is_empty():
			_tire_skid_trails.call("sample_tire", str(record["key"]), Vector3.ZERO,
				Vector3.RIGHT, half_width, strength, oil, false)
			continue
		var normal: Vector3 = contact["normal"]
		var width_axis := anchor.global_basis.x.slide(normal).normalized()
		_tire_skid_trails.call("sample_tire", str(record["key"]), contact["point"],
			width_axis, half_width, strength, oil, true)
	_boost_skid_pulse = maxf(_boost_skid_pulse - delta, 0.0)
	_drift_skid_pulse = maxf(_drift_skid_pulse - delta, 0.0)
	_boost_release_no_skid = maxf(_boost_release_no_skid - delta, 0.0)


func _tire_ground_contact(anchor: Node3D) -> Dictionary:
	var world := get_world_3d()
	if world == null:
		return {}
	var origin := anchor.global_position
	var query := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.65,
		origin + Vector3.DOWN * 1.35)
	query.collide_with_areas = false
	var collision_body := _body as CollisionObject3D
	if collision_body != null:
		query.exclude = [collision_body.get_rid()]
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var normal: Vector3 = hit["normal"]
	return {"point": (hit["position"] as Vector3) + normal * 0.026,
		"normal": normal.normalized()}

## The standalone animation lab uses this seam to exercise presentation without
## creating a fake gameplay/network state. An empty dictionary returns control
## to the live rigid body.
func set_animation_preview_state(state: Dictionary) -> void:
	_animation_preview_state = state.duplicate()

func _animation_inputs(rigid: RigidBody3D, delta: float) -> Dictionary:
	if not _animation_preview_state.is_empty():
		var speed := maxf(float(_animation_preview_state.get("speed", 0.0)), 0.0)
		return {
			"speed": speed,
			"signed_speed": float(_animation_preview_state.get("signed_speed", speed)),
			"brake": clampf(float(_animation_preview_state.get("brake", 0.0)), 0.0, 1.0),
			"steer": clampf(float(_animation_preview_state.get("steer", 0.0)), -1.0, 1.0),
			"yaw_rate": float(_animation_preview_state.get("yaw_rate",
				float(_animation_preview_state.get("steer", 0.0)) * STEER_RATE_REFERENCE)),
			"drift": clampf(float(_animation_preview_state.get("drift", 0.0)), -1.0, 1.0),
			"longitudinal_load": clampf(float(_animation_preview_state.get(
				"longitudinal_load", 0.0)), -1.0, 1.0),
			"boosting": bool(_animation_preview_state.get("boosting", false)),
		}
	var velocity := rigid.linear_velocity
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var forward := -rigid.global_basis.z
	var right := rigid.global_basis.x
	var signed_speed := velocity.dot(forward)
	var acceleration_load := 0.0
	if _has_speed_sample and delta > 0.0001:
		acceleration_load = clampf((signed_speed - _last_signed_speed) / delta \
			/ LONGITUDINAL_LOAD_REFERENCE, -1.0, 1.0)
	_last_signed_speed = signed_speed
	_has_speed_sample = true
	var brake := clampf(float(_body.get("brake_skid_amount")), 0.0, 1.0)
	var boosting := bool(_body.get("boost_active"))
	if brake > 0.0:
		acceleration_load = minf(acceleration_load, -brake)
	elif boosting:
		acceleration_load = maxf(acceleration_load, 0.72)
	_smoothed_longitudinal_load = lerpf(_smoothed_longitudinal_load,
		acceleration_load, 1.0 - exp(-7.0 * delta))
	var slip := 0.0 if planar_speed < 0.5 else clampf(velocity.dot(right) \
		/ maxf(planar_speed * 0.55, 0.001), -1.0, 1.0)
	var assist := clampf(float(_body.get("drift_assist_amount")), 0.0, 1.0)
	var assist_side := signf(float(_body.get("drift_assist_side")))
	return {
		"speed": planar_speed,
		"signed_speed": signed_speed,
		"brake": brake,
		"steer": clampf(rigid.angular_velocity.y / STEER_RATE_REFERENCE, -1.0, 1.0),
		"yaw_rate": rigid.angular_velocity.y,
		"drift": clampf(slip + assist * assist_side * 0.65, -1.0, 1.0),
		"longitudinal_load": _smoothed_longitudinal_load,
		"boosting": boosting,
	}

static func chassis_roll_target(yaw_rate: float, road_speed: float) -> float:
	var steer_load := clampf(yaw_rate / STEER_RATE_REFERENCE, -1.0, 1.0)
	var speed_load := clampf(road_speed / BODY_ROLL_SPEED_REF, 0.0, 1.0)
	return -steer_load * speed_load * BODY_ROLL_MAX

static func chassis_brake_pitch_target(brake_skid: float, road_speed: float) -> float:
	# Hold the chassis level through ordinary deceleration. The dramatic dive
	# belongs to the peak tire-lock moment, then eases in slowly enough to read.
	var skid_load := smoothstep(BODY_BRAKE_PITCH_ONSET, BODY_BRAKE_PITCH_FULL,
		clampf(brake_skid, 0.0, 1.0))
	var speed_load := clampf(road_speed / BODY_BRAKE_PITCH_SPEED_REF, 0.0, 1.0)
	return -skid_load * speed_load * BODY_BRAKE_PITCH_MAX

static func chassis_dynamic_pitch_target(brake_skid: float, road_speed: float,
		longitudinal_load: float, boosting: bool = false) -> float:
	var brake_pitch := chassis_brake_pitch_target(brake_skid, road_speed)
	if brake_pitch < 0.0:
		return brake_pitch
	var acceleration := maxf(longitudinal_load, 0.72 if boosting else 0.0)
	var speed_read := clampf(road_speed / 5.0, 0.0, 1.0)
	return clampf(acceleration, 0.0, 1.0) * speed_read * BODY_ACCEL_PITCH_MAX

static func chassis_dynamic_roll_target(yaw_rate: float, road_speed: float,
		drift_signed: float = 0.0) -> float:
	var ordinary := chassis_roll_target(yaw_rate, road_speed)
	var drift_load := -clampf(drift_signed, -1.0, 1.0) * BODY_DYNAMIC_ROLL_MAX
	return clampf(ordinary + drift_load * 0.45, -BODY_DYNAMIC_ROLL_MAX,
		BODY_DYNAMIC_ROLL_MAX)

static func chassis_heave_target(longitudinal_load: float, drift_amount: float) -> float:
	return -BODY_SUSPENSION_TRAVEL * (absf(longitudinal_load) * 0.34 \
		+ clampf(drift_amount, 0.0, 1.0) * 0.18)

static func wheel_steer_target(steer_fraction: float, side_sign: float,
		drift_signed: float = 0.0) -> float:
	var requested := clampf(steer_fraction - drift_signed * 0.32, -1.0, 1.0)
	var inner_wheel := clampf(requested * side_sign, -1.0, 1.0)
	var ackermann := lerpf(0.88, 1.12, (inner_wheel + 1.0) * 0.5)
	return requested * MAX_VISUAL_STEER * ackermann

static func wheel_suspension_target(front: bool, side_sign: float,
		longitudinal_load: float, roll_target: float) -> float:
	var axle_load := -longitudinal_load if front else longitudinal_load
	var roll_fraction := clampf(roll_target / BODY_DYNAMIC_ROLL_MAX, -1.0, 1.0)
	return BODY_SUSPENSION_TRAVEL * (axle_load * 0.48 + side_sign * roll_fraction * 0.34)

func _update_wheel_pose(steer_fraction: float, drift_signed: float,
		longitudinal_load: float, roll_target: float, delta: float) -> void:
	var blend := 1.0 - exp(-12.0 * delta)
	for record in _wheel_records:
		var anchor := record["node"] as Node3D
		if bool(record["front"]):
			var steer_target := wheel_steer_target(steer_fraction,
				float(record["side"]), drift_signed)
			anchor.rotation.y = lerp_angle(anchor.rotation.y, steer_target, blend)
		var suspension := wheel_suspension_target(bool(record["front"]),
			float(record["side"]), longitudinal_load, roll_target) / _vehicle_scale
		anchor.position.y = lerpf(anchor.position.y,
			float(record["base_y"]) + suspension, blend)

static func wheel_roll_scale(brake_skid: float) -> float:
	return lerpf(1.0, LOCKED_WHEEL_ROLL_SCALE, clampf(brake_skid, 0.0, 1.0))

static func cloak_cut_position(amount: float) -> float:
	return lerpf(CLOAK_CUT_FRONT, CLOAK_CUT_BACK, clampf(amount, 0.0, 1.0))

func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.62
	return material

func _mesh_node(node_name: String, mesh: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = position
	node.material_override = material
	return node

func vehicle_name() -> String:
	return str((VEHICLES[_vehicle_index] as Dictionary)["name"])

static func sanitized_model_scale(value: Variant) -> float:
	if value is not float and value is not int:
		return 1.0
	return clampf(float(value), MODEL_SCALE_MIN, MODEL_SCALE_MAX)

func model_scale_multiplier() -> float:
	return _model_scale_multiplier

func set_model_scale_multiplier(value: Variant) -> void:
	var next_scale := sanitized_model_scale(value)
	if is_equal_approx(next_scale, _model_scale_multiplier):
		return
	_model_scale_multiplier = next_scale
	if _chassis_lean != null:
		_rebuild_selected_vehicle()

func cycle_vehicle() -> void:
	_vehicle_index = (_vehicle_index + 1) % VEHICLES.size()
	_rebuild_selected_vehicle()

func _rebuild_selected_vehicle() -> void:
	_clear_vehicle_visuals()
	_build_selected_vehicle()
	_prepare_cloak_meshes(self)
	_prepare_occlusion_overlay(self)
	_build_cloak_ghost()
	_build_boost_echoes()
	if _tire_skid_trails != null:
		_tire_skid_trails.call("break_emitters")
	_cloak_override_active = false
	_set_cloak_override_active(_cloak_strength > 0.0001)

func _clear_vehicle_visuals() -> void:
	for echo in _boost_echoes:
		if is_instance_valid(echo):
			echo.free()
	_boost_echoes.clear()
	_boost_echo_materials.clear()
	_boost_echo_ages.clear()
	_boost_echo_cursor = 0
	_boost_echo_accum = 0.0
	if _cloak_ghost != null and is_instance_valid(_cloak_ghost):
		_cloak_ghost.free()
	_cloak_ghost = null
	for part in _visual_parts:
		if is_instance_valid(part):
			part.free()
	_visual_parts.clear()
	_front_steer_nodes.clear()
	_wheel_spin_nodes.clear()
	_wheel_records.clear()
	_cloak_surfaces.clear()
	_occlusion_meshes.clear()

func _build_selected_vehicle() -> void:
	var vehicle: Dictionary = VEHICLES[_vehicle_index]
	var scale_amount := float(vehicle["scale"]) * _model_scale_multiplier
	_vehicle_scale = scale_amount
	var source := (vehicle["scene"] as PackedScene).instantiate() as Node3D
	_apply_vehicle_materials(source, vehicle.get("materials", {}) as Dictionary)
	var split: Dictionary
	if bool(vehicle.get("separated_meshes", false)):
		split = VEHICLE_SPLITTER.split_separated(source)
	elif bool(vehicle.get("multi_mesh", false)):
		split = VEHICLE_SPLITTER.split_multi_mesh(source)
	elif bool(vehicle.get("bounded_wheels", false)):
		split = VEHICLE_SPLITTER.split_bounded_wheels(source,
			vehicle["wheel_boxes"] as Dictionary, float(vehicle.get("source_yaw", 0.0)),
			vehicle.get("wheel_materials", []) as Array)
	else:
		var source_mesh_instance := source.find_child("*", true, false) as MeshInstance3D
		split = VEHICLE_SPLITTER.split(source_mesh_instance.mesh, source_mesh_instance.transform)
	source.free()
	_wheel_radius = float(split.get("wheel_radius", WHEEL_RADIUS / JEEP_SCALE)) \
		* scale_amount

	_chassis_lean = Node3D.new()
	_chassis_lean.name = "ChassisLean"
	add_child(_chassis_lean)
	var chassis_model := _model_root("ChassisModel", _chassis_lean, scale_amount)
	var chassis := MeshInstance3D.new()
	chassis.name = "SeparatedChassis"
	chassis.mesh = split["chassis"]
	chassis_model.add_child(chassis)

	var wheel_model := _model_root("WheelModel", self, scale_amount)
	_visual_parts = [_chassis_lean, wheel_model]
	var wheels: Dictionary = split["wheels"]
	for wheel_name in wheels.keys():
		var wheel: Dictionary = wheels[wheel_name]
		var steer_anchor := Node3D.new()
		steer_anchor.name = "%sSteer" % str(wheel_name).to_pascal_case()
		steer_anchor.position = wheel["center"]
		wheel_model.add_child(steer_anchor)
		if bool(wheel["front"]):
			_front_steer_nodes.append(steer_anchor)
		_wheel_records.append({
			"key": str(wheel_name),
			"node": steer_anchor,
			"base_y": steer_anchor.position.y,
			"front": bool(wheel["front"]),
			"side": signf(float((wheel["center"] as Vector3).x)),
		})
		var spin_anchor := Node3D.new()
		spin_anchor.name = "%sSpin" % str(wheel_name).to_pascal_case()
		steer_anchor.add_child(spin_anchor)
		_wheel_spin_nodes.append(spin_anchor)
		var wheel_mesh := MeshInstance3D.new()
		wheel_mesh.name = "%sMesh" % str(wheel_name).to_pascal_case()
		wheel_mesh.mesh = wheel["mesh"]
		spin_anchor.add_child(wheel_mesh)

	var dark_mat := _material(Color(0.055, 0.075, 0.095), 0.3)
	var body_mat := _material(Color(0.18, 0.48, 0.22), 0.12)
	_build_weapon_mounts(dark_mat, body_mat)

func _apply_vehicle_materials(source: Node3D, overrides: Dictionary) -> void:
	if overrides.is_empty():
		return
	for candidate in source.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		var mesh_copy := mesh_instance.mesh.duplicate() as Mesh
		for surface in range(mesh_copy.get_surface_count()):
			var imported := mesh_copy.surface_get_material(surface)
			var material_name := "" if imported == null else imported.resource_name
			if not overrides.has(material_name):
				continue
			var config: Dictionary = overrides[material_name]
			var material := StandardMaterial3D.new()
			material.resource_name = material_name
			material.albedo_texture = config.get("albedo") as Texture2D
			material.roughness = float(config.get("roughness", 0.62))
			var normal_texture := config.get("normal") as Texture2D
			if normal_texture != null:
				material.normal_enabled = true
				material.normal_texture = normal_texture
			var metallic_texture := config.get("metallic") as Texture2D
			if metallic_texture != null:
				material.metallic = 1.0
				material.metallic_texture = metallic_texture
				material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			var roughness_texture := config.get("roughness_texture") as Texture2D
			if roughness_texture != null:
				material.roughness = 1.0
				material.roughness_texture = roughness_texture
				material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			var ao_texture := config.get("ao") as Texture2D
			if ao_texture != null:
				material.ao_enabled = true
				material.ao_texture = ao_texture
				material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			mesh_copy.surface_set_material(surface, material)
		mesh_instance.mesh = mesh_copy

func _build_weapon_mounts(dark_material: Material, body_material: Material) -> void:
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.17
	ring_mesh.bottom_radius = 0.21
	ring_mesh.height = 0.13
	ring_mesh.radial_segments = 12
	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.11, 0.10, 0.72)
	for index in range(4):
		var mount := Node3D.new()
		mount.name = "%sWeaponMount" % ["Front", "Right", "Rear", "Left"][index]
		mount.position = Vector3(0.0, 1.30 * _model_scale_multiplier, -0.04)
		mount.rotation.y = [0.0, -PI * 0.5, PI, PI * 0.5][index]
		_chassis_lean.add_child(mount)
		mount.add_child(_mesh_node("Mount", ring_mesh, Vector3.ZERO, dark_material))
		mount.add_child(_mesh_node("Barrel", barrel_mesh,
			Vector3(0.0, 0.04, -0.34), body_material))

## Prepare the dissolve counterparts without replacing the normal materials.
## The originals remain authoritative whenever the Jeep is fully visible.
func _prepare_cloak_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			if mesh_instance.material_override != null:
				_cloak_surfaces.append({
					"mesh": mesh_instance, "surface": -1,
					"original": mesh_instance.material_override,
					"material": _cloak_material(mesh_instance.material_override),
				})
			else:
				for surface in range(mesh_instance.mesh.get_surface_count()):
					_cloak_surfaces.append({
						"mesh": mesh_instance, "surface": surface,
						"original": mesh_instance.get_surface_override_material(surface),
						"material": _cloak_material(mesh_instance.get_active_material(surface)),
					})
	for child in node.get_children():
		_prepare_cloak_meshes(child)

## The transparent stencil pass marks the visible vehicle without changing its
## normal materials. Godot's X-ray next pass then draws the cyan silhouette
## only where static walls or obstacles hide the vehicle from the camera.
func _prepare_occlusion_overlay(node: Node) -> void:
	if _occlusion_material == null:
		_occlusion_material = occlusion_material()
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if _occlusion_enabled:
			mesh_instance.material_overlay = _occlusion_material
		_occlusion_meshes.append(mesh_instance)
	for child in node.get_children():
		_prepare_occlusion_overlay(child)

static func occlusion_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
	material.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
	var xray_pass := material.next_pass as BaseMaterial3D
	if xray_pass != null:
		xray_pass.albedo_color = OCCLUDED_SILHOUETTE_COLOR
	return material

func _set_occlusion_enabled(enabled: bool) -> void:
	if enabled == _occlusion_enabled:
		return
	_occlusion_enabled = enabled
	for mesh_instance in _occlusion_meshes:
		if is_instance_valid(mesh_instance):
			mesh_instance.material_overlay = _occlusion_material if enabled else null

func _cloak_material(source: Material) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CLOAK_DISSOLVE_SHADER
	if source is BaseMaterial3D:
		var base := source as BaseMaterial3D
		material.set_shader_parameter("base_color", base.albedo_color)
		material.set_shader_parameter("roughness_value", base.roughness)
		material.set_shader_parameter("metallic_value", base.metallic)
		if base.albedo_texture != null:
			material.set_shader_parameter("albedo_texture", base.albedo_texture)
			material.set_shader_parameter("use_albedo_texture", true)
	material.set_shader_parameter("cut_position", CLOAK_CUT_FRONT * _model_scale_multiplier)
	return material

func _build_cloak_dust() -> void:
	_cloak_dust = Node3D.new()
	_cloak_dust.name = "VehicleCloakDust"
	_cloak_dust.set_script(CLOAK_DUST_SCRIPT)
	add_child(_cloak_dust)

## Remote Jeeps disappear completely. The owning client keeps this faint
## refractive duplicate as a steering reference once the cut reaches the tail.
func _build_cloak_ghost() -> void:
	if _body == null or int(_body.get("owner_id")) != multiplayer.get_unique_id():
		return
	_cloak_ghost = Node3D.new()
	_cloak_ghost.name = "OwnerCloakGhost"
	add_child(_cloak_ghost)
	for part in _visual_parts:
		_cloak_ghost.add_child(part.duplicate())
	_cloak_ghost_material = ShaderMaterial.new()
	_cloak_ghost_material.shader = CLOAK_GHOST_SHADER
	_cloak_ghost_material.set_shader_parameter("cloak_strength", 0.0)
	_apply_cloak_ghost_material(_cloak_ghost)
	_cloak_ghost.visible = false

func _update_cloak(delta: float, rigid: RigidBody3D) -> void:
	var target := 1.0 if bool(_body.get("is_cloaked")) else 0.0
	_cloak_strength = move_toward(_cloak_strength, target,
		delta / maxf(CLOAK_FADE_TIME, 0.0001))
	var forward := -global_basis.z.normalized()
	var right := global_basis.x.normalized()
	var up := global_basis.y.normalized()
	var cut := cloak_cut_position(_cloak_strength) * _model_scale_multiplier
	_set_cloak_override_active(_cloak_strength > 0.0001)
	# An already dissolving vehicle must not leave a full X-ray duplicate behind.
	_set_occlusion_enabled(_cloak_strength <= 0.0001)
	for record in _cloak_surfaces:
		var material := record["material"] as ShaderMaterial
		material.set_shader_parameter("vehicle_origin", global_position)
		material.set_shader_parameter("vehicle_forward", forward)
		material.set_shader_parameter("vehicle_right", right)
		material.set_shader_parameter("vehicle_up", up)
		material.set_shader_parameter("cut_position", cut)
	if _cloak_dust != null and is_instance_valid(_cloak_dust):
		_cloak_dust.call("set_source_velocity", rigid.linear_velocity)
		_cloak_dust.call("set_cloak", _cloak_strength)
	if _cloak_ghost != null and _cloak_ghost_material != null:
		for index in range(_visual_parts.size()):
			_copy_pose(_visual_parts[index], _cloak_ghost.get_child(index) as Node3D)
		var ghost_strength := smoothstep(0.86, 1.0, _cloak_strength)
		_cloak_ghost_material.set_shader_parameter("cloak_strength", ghost_strength)
		_cloak_ghost.visible = ghost_strength > 0.001

func _set_cloak_override_active(active: bool) -> void:
	if active == _cloak_override_active:
		return
	_cloak_override_active = active
	for record in _cloak_surfaces:
		var mesh_instance := record["mesh"] as MeshInstance3D
		if not is_instance_valid(mesh_instance):
			continue
		var material := record["material"] as Material if active else record["original"] as Material
		var surface := int(record["surface"])
		if surface < 0:
			mesh_instance.material_override = material
		else:
			mesh_instance.set_surface_override_material(surface, material)

func _apply_cloak_ghost_material(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.material_override = _cloak_ghost_material
		# The local cloak ghost is a separate refractive cue, never an obstacle X-ray target.
		geometry.material_overlay = null
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_cloak_ghost_material(child)

## A tiny pool of frozen Jeep snapshots, matching g2's accepted boost echoes.
## They clone only render nodes and never add collision, physics, or network state.
func _build_boost_echoes() -> void:
	for index in range(BOOST_ECHO_COUNT):
		var echo := Node3D.new()
		echo.name = "BoostEcho_%d" % index
		add_child(echo)
		echo.top_level = true
		echo.visible = false
		for part in _visual_parts:
			echo.add_child(part.duplicate())
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(BOOST_ECHO_COLOR.r, BOOST_ECHO_COLOR.g,
			BOOST_ECHO_COLOR.b, 0.0)
		material.emission_enabled = true
		material.emission = BOOST_ECHO_COLOR
		material.emission_energy_multiplier = 0.45
		_apply_echo_material(echo, material)
		_boost_echoes.append(echo)
		_boost_echo_materials.append(material)
		_boost_echo_ages.append(BOOST_ECHO_LIFETIME)

func _update_boost_echoes(delta: float, boosting: bool, speed: float) -> void:
	for index in range(_boost_echoes.size()):
		var age := _boost_echo_ages[index] + delta
		_boost_echo_ages[index] = age
		var alive := 1.0 - clampf(age / BOOST_ECHO_LIFETIME, 0.0, 1.0)
		var echo := _boost_echoes[index]
		echo.visible = alive > 0.01
		if echo.visible:
			# Keep sampled position but use the live vehicle facing, preventing a
			# fan of stale headings during a curved boost.
			var echo_transform := echo.global_transform
			echo_transform.basis = global_transform.basis
			echo.global_transform = echo_transform
		var alpha := BOOST_ECHO_COLOR.a * alive * alive
		_boost_echo_materials[index].albedo_color = Color(BOOST_ECHO_COLOR.r,
			BOOST_ECHO_COLOR.g, BOOST_ECHO_COLOR.b, alpha)
	if not boosting or speed < BOOST_ECHO_MIN_SPEED or _boost_echoes.is_empty():
		_boost_echo_accum = 0.0
		return
	_boost_echo_accum += delta
	if _boost_echo_accum < BOOST_ECHO_INTERVAL:
		return
	_boost_echo_accum = fmod(_boost_echo_accum, BOOST_ECHO_INTERVAL)
	_emit_boost_echo()

func _emit_boost_echo() -> void:
	if _boost_echoes.is_empty():
		return
	var echo := _boost_echoes[_boost_echo_cursor]
	for index in range(_visual_parts.size()):
		_copy_pose(_visual_parts[index], echo.get_child(index) as Node3D)
	echo.global_transform = global_transform
	echo.visible = true
	_boost_echo_ages[_boost_echo_cursor] = 0.0
	_boost_echo_cursor = (_boost_echo_cursor + 1) % _boost_echoes.size()

func _copy_pose(source: Node3D, target: Node3D) -> void:
	target.transform = source.transform
	var child_count := mini(source.get_child_count(), target.get_child_count())
	for index in range(child_count):
		var source_child := source.get_child(index) as Node3D
		var target_child := target.get_child(index) as Node3D
		if source_child != null and target_child != null:
			_copy_pose(source_child, target_child)

func _apply_echo_material(node: Node, material: StandardMaterial3D) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.material_override = material
		# Frozen boost snapshots are trails, not live vehicles; do not duplicate their X-ray silhouette.
		geometry.material_overlay = null
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_echo_material(child, material)

func _model_root(node_name: String, parent: Node3D, scale_amount: float) -> Node3D:
	var model := Node3D.new()
	model.name = node_name
	model.scale = Vector3.ONE * scale_amount
	model.rotation.y = PI
	model.position = Vector3(0.0, 0.065, -0.05)
	parent.add_child(model)
	return model
