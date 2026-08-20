class_name CarFightAreaWeapon
extends RefCounted
## Shared, bounded gesture layout for the server strike and every client view.

const TAP_DISTANCE := 1.2
const MAX_LENGTH := 18.0
const BOMB_COUNT := 5
const TAP_RADIUS := 2.65
const DRAG_RADIUS := 1.64

static func layout(origin: Vector3, raw_start: Vector3, raw_end: Vector3,
		max_range := 22.0) -> Dictionary:
	var start := _clamp_to_range(origin, raw_start, max_range)
	var end := _clamp_to_range(origin, raw_end, max_range)
	var drag := end - start
	drag.y = 0.0
	var is_tap := drag.length() < TAP_DISTANCE
	if is_tap:
		end = start
	else:
		end = start + drag.limit_length(MAX_LENGTH)
	var heading := end - start
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = start - origin
		heading.y = 0.0
	heading = heading.normalized() if heading.length_squared() > 0.0001 else Vector3.FORWARD
	var right := Vector3.UP.cross(heading).normalized()
	var impacts := PackedVector3Array()
	var compact_forward := [-0.85, -0.35, 0.20, 0.65, 1.05]
	var compact_side := [-1.65, 1.40, -0.60, 0.75, 0.05]
	var lateral_offsets := [-0.72, 0.58, -0.34, 0.66, -0.08]
	for index in BOMB_COUNT:
		if is_tap:
			impacts.append(start + heading * compact_forward[index] + right * compact_side[index])
		else:
			impacts.append(start.lerp(end, float(index) / float(BOMB_COUNT - 1)) \
				+ right * lateral_offsets[index])
	return {"start": start, "end": end, "impacts": impacts,
		"radius": TAP_RADIUS if is_tap else DRAG_RADIUS, "is_drag": not is_tap}

static func _clamp_to_range(origin: Vector3, point: Vector3, max_range: float) -> Vector3:
	var offset := point - origin
	offset.y = 0.0
	return origin + offset.limit_length(max_range)
