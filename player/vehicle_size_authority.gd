extends RefCounted
## Shared validation for debug vehicle sizing that affects authoritative physics.

const ALLOWED_SCALES := [
	1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0,
	3.5, 4.0, 4.5, 5.0,
]


static func validated_scale(value: Variant) -> float:
	if value is not float and value is not int:
		return -1.0
	var requested := float(value)
	if not is_finite(requested):
		return -1.0
	for allowed_variant in ALLOWED_SCALES:
		var allowed := float(allowed_variant)
		if is_equal_approx(requested, allowed):
			return allowed
	return -1.0


static func valid_vehicle_index(value: int, vehicle_count: int) -> bool:
	return value >= 0 and value < vehicle_count
