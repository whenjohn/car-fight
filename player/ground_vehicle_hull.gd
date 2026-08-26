extends Node3D
## Presentation-only CC0 vehicle pack. Chassis lean and wheel animation are
## derived locally; the rollback collider remains one equal-mass sphere.

const VEHICLE_SPLITTER := preload("res://player/jeep_mesh_splitter.gd")
const CLOAK_DISSOLVE_SHADER := preload("res://fx/vehicle_cloak_dissolve.gdshader")
const CLOAK_GHOST_SHADER := preload("res://fx/vehicle_cloak_ghost.gdshader")
const CLOAK_DUST_SCRIPT := preload("res://fx/vehicle_cloak_dust.gd")
const JEEP_SCALE := 0.45
const WHEEL_RADIUS := 0.31
const OCCLUDED_SILHOUETTE_COLOR := Color(0.34, 0.76, 1.0, 1.0)
const VEHICLES := [
	{"name": "Jeep", "scene": preload("res://assets/ground_vehicle/Jeep.fbx"), "scale": 0.45},
	{"name": "Pickup", "scene": preload("res://assets/ground_vehicle/Pickup.fbx"), "scale": 0.33},
	{"name": "Sedan", "scene": preload("res://assets/ground_vehicle/Sedan.fbx"), "scale": 0.33},
	{"name": "Wagon", "scene": preload("res://assets/ground_vehicle/Wagon.fbx"), "scale": 0.33},
	{"name": "Bus", "scene": preload("res://assets/ground_vehicle/Bus.fbx"), "scale": 0.175},
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

var _body: Node3D
var _chassis_lean: Node3D
var _front_steer_nodes: Array[Node3D] = []
var _wheel_spin_nodes: Array[Node3D] = []
var _wheel_records: Array[Dictionary] = []
var _wheel_spin_angle := 0.0
var _wheel_radius := WHEEL_RADIUS
var _vehicle_scale := JEEP_SCALE
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

func _ready() -> void:
	_body = get_parent() as Node3D
	_build_selected_vehicle()
	_prepare_cloak_meshes(self)
	_prepare_occlusion_overlay(self)
	_build_cloak_dust()
	_build_cloak_ghost()
	_build_boost_echoes()

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
		_update_boost_echoes(delta, bool(inputs["boosting"]), planar_speed)
		_update_cloak(delta, rigid)

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

func cycle_vehicle() -> void:
	_vehicle_index = (_vehicle_index + 1) % VEHICLES.size()
	_clear_vehicle_visuals()
	_build_selected_vehicle()
	_prepare_cloak_meshes(self)
	_prepare_occlusion_overlay(self)
	_build_cloak_ghost()
	_build_boost_echoes()
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
	_vehicle_scale = float(vehicle["scale"])
	var source := (vehicle["scene"] as PackedScene).instantiate() as Node3D
	var source_mesh_instance := source.find_child("*", true, false) as MeshInstance3D
	var split: Dictionary = VEHICLE_SPLITTER.split(source_mesh_instance.mesh, source_mesh_instance.transform)
	source.free()
	_wheel_radius = WHEEL_RADIUS * float(vehicle["scale"]) / JEEP_SCALE

	_chassis_lean = Node3D.new()
	_chassis_lean.name = "ChassisLean"
	add_child(_chassis_lean)
	var chassis_model := _model_root("ChassisModel", _chassis_lean, float(vehicle["scale"]))
	var chassis := MeshInstance3D.new()
	chassis.name = "SeparatedChassis"
	chassis.mesh = split["chassis"]
	chassis_model.add_child(chassis)

	var wheel_model := _model_root("WheelModel", self, float(vehicle["scale"]))
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
		mount.position = Vector3(0.0, 1.30, -0.04)
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
	material.set_shader_parameter("cut_position", CLOAK_CUT_FRONT)
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
	var cut := cloak_cut_position(_cloak_strength)
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
