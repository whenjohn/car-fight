extends RefCounted
## Permanent target positions kept out of the ramp and central obstacle lanes.

static func positions() -> Array[Vector3]:
	return [
		Vector3(-8.0, 0.75, 0.0), Vector3(8.0, 0.75, 0.0),
		Vector3(0.0, 0.75, -7.0), Vector3(0.0, 0.75, 7.0),
		Vector3(-18.0, 0.75, 7.0), Vector3(18.0, 0.75, 7.0),
		Vector3(-22.0, 0.75, -22.0), Vector3(22.0, 0.75, -22.0),
		Vector3(-22.0, 0.75, 24.0), Vector3(22.0, 0.75, 24.0),
		Vector3(0.0, 0.75, 34.0), Vector3(28.0, 0.75, 0.0),
	]
