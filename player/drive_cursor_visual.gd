extends RefCounted
## Material policy for the local speed-and-trajectory cursor.

const RENDER_PRIORITY := 3


static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.82
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA \
		if color.a < 0.999 else BaseMaterial3D.TRANSPARENCY_DISABLED
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Direct control feedback must remain legible over city geometry.
	result.no_depth_test = true
	result.render_priority = RENDER_PRIORITY
	return result
