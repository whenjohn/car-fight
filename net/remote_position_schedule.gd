extends RefCounted

## Pure fixed-tick publication scheduling for the remote-position transport.
##
## Every transport mode uses this same function. A delayed rendered frame may cross
## several deadlines, but it produces at most one publication at the final settled
## tick. The returned `skipped` count is the number of crossed deadlines deliberately
## collapsed rather than burst as stale samples.

const VALID_RATES := [20, 30, 60]

static func configure(state: Dictionary, rate_hz: int, tickrate: int) -> void:
	assert(rate_hz in VALID_RATES)
	assert(tickrate > 0 and tickrate % rate_hz == 0)
	state.clear()
	state["period"] = tickrate / rate_hz
	state["next_tick"] = -1
	state["last_tick"] = -1

## Returns {due, tick, skipped, interval}. `tick` is always the current settled
## tick; historical deadline ticks are never returned for later transmission.
static func advance(state: Dictionary, current_tick: int) -> Dictionary:
	var period := int(state.get("period", 1))
	var last_tick := int(state.get("last_tick", -1))
	var next_tick := int(state.get("next_tick", -1))

	# A fresh synchronized clock or a test/world restart establishes a new epoch.
	if next_tick < 0 or (last_tick >= 0 and current_tick < last_tick):
		next_tick = current_tick
		state["next_tick"] = next_tick
	state["last_tick"] = current_tick

	if current_tick < next_tick:
		return {"due": false, "tick": current_tick, "skipped": 0, "interval": period}

	var crossed := 1 + (current_tick - next_tick) / period
	state["next_tick"] = next_tick + crossed * period
	return {
		"due": true,
		"tick": current_tick,
		"skipped": maxi(0, crossed - 1),
		"interval": period,
	}
