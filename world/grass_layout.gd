extends RefCounted
## Static gameplay region shared with the render-only grass. Never query blades.
const CENTER := Vector3(58.0, 0.0, 18.0)
const CHUNK_SIZE := 14.0
const CHUNKS_PER_SIDE := 3
const HALF_EXTENT := CHUNK_SIZE * CHUNKS_PER_SIDE * 0.5

static func contains(point: Vector3, margin: float = 0.0) -> bool:
	return absf(point.x - CENTER.x) < HALF_EXTENT - margin \
		and absf(point.z - CENTER.z) < HALF_EXTENT - margin
