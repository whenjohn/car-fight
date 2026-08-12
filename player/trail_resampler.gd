extends RefCounted
## Places trail samples at fixed world-space intervals regardless of render cadence.

static func advance(anchor: Vector3, current: Vector3, spacing: float,
		max_new_points := 64) -> Dictionary:
	var points: Array[Vector3] = []
	if spacing <= 0.0 or max_new_points <= 0:
		return {"anchor": anchor, "points": points}
	var segment := current - anchor
	var distance := segment.length()
	if distance < spacing:
		return {"anchor": anchor, "points": points}
	var direction := segment / distance
	var count := mini(int(floor(distance / spacing)), max_new_points)
	var next_anchor := anchor
	for _index in range(count):
		next_anchor += direction * spacing
		points.append(next_anchor)
	return {"anchor": next_anchor, "points": points}
