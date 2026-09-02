extends RefCounted
## The production world has one authoritative map. Keep the explicit map ID so
## the established network state schema remains unchanged.

const CITY := 0
const CITY_CENTER := Vector3.ZERO
const CITY_HALF_EXTENT := 165.0


static func map_name(map_id: int) -> String:
	match map_id:
		CITY:
			return "LOW POLY CITY"
		_:
			return "UNKNOWN"
