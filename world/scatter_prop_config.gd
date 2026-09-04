extends RefCounted
## Lightweight, deterministic debris used by the opt-in ramming lab.
## Vehicle mass starts at 1.0; keeping every prop below 0.18 makes even the
## lightest car decisively win a collision without requiring scripted impulses.

const MASS_MAX := 0.18
const TYPES := {
	"barrel": {
		"mass": 0.18,
		"shape": "cylinder",
		"radius": 0.33,
		"height": 1.08,
		"spawn_height": 0.56,
		"bounce": 0.38,
	},
	"crate": {
		"mass": 0.14,
		"shape": "box",
		"size": Vector3(1.02, 0.82, 1.02),
		"spawn_height": 0.43,
		"bounce": 0.24,
	},
	"tire": {
		"mass": 0.08,
		"shape": "cylinder",
		"radius": 0.44,
		"height": 0.31,
		"collision_rotation": Vector3(PI * 0.5, 0.0, 0.0),
		"spawn_height": 0.46,
		"bounce": 0.62,
	},
	"mailbox": {
		"mass": 0.12,
		"shape": "box",
		"size": Vector3(0.26, 1.02, 0.46),
		"spawn_height": 0.53,
		"bounce": 0.30,
	},
}

const SPAWNS := [
	{"name": "ScatterBarrel01", "kind": "barrel", "position": Vector2(-11, -18),
		"yaw": 0.10},
	{"name": "ScatterBarrel02", "kind": "barrel", "position": Vector2(11, -10),
		"yaw": -0.18},
	{"name": "ScatterBarrel03", "kind": "barrel", "position": Vector2(-11, 12),
		"yaw": 0.28},
	{"name": "ScatterBarrel04", "kind": "barrel", "position": Vector2(11, 22),
		"yaw": -0.08},
	{"name": "ScatterCrate01", "kind": "crate", "position": Vector2(-4, -12),
		"yaw": 0.42},
	{"name": "ScatterCrate02", "kind": "crate", "position": Vector2(4, -5),
		"yaw": -0.31},
	{"name": "ScatterCrate03", "kind": "crate", "position": Vector2(-4, 6),
		"yaw": 0.17},
	{"name": "ScatterCrate04", "kind": "crate", "position": Vector2(4, 15),
		"yaw": -0.48},
	{"name": "ScatterTire01", "kind": "tire", "position": Vector2(-9, -1),
		"yaw": 0.26},
	{"name": "ScatterTire02", "kind": "tire", "position": Vector2(9, 5),
		"yaw": -0.22},
	{"name": "ScatterMailbox01", "kind": "mailbox", "position": Vector2(-12, 28),
		"yaw": 0.12},
	{"name": "ScatterMailbox02", "kind": "mailbox", "position": Vector2(12, -28),
		"yaw": -0.12},
]


static func type_config(kind: String) -> Dictionary:
	return (TYPES.get(kind, TYPES["crate"]) as Dictionary).duplicate(true)


static func spawn_position(spawn: Dictionary) -> Vector3:
	var planar: Vector2 = spawn["position"]
	var config := type_config(str(spawn["kind"]))
	return Vector3(planar.x, float(config["spawn_height"]), planar.y)

