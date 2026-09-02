extends RefCounted
## Permanent target positions placed along Low Poly City's three street axes.

static func positions() -> Array[Vector3]:
	return [
		# Keep the central multiplayer spawn/collision lane clear. At the old
		# eight-unit spacing a car could touch a static dummy immediately after
		# meeting another car, correctly suppressing the car-only escape assist.
		Vector3(-21.0, 0.75, 0.0), Vector3(21.0, 0.75, 0.0),
		Vector3(0.0, 0.75, -21.0), Vector3(0.0, 0.75, 21.0),
		Vector3(-63.0, 0.75, -21.0), Vector3(-63.0, 0.75, 21.0),
		Vector3(63.0, 0.75, -21.0), Vector3(63.0, 0.75, 21.0),
		Vector3(-21.0, 0.75, -63.0), Vector3(21.0, 0.75, -63.0),
		Vector3(-21.0, 0.75, 63.0), Vector3(21.0, 0.75, 63.0),
	]
