extends RefCounted
## Small symmetric obstacle set. The center stays clear for all four spawns.

static func collision_objects() -> Array[Dictionary]:
	return [
		{
			"name": "BarrierNorthWest",
			"size": Vector3(8.0, 1.2, 1.4),
			"position": Vector3(-15.0, 0.6, -13.0),
			"yaw": deg_to_rad(25.0),
			"color": Color("6c665c"),
		},
		{
			"name": "BarrierNorthEast",
			"size": Vector3(1.4, 1.2, 8.0),
			"position": Vector3(15.0, 0.6, -13.0),
			"yaw": deg_to_rad(-25.0),
			"color": Color("6c665c"),
		},
		{
			"name": "BarrierSouthWest",
			"size": Vector3(1.4, 1.2, 8.0),
			"position": Vector3(-15.0, 0.6, 13.0),
			"yaw": deg_to_rad(-25.0),
			"color": Color("6c665c"),
		},
		{
			"name": "BarrierSouthEast",
			"size": Vector3(8.0, 1.2, 1.4),
			"position": Vector3(15.0, 0.6, 13.0),
			"yaw": deg_to_rad(25.0),
			"color": Color("6c665c"),
		},
		{
			"name": "BlockNorth",
			"size": Vector3(4.0, 2.4, 4.0),
			"position": Vector3(0.0, 1.2, -22.0),
			"yaw": deg_to_rad(12.0),
			"color": Color("56656b"),
		},
		{
			"name": "BlockSouth",
			"size": Vector3(4.0, 2.4, 4.0),
			"position": Vector3(0.0, 1.2, 22.0),
			"yaw": deg_to_rad(-12.0),
			"color": Color("56656b"),
		},
	]
