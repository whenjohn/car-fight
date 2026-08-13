extends RefCounted
## Permanent target positions kept out of the ramp and central obstacle lanes.

static func positions() -> Array[Vector3]:
	return [
		Vector3(-8.0, 0.75, 0.0), Vector3(8.0, 0.75, 0.0),
		Vector3(0.0, 0.75, -7.0), Vector3(0.0, 0.75, 7.0),
		Vector3(-24.0, 0.75, 7.0), Vector3(24.0, 0.75, 7.0),
		Vector3(-36.0, 0.75, -30.0), Vector3(36.0, 0.75, -30.0),
		Vector3(-38.0, 0.75, 32.0), Vector3(38.0, 0.75, 32.0),
		Vector3(0.0, 0.75, 46.0), Vector3(46.0, 0.75, 0.0),
	]
