extends RefCounted

## Pure per-recipient selection for the remote-position presentation stream.
## Samples are settled once after rollback, including map and position from the
## same publication point. Nothing here mutates simulation or gameplay state.

const MODE_ALL := "all"
const MODE_SAME_MAP := "same-map"
const UNKNOWN_MAP := -1

static func valid_mode(mode: String) -> bool:
	return mode in [MODE_ALL, MODE_SAME_MAP]

static func select(samples: Array, recipient_id: int, recipient_map: int,
		mode: String, include_self: bool) -> Array:
	var selected: Array = []
	for sample in samples:
		if not include_self and int(sample["id"]) == recipient_id:
			continue
		if mode == MODE_SAME_MAP:
			if recipient_map == UNKNOWN_MAP or int(sample["map"]) != recipient_map:
				continue
		selected.append(sample)
	return selected

static func membership_key(body_id: int, generation: int) -> String:
	return "%d:%d" % [body_id, generation]

static func membership_from_arrays(ids: PackedInt64Array,
		generations: PackedInt32Array) -> Dictionary:
	var membership := {}
	for i in ids.size():
		membership[membership_key(int(ids[i]), int(generations[i]))] = {
			"id": int(ids[i]),
			"generation": int(generations[i]),
		}
	return membership

static func membership_delta(previous: Dictionary, current: Dictionary) -> Dictionary:
	var entered := {}
	var left := {}
	for key in current:
		if not previous.has(key):
			entered[key] = current[key]
	for key in previous:
		if not current.has(key):
			left[key] = previous[key]
	return {"entered": entered, "left": left}
