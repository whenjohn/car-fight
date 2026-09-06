extends RefCounted
## Shared admission filter for gameplay queries; network synchronization still
## includes joining bodies so owners can validate real authoritative state.

static func active(body: Node) -> bool:
	return body != null and (not body.has_method("gameplay_active") \
		or bool(body.call("gameplay_active")))

static func children(players: Node) -> Array[Node]:
	var result: Array[Node] = []
	for body in players.get_children():
		if active(body):
			result.append(body)
	return result
