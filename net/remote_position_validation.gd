extends RefCounted

## Pure receiver validation shared by the live transport and focused tests.

const MAX_BODIES := 64

static func classify_batch(last_sequence: int, last_publication: int, last_tick: int,
		sequence: int, publication: int, tick: int, recipient_map: int,
		id_count: int, generation_count: int, position_count: int) -> String:
	if id_count != generation_count or id_count != position_count or id_count > MAX_BODIES:
		return "malformed"
	if recipient_map < -1:
		return "malformed"
	if tick <= last_tick or publication <= last_publication or sequence <= last_sequence:
		return "stale"
	return "accept"

static func accepts_body_sample(is_server: bool, is_local: bool,
		expected_generation: int, last_tick: int, minimum_tick: int,
		generation: int, tick: int) -> bool:
	return not is_server and not is_local \
		and generation == expected_generation \
		and tick > last_tick and tick > minimum_tick

static func teleport_reset_required(last_sample_tick: int, teleport_tick: int) -> bool:
	return last_sample_tick < teleport_tick

static func valid_recipient_map(recipient_map: int, map_count: int) -> bool:
	return recipient_map == -1 or (recipient_map >= 0 and recipient_map < map_count)

static func has_valid_unique_membership(ids: PackedInt64Array,
		generations: PackedInt32Array) -> bool:
	if ids.size() != generations.size():
		return false
	var seen := {}
	for i in ids.size():
		if int(ids[i]) < 0 or int(generations[i]) < 0:
			return false
		var key := "%d:%d" % [int(ids[i]), int(generations[i])]
		if seen.has(key):
			return false
		seen[key] = true
	return true

static func is_deliverable_body(body: Node) -> bool:
	return body != null and body.is_in_group("pilotable") \
		and body.has_method("receive_remote_position")
