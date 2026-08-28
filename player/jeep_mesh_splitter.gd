extends RefCounted
## Derives a chassis mesh and four independently pivotable wheel meshes from
## each combined CC0 vehicle-pack FBX. Source assets remain untouched.

const WHEEL_MATERIALS := ["Tires", "Wheel", "tire"]

static func split(source_mesh: Mesh, source_transform: Transform3D) -> Dictionary:
	var chassis := ArrayMesh.new()
	var wheel_surfaces := []
	for surface in range(source_mesh.get_surface_count()):
		var material := source_mesh.surface_get_material(surface)
		var material_name := "" if material == null else material.resource_name
		if material_name in WHEEL_MATERIALS:
			wheel_surfaces.append(surface)
		else:
			_append_surface(source_mesh, surface, source_transform, Vector3.ZERO, "", chassis)

	var wheel_bounds := {}
	for surface in wheel_surfaces:
		var arrays := source_mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for triangle in range(_triangle_count(vertices, indices)):
			var key := _wheel_key(_triangle_centroid(vertices, indices, triangle))
			for corner in range(3):
				var source_index := _vertex_index(indices, triangle, corner)
				var transformed := source_transform * vertices[source_index]
				if not wheel_bounds.has(key):
					wheel_bounds[key] = AABB(transformed, Vector3.ZERO)
				else:
					var bounds: AABB = wheel_bounds[key]
					wheel_bounds[key] = bounds.expand(transformed)

	var wheels := {}
	for key in wheel_bounds.keys():
		var bounds: AABB = wheel_bounds[key]
		var center := bounds.get_center()
		var wheel_mesh := ArrayMesh.new()
		for surface in wheel_surfaces:
			_append_surface(source_mesh, surface, source_transform, center, key, wheel_mesh)
		wheels[key] = {
			"mesh": wheel_mesh,
			"center": center,
			"front": str(key).begins_with("front"),
		}

	return {"chassis": chassis, "wheels": wheels}


## Normalizes an imported scene whose chassis and four wheels are already
## separate MeshInstance3D nodes. The returned data matches split() so the
## presentation rig can animate either source layout identically.
static func split_separated(source: Node3D) -> Dictionary:
	var chassis_sources: Array[MeshInstance3D] = []
	var wheel_sources: Array[MeshInstance3D] = []
	for candidate in source.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.name.to_lower().begins_with("wheel"):
			wheel_sources.append(mesh_instance)
		else:
			chassis_sources.append(mesh_instance)

	var wheel_center := Vector3.ZERO
	var ground_y := INF
	var wheel_bounds: Array[AABB] = []
	for wheel_source in wheel_sources:
		var bounds := wheel_source.transform * wheel_source.mesh.get_aabb()
		wheel_bounds.append(bounds)
		wheel_center += bounds.get_center()
		ground_y = minf(ground_y, bounds.position.y)
	if not wheel_sources.is_empty():
		wheel_center /= float(wheel_sources.size())
	var model_offset := Vector3(-wheel_center.x, -ground_y, -wheel_center.z)

	var chassis := ArrayMesh.new()
	for chassis_source in chassis_sources:
		for surface in range(chassis_source.mesh.get_surface_count()):
			_append_surface(chassis_source.mesh, surface, chassis_source.transform,
				-model_offset, "", chassis)

	var wheels := {}
	var wheel_radius := 0.0
	for index in range(wheel_sources.size()):
		var wheel_source := wheel_sources[index]
		var bounds := wheel_bounds[index]
		var source_center := bounds.get_center()
		var center := source_center + model_offset
		var key := "%s_%s" % [
			"front" if source_center.z >= wheel_center.z else "rear",
			"positive_x" if source_center.x >= wheel_center.x else "negative_x",
		]
		var wheel_mesh := ArrayMesh.new()
		for surface in range(wheel_source.mesh.get_surface_count()):
			_append_surface(wheel_source.mesh, surface, wheel_source.transform,
				source_center, "", wheel_mesh)
		wheels[key] = {
			"mesh": wheel_mesh,
			"center": center,
			"front": key.begins_with("front"),
		}
		wheel_radius += maxf(bounds.size.y, bounds.size.z) * 0.5
	if not wheel_sources.is_empty():
		wheel_radius /= float(wheel_sources.size())

	return {
		"chassis": chassis,
		"wheels": wheels,
		"wheel_radius": wheel_radius,
	}


## Normalizes a scene whose body and one combined four-wheel mesh are separate
## nodes. Wheel triangles are clustered around the axle midpoint after each
## node transform is applied, retaining the source material on every part.
static func split_multi_mesh(source: Node3D) -> Dictionary:
	var chassis_sources: Array[MeshInstance3D] = []
	var wheel_sources: Array[MeshInstance3D] = []
	for candidate in source.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		var is_wheel_source := false
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.mesh.surface_get_material(surface)
			if material != null and material.resource_name in WHEEL_MATERIALS:
				is_wheel_source = true
				break
		if is_wheel_source:
			wheel_sources.append(mesh_instance)
		else:
			chassis_sources.append(mesh_instance)

	var wheel_center := Vector3.ZERO
	var wheel_vertex_count := 0
	var ground_y := INF
	for wheel_source in wheel_sources:
		var wheel_transform := _transform_relative_to(wheel_source, source)
		for surface in range(wheel_source.mesh.get_surface_count()):
			var arrays := wheel_source.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var transformed := wheel_transform * vertex
				wheel_center += transformed
				wheel_vertex_count += 1
				ground_y = minf(ground_y, transformed.y)
	if wheel_vertex_count > 0:
		wheel_center /= float(wheel_vertex_count)
	var model_offset := Vector3(-wheel_center.x, -ground_y, -wheel_center.z)

	var chassis := ArrayMesh.new()
	for chassis_source in chassis_sources:
		var chassis_transform := _transform_relative_to(chassis_source, source)
		for surface in range(chassis_source.mesh.get_surface_count()):
			_append_surface(chassis_source.mesh, surface, chassis_transform,
				-model_offset, "", chassis)

	var wheel_bounds := {}
	for wheel_source in wheel_sources:
		var wheel_transform := _transform_relative_to(wheel_source, source)
		for surface in range(wheel_source.mesh.get_surface_count()):
			var arrays := wheel_source.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for triangle in range(_triangle_count(vertices, indices)):
				var centroid := wheel_transform * _triangle_centroid(
					vertices, indices, triangle)
				var key := _model_wheel_key(centroid, wheel_center)
				for corner in range(3):
					var source_index := _vertex_index(indices, triangle, corner)
					var transformed := wheel_transform * vertices[source_index]
					if not wheel_bounds.has(key):
						wheel_bounds[key] = AABB(transformed, Vector3.ZERO)
					else:
						var bounds: AABB = wheel_bounds[key]
						wheel_bounds[key] = bounds.expand(transformed)

	var wheels := {}
	var wheel_radius := 0.0
	for key_variant in wheel_bounds:
		var key := str(key_variant)
		var bounds: AABB = wheel_bounds[key]
		var source_center := bounds.get_center()
		var wheel_mesh := ArrayMesh.new()
		for wheel_source in wheel_sources:
			var wheel_transform := _transform_relative_to(wheel_source, source)
			for surface in range(wheel_source.mesh.get_surface_count()):
				_append_model_wheel_surface(wheel_source.mesh, surface,
					wheel_transform, source_center, key, wheel_center, wheel_mesh)
		wheels[key] = {
			"mesh": wheel_mesh,
			"center": source_center + model_offset,
			"front": key.begins_with("front"),
		}
		wheel_radius += maxf(bounds.size.y, bounds.size.z) * 0.5
	if not wheels.is_empty():
		wheel_radius /= float(wheels.size())

	return {
		"chassis": chassis,
		"wheels": wheels,
		"wheel_radius": wheel_radius,
	}


## Splits four wheels that share numbered/material-batch meshes with chassis
## geometry. Bounds are supplied in source space and only matching triangles
## are removed from the chassis. source_yaw normalizes non-forward FBX axes.
static func split_bounded_wheels(source: Node3D, wheel_boxes: Dictionary,
		source_yaw: float = 0.0, wheel_materials: Array = []) -> Dictionary:
	var orientation := Transform3D(Basis(Vector3.UP, source_yaw), Vector3.ZERO)
	var wheel_bounds := {}
	for candidate in source.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		var node_transform := _transform_relative_to(mesh_instance, source)
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.mesh.surface_get_material(surface)
			var material_name := "" if material == null else material.resource_name
			if not wheel_materials.is_empty() and material_name not in wheel_materials:
				continue
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for triangle in range(_triangle_count(vertices, indices)):
				var source_centroid := node_transform * _triangle_centroid(
					vertices, indices, triangle)
				var key := _bounded_wheel_key(source_centroid, wheel_boxes)
				if key.is_empty():
					continue
				for corner in range(3):
					var source_index := _vertex_index(indices, triangle, corner)
					var transformed := orientation * (node_transform * vertices[source_index])
					if not wheel_bounds.has(key):
						wheel_bounds[key] = AABB(transformed, Vector3.ZERO)
					else:
						var bounds: AABB = wheel_bounds[key]
						wheel_bounds[key] = bounds.expand(transformed)

	var wheel_center := Vector3.ZERO
	var ground_y := INF
	for bounds_variant in wheel_bounds.values():
		var bounds: AABB = bounds_variant
		wheel_center += bounds.get_center()
		ground_y = minf(ground_y, bounds.position.y)
	if not wheel_bounds.is_empty():
		wheel_center /= float(wheel_bounds.size())
	var model_offset := Vector3(-wheel_center.x, -ground_y, -wheel_center.z)

	var chassis := ArrayMesh.new()
	for candidate in source.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		var node_transform := _transform_relative_to(mesh_instance, source)
		for surface in range(mesh_instance.mesh.get_surface_count()):
			_append_bounded_surface(mesh_instance.mesh, surface, node_transform,
				orientation, model_offset, wheel_boxes, wheel_materials, "", true, chassis)

	var wheels := {}
	var wheel_radius := 0.0
	for key_variant in wheel_bounds:
		var key := str(key_variant)
		var bounds: AABB = wheel_bounds[key]
		var center := bounds.get_center()
		var wheel_mesh := ArrayMesh.new()
		for candidate in source.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := candidate as MeshInstance3D
			var node_transform := _transform_relative_to(mesh_instance, source)
			for surface in range(mesh_instance.mesh.get_surface_count()):
				_append_bounded_surface(mesh_instance.mesh, surface, node_transform,
					orientation, -center, wheel_boxes, wheel_materials, key, false, wheel_mesh)
		wheels[key] = {
			"mesh": wheel_mesh,
			"center": center + model_offset,
			"front": key.begins_with("front"),
		}
		wheel_radius += maxf(bounds.size.y, bounds.size.z) * 0.5
	if not wheels.is_empty():
		wheel_radius /= float(wheels.size())

	return {
		"chassis": chassis,
		"wheels": wheels,
		"wheel_radius": wheel_radius,
	}


static func _append_bounded_surface(source_mesh: Mesh, surface: int,
		node_transform: Transform3D, orientation: Transform3D, offset: Vector3,
		wheel_boxes: Dictionary, wheel_materials: Array, wheel_filter: String, chassis: bool,
		target: ArrayMesh) -> void:
	var arrays := source_mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normals: PackedVector3Array = PackedVector3Array() \
		if arrays[Mesh.ARRAY_NORMAL] == null else arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = PackedColorArray() \
		if arrays[Mesh.ARRAY_COLOR] == null else arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = PackedVector2Array() \
		if arrays[Mesh.ARRAY_TEX_UV] == null else arrays[Mesh.ARRAY_TEX_UV]
	var combined := orientation * node_transform
	var normal_transform := combined.basis.inverse().transposed()
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := source_mesh.surface_get_material(surface)
	builder.set_material(material)
	var material_name := "" if material == null else material.resource_name
	var can_be_wheel := wheel_materials.is_empty() or material_name in wheel_materials
	var added := 0
	for triangle in range(_triangle_count(vertices, indices)):
		var source_centroid := node_transform * _triangle_centroid(vertices, indices, triangle)
		var key := _bounded_wheel_key(source_centroid, wheel_boxes) if can_be_wheel else ""
		if (chassis and not key.is_empty()) or (not chassis and key != wheel_filter):
			continue
		for corner in range(3):
			var source_index := _vertex_index(indices, triangle, corner)
			if normals.size() > source_index:
				builder.set_normal((normal_transform * normals[source_index]).normalized())
			if colors.size() > source_index:
				builder.set_color(colors[source_index])
			if uvs.size() > source_index:
				builder.set_uv(uvs[source_index])
			builder.add_vertex(combined * vertices[source_index] + offset)
			added += 1
	if added > 0:
		builder.commit(target)


static func _bounded_wheel_key(point: Vector3, wheel_boxes: Dictionary) -> String:
	for key_variant in wheel_boxes:
		var bounds: AABB = wheel_boxes[key_variant]
		if bounds.has_point(point):
			return str(key_variant)
	return ""


static func _append_model_wheel_surface(source_mesh: Mesh, surface: int,
		source_transform: Transform3D, center: Vector3, wheel_filter: String,
		wheel_center: Vector3, target: ArrayMesh) -> void:
	var arrays := source_mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normals: PackedVector3Array = PackedVector3Array() \
		if arrays[Mesh.ARRAY_NORMAL] == null else arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = PackedColorArray() \
		if arrays[Mesh.ARRAY_COLOR] == null else arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = PackedVector2Array() \
		if arrays[Mesh.ARRAY_TEX_UV] == null else arrays[Mesh.ARRAY_TEX_UV]
	var normal_transform := source_transform.basis.inverse().transposed()
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(source_mesh.surface_get_material(surface))
	var added := 0
	for triangle in range(_triangle_count(vertices, indices)):
		var centroid := source_transform * _triangle_centroid(vertices, indices, triangle)
		if _model_wheel_key(centroid, wheel_center) != wheel_filter:
			continue
		for corner in range(3):
			var source_index := _vertex_index(indices, triangle, corner)
			if normals.size() > source_index:
				builder.set_normal((normal_transform * normals[source_index]).normalized())
			if colors.size() > source_index:
				builder.set_color(colors[source_index])
			if uvs.size() > source_index:
				builder.set_uv(uvs[source_index])
			builder.add_vertex(source_transform * vertices[source_index] - center)
			added += 1
	if added > 0:
		builder.commit(target)


static func _model_wheel_key(centroid: Vector3, center: Vector3) -> String:
	var axle := "front" if centroid.z >= center.z else "rear"
	var side := "positive_x" if centroid.x >= center.x else "negative_x"
	return "%s_%s" % [axle, side]


static func _transform_relative_to(node: Node3D, root: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != null and parent != root:
		if parent is Node3D:
			result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result

static func _append_surface(source_mesh: Mesh, surface: int, source_transform: Transform3D,
		center: Vector3, wheel_filter: String, target: ArrayMesh) -> void:
	var arrays := source_mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normals: PackedVector3Array = PackedVector3Array() if arrays[Mesh.ARRAY_NORMAL] == null else arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = PackedColorArray() if arrays[Mesh.ARRAY_COLOR] == null else arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = PackedVector2Array() if arrays[Mesh.ARRAY_TEX_UV] == null else arrays[Mesh.ARRAY_TEX_UV]
	var normal_transform := source_transform.basis.inverse().transposed()
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(source_mesh.surface_get_material(surface))
	var added := 0
	for triangle in range(_triangle_count(vertices, indices)):
		if not wheel_filter.is_empty() and _wheel_key(_triangle_centroid(vertices, indices, triangle)) != wheel_filter:
			continue
		for corner in range(3):
			var source_index := _vertex_index(indices, triangle, corner)
			if normals.size() > source_index:
				builder.set_normal((normal_transform * normals[source_index]).normalized())
			if colors.size() > source_index:
				builder.set_color(colors[source_index])
			if uvs.size() > source_index:
				builder.set_uv(uvs[source_index])
			builder.add_vertex(source_transform * vertices[source_index] - center)
			added += 1
	if added > 0:
		builder.commit(target)

static func _wheel_key(centroid: Vector3) -> String:
	var axle := "front" if centroid.y < 0.0 else "rear"
	var side := "positive_x" if centroid.x >= 0.0 else "negative_x"
	return "%s_%s" % [axle, side]

static func _triangle_centroid(vertices: PackedVector3Array, indices: PackedInt32Array,
		triangle: int) -> Vector3:
	var a := vertices[_vertex_index(indices, triangle, 0)]
	var b := vertices[_vertex_index(indices, triangle, 1)]
	var c := vertices[_vertex_index(indices, triangle, 2)]
	return (a + b + c) / 3.0

static func _triangle_count(vertices: PackedVector3Array, indices: PackedInt32Array) -> int:
	return indices.size() / 3 if not indices.is_empty() else vertices.size() / 3

static func _vertex_index(indices: PackedInt32Array, triangle: int, corner: int) -> int:
	return indices[triangle * 3 + corner] if not indices.is_empty() else triangle * 3 + corner
