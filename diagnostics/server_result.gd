extends RefCounted
## Stable formatting for the server RESULT line consumed by focused shell gates.

const FIELDS := [
	["players", "%d"], ["minpair", "%.3f"], ["contact", "%d"],
	["escapes", "%d"], ["bumps", "%d"], ["ballmax", "%.3f"],
	["maxy", "%.3f"], ["landed", "%d"], ["grounded", "%d"],
	["rebound", "%.3f"], ["tilt", "%.3f"], ["maxtilt", "%.3f"],
	["minx", "%.3f"], ["cloaked", "%d"], ["shields", "%d"],
	["boosting", "%d"], ["tractorgrabs", "%d"], ["tractorticks", "%d"],
	["shots", "%d"], ["hits", "%d"], ["ballhits", "%d"],
	["droneshots", "%d"], ["dets", "%d"], ["impacthits", "%d"],
	["shieldhits", "%d"], ["impactmax", "%.3f"], ["rcshots", "%d"],
	["rcdets", "%d"], ["rchits", "%d"], ["coursemaps", "%d"],
	["courseoff", "%d"], ["gatetransitions", "%d"],
]


static func format_line(values: Dictionary) -> String:
	var parts := PackedStringArray(["RESULT"])
	for field in FIELDS:
		var name: String = field[0]
		assert(values.has(name), "missing server result field: %s" % name)
		parts.append("%s=%s" % [name, str(field[1]) % values[name]])
	return " ".join(parts)
