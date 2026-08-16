extends Node3D
## Clean-room rendering ladder. Stage 0 uses only engine primitives; later
## stages add one explicitly selected car-fight presentation variable at a time.

const SAMPLE_INTERVAL_SECONDS := 1.0
const STAGE0 := "stage0-control"
const STAGE1 := "stage1-jeep"
const STAGE1_FLAT := "stage1-jeep-flat"
const STAGE1_ONE_SURFACE := "stage1-jeep-one-surface"
const STAGE1_PICKUP_ONE_SURFACE := "stage1-pickup-one-surface"

var _telemetry: FileAccess
var _stage := STAGE0
var _event_prefix := "stage0"
var _stage_details := {}
var _started_msec := 0
var _sample_elapsed := 0.0
var _last_window_mode := -1
var _auto_quit_after_seconds := -1.0
var _quit_requested := false


func _ready() -> void:
	if not _configure_stage():
		get_tree().quit(2)
		return
	_open_telemetry()
	if not _build_control_scene():
		_write_record("%s_asset_load_failed" % _event_prefix, {})
		get_tree().quit(2)
		return
	_started_msec = Time.get_ticks_msec()
	_last_window_mode = int(DisplayServer.window_get_mode())
	_configure_auto_quit()
	var start := _display_state()
	start.merge(_stage_details)
	_write_record("%s_start" % _event_prefix, start)


func _process(delta: float) -> void:
	var window_mode := int(DisplayServer.window_get_mode())
	if window_mode != _last_window_mode:
		var mode_change := _display_state()
		mode_change["previous_window_mode"] = _last_window_mode
		_write_record("window_mode_change", mode_change)
		_last_window_mode = window_mode
	_sample_elapsed += delta
	if _sample_elapsed >= SAMPLE_INTERVAL_SECONDS:
		_sample_elapsed = 0.0
		var sample := _display_state()
		sample["fps"] = Engine.get_frames_per_second()
		sample["process_ms"] = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		sample["static_memory_bytes"] = Performance.get_monitor(Performance.MEMORY_STATIC)
		sample["render_objects"] = Performance.get_monitor(
			Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		sample["render_primitives"] = Performance.get_monitor(
			Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		sample["draw_calls"] = Performance.get_monitor(
			Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_write_record("%s_sample" % _event_prefix, sample)
	_service_auto_quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_write_record("focus_in", {})
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_write_record("focus_out", {})
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_write_record("close_requested", {})


func _exit_tree() -> void:
	_write_record("%s_stop" % _event_prefix, {})
	if _telemetry != null:
		_telemetry.close()
		_telemetry = null


func _build_control_scene() -> bool:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("182235")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9c8e8")
	environment.ambient_light_energy = 0.55
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var camera := Camera3D.new()
	camera.position = Vector3(7.0, 5.5, 8.0)
	camera.look_at_from_position(camera.position, Vector3.ZERO, Vector3.UP)
	camera.current = true
	add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	light.light_energy = 1.2
	light.shadow_enabled = false
	add_child(light)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 12.0)
	plane.material = _material(Color("34485c"))
	ground.mesh = plane
	add_child(ground)

	if _stage == STAGE1 or _stage == STAGE1_FLAT or _stage == STAGE1_ONE_SURFACE:
		return _add_vehicle(
			"res://CarFightJeep.fbx", "Jeep", "jeep",
			_stage != STAGE1, _stage == STAGE1_ONE_SURFACE)
	if _stage == STAGE1_PICKUP_ONE_SURFACE:
		return _add_vehicle(
			"res://Pickup.fbx", "Pickup", "pickup", true, true)
	_add_control_box()
	return true


func _add_control_box() -> void:
	var marker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 1.0, 3.0)
	box.material = _material(Color("d98545"))
	marker.mesh = box
	marker.position = Vector3(0.0, 0.5, 0.0)
	add_child(marker)


func _add_vehicle(source_path: String, model_name: String, telemetry_prefix: String,
		use_flat_material: bool, merge_surfaces: bool) -> bool:
	var resource := load(source_path) as PackedScene
	if resource == null:
		push_error("Stage 1 could not load the %s source" % model_name)
		return false
	var vehicle := resource.instantiate() as Node3D
	if vehicle == null:
		push_error("Stage 1 could not instantiate the %s source" % model_name)
		return false
	vehicle.name = "%sPresentation" % model_name
	vehicle.scale = Vector3.ONE * 0.45
	vehicle.rotation.y = PI
	vehicle.position = Vector3(0.0, 0.065, -0.05)
	add_child(vehicle)
	var meshes := vehicle.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		push_error("Stage 1 %s source contains no mesh instances" % model_name)
		vehicle.queue_free()
		return false
	var source_surface_count := 0
	var source_vertex_count := 0
	var source_index_count := 0
	var rendered_surface_count := 0
	var rendered_vertex_count := 0
	var rendered_index_count := 0
	var invalid_attribute_value_count := 0
	var invalid_index_count := 0
	var flat_material := _material(Color("4b9b55")) if use_flat_material else null
	for child in meshes:
		var mesh_instance := child as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var source_mesh := mesh_instance.mesh
		if source_mesh == null:
			continue
		source_surface_count += source_mesh.get_surface_count()
		for surface in range(source_mesh.get_surface_count()):
			source_vertex_count += source_mesh.surface_get_array_len(surface)
			source_index_count += source_mesh.surface_get_array_index_len(surface)
			var validation := _validate_surface_arrays(
				source_mesh.surface_get_arrays(surface))
			invalid_attribute_value_count += validation["invalid_attribute_values"]
			invalid_index_count += validation["invalid_indices"]
		if merge_surfaces:
			var merged_mesh := _merge_mesh_surfaces(source_mesh)
			if merged_mesh == null:
				vehicle.queue_free()
				return false
			mesh_instance.mesh = merged_mesh
		if flat_material != null:
			mesh_instance.material_override = flat_material
		var rendered_mesh := mesh_instance.mesh
		rendered_surface_count += rendered_mesh.get_surface_count()
		for surface in range(rendered_mesh.get_surface_count()):
			rendered_vertex_count += rendered_mesh.surface_get_array_len(surface)
			rendered_index_count += rendered_mesh.surface_get_array_index_len(surface)
	var details := {
		"vehicle_model": model_name,
	}
	details["%s_geometry_mode" % telemetry_prefix] = (
		"one_surface" if merge_surfaces else "source_surfaces")
	details["%s_geometry_counts_preserved" % telemetry_prefix] = (
			source_vertex_count == rendered_vertex_count
			and source_index_count == rendered_index_count)
	details["%s_indices" % telemetry_prefix] = rendered_index_count
	details["%s_invalid_attribute_values" % telemetry_prefix] = invalid_attribute_value_count
	details["%s_invalid_indices" % telemetry_prefix] = invalid_index_count
	details["%s_material_mode" % telemetry_prefix] = (
		"flat_override" if use_flat_material else "embedded")
	details["%s_material_override" % telemetry_prefix] = use_flat_material
	details["%s_mesh_data_valid" % telemetry_prefix] = (
		invalid_attribute_value_count == 0 and invalid_index_count == 0)
	details["%s_mesh_instances" % telemetry_prefix] = meshes.size()
	details["%s_shadows" % telemetry_prefix] = false
	details["%s_source_indices" % telemetry_prefix] = source_index_count
	details["%s_source_surfaces" % telemetry_prefix] = source_surface_count
	details["%s_source_vertices" % telemetry_prefix] = source_vertex_count
	details["%s_surfaces" % telemetry_prefix] = rendered_surface_count
	details["%s_vertices" % telemetry_prefix] = rendered_vertex_count
	_stage_details = details
	if invalid_attribute_value_count > 0 or invalid_index_count > 0:
		push_error("Stage 1 %s source contains invalid mesh data" % model_name)
		vehicle.queue_free()
		return false
	return true


func _validate_surface_arrays(arrays: Array) -> Dictionary:
	var invalid_attribute_values := 0
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = (
		PackedVector3Array() if arrays[Mesh.ARRAY_NORMAL] == null
		else arrays[Mesh.ARRAY_NORMAL])
	var tangents: PackedFloat32Array = (
		PackedFloat32Array() if arrays[Mesh.ARRAY_TANGENT] == null
		else arrays[Mesh.ARRAY_TANGENT])
	var indices: PackedInt32Array = (
		PackedInt32Array() if arrays[Mesh.ARRAY_INDEX] == null
		else arrays[Mesh.ARRAY_INDEX])
	for value in vertices:
		if not _vector3_is_finite(value):
			invalid_attribute_values += 1
	for value in normals:
		if not _vector3_is_finite(value):
			invalid_attribute_values += 1
	for value in tangents:
		if is_nan(value) or is_inf(value):
			invalid_attribute_values += 1
	var invalid_indices := 0
	for index in indices:
		if index < 0 or index >= vertices.size():
			invalid_indices += 1
	return {
		"invalid_attribute_values": invalid_attribute_values,
		"invalid_indices": invalid_indices,
	}


func _vector3_is_finite(value: Vector3) -> bool:
	return not (
		is_nan(value.x) or is_inf(value.x)
		or is_nan(value.y) or is_inf(value.y)
		or is_nan(value.z) or is_inf(value.z))


func _merge_mesh_surfaces(source: Mesh) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for surface in range(source.get_surface_count()):
		if source.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			push_error("One-surface Jeep requires triangle source surfaces")
			return null
		tool.append_from(source, surface, Transform3D.IDENTITY)
	var merged := tool.commit()
	if merged == null or merged.get_surface_count() != 1:
		push_error("One-surface Jeep merge did not create exactly one surface")
		return null
	return merged


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material


func _configure_stage() -> bool:
	var requested := OS.get_environment("CAR_FIGHT_BISECT_STAGE")
	if requested.is_empty() or requested == STAGE0:
		_stage = STAGE0
		_event_prefix = "stage0"
		return true
	if requested == STAGE1:
		_stage = STAGE1
		_event_prefix = "stage1"
		return true
	if requested == STAGE1_FLAT:
		_stage = STAGE1_FLAT
		_event_prefix = "stage1flat"
		return true
	if requested == STAGE1_ONE_SURFACE:
		_stage = STAGE1_ONE_SURFACE
		_event_prefix = "stage1one"
		return true
	if requested == STAGE1_PICKUP_ONE_SURFACE:
		_stage = STAGE1_PICKUP_ONE_SURFACE
		_event_prefix = "stage1pickup"
		return true
	push_error("Unknown render-isolation stage: %s" % requested)
	return false


func _configure_auto_quit() -> void:
	var value := OS.get_environment("CAR_FIGHT_BISECT_AUTO_QUIT_SECONDS")
	if value.is_empty():
		return
	_auto_quit_after_seconds = maxf(float(value), 1.0)


func _service_auto_quit() -> void:
	if _quit_requested or _auto_quit_after_seconds < 0.0:
		return
	var elapsed_seconds := float(Time.get_ticks_msec() - _started_msec) / 1000.0
	if elapsed_seconds < _auto_quit_after_seconds:
		return
	_quit_requested = true
	_write_record("auto_quit", {"elapsed_seconds": elapsed_seconds})
	get_tree().quit()


func _open_telemetry() -> void:
	var path := OS.get_environment("CAR_FIGHT_BISECT_TELEMETRY")
	if path.is_empty():
		return
	_telemetry = FileAccess.open(path, FileAccess.WRITE)
	if _telemetry == null:
		push_warning("Could not open render-control telemetry: %s" % error_string(
			FileAccess.get_open_error()))


func _write_record(event: String, data: Dictionary) -> void:
	if _telemetry == null:
		return
	var record := data.duplicate()
	record["event"] = event
	record["stage"] = _stage
	record["pid"] = OS.get_process_id()
	record["monotonic_msec"] = Time.get_ticks_msec()
	record["unix_time"] = Time.get_unix_time_from_system()
	_telemetry.store_line(JSON.stringify(record))
	_telemetry.flush()


func _display_state() -> Dictionary:
	var screen := DisplayServer.window_get_current_screen()
	return {
		"display_driver": DisplayServer.get_name(),
		"rendering_method": str(ProjectSettings.get_setting(
			"rendering/renderer/rendering_method", "unknown")),
		"rendering_driver": _rendering_string("get_current_rendering_driver_name"),
		"video_adapter": _rendering_string("get_video_adapter_name"),
		"video_vendor": _rendering_string("get_video_adapter_vendor"),
		"window_mode": int(DisplayServer.window_get_mode()),
		"window_size": _vector2i_array(DisplayServer.window_get_size()),
		"window_position": _vector2i_array(DisplayServer.window_get_position()),
		"window_focused": DisplayServer.window_is_focused(),
		"screen": screen,
		"screen_size": _vector2i_array(DisplayServer.screen_get_size(screen)),
		"screen_refresh_hz": DisplayServer.screen_get_refresh_rate(screen),
	}


func _rendering_string(method: String) -> String:
	return str(RenderingServer.call(method)) if RenderingServer.has_method(method) else "unknown"


func _vector2i_array(value: Vector2i) -> Array[int]:
	return [value.x, value.y]
