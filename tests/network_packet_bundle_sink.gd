extends "res://net/state_bundle.gd"
## Decode the real inherited RPCs without applying synthetic load to gameplay.

var received: Array[Dictionary] = []


func _receive_state_bundle(tick: int, is_key: bool, routes: PackedInt64Array,
		kinds: PackedByteArray, references: PackedInt32Array, payloads: Array, sender: int) -> void:
	received.append({"tick": tick, "key": is_key, "routes": routes.size(), "sender": sender})
	assert(routes.size() == kinds.size() and routes.size() == references.size() and routes.size() == payloads.size())
