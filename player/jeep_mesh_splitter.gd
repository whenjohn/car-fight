extends RefCounted
## Derives a chassis mesh and four independently pivotable wheel meshes from
## each combined CC0 vehicle-pack FBX. Source assets remain untouched.

const WHEEL_MATERIALS := ["Tires", "Wheel"]

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
