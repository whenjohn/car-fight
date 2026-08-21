extends SceneTree

const AdaptiveDelay := preload("res://net/adaptive_presentation_delay.gd")
var failed := false

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("ADAPTIVE PRESENTATION ASSERT: %s" % message)

func configured() -> Dictionary:
	var state := {}
	AdaptiveDelay.configure(state, 75.0, 150.0, 60.0)
	return state

func batch(state: Dictionary, sequence: int, tick: int, arrival: int) -> void:
	AdaptiveDelay.observe_batch(state, sequence, tick, arrival, false)

func body(headroom: float, mode := "interp", effective := 75.0) -> Dictionary:
	return {"id": 1, "eligible": true, "warming": false,
		"headroom_msec": headroom, "effective_msec": effective,
		"render_tick": 100.0, "mode": mode}

func warm(state: Dictionary) -> int:
	var now := 0
	for i in 32:
		batch(state, i + 1, i * 2, now)
		now += 33
	AdaptiveDelay.observe_frame(state, now, 16.7, [])
	for i in 8:
		batch(state, 33 + i, 64 + i * 2, now)
		now += 33
	return now

func _initialize() -> void:
	var clean := configured()
	var now := warm(clean)
	for i in 180:
		if i % 2 == 0:
			batch(clean, int(clean["last_sequence"]) + 1,
				int(clean["last_tick"]) + 2, now)
		AdaptiveDelay.observe_frame(clean, now, 16.7, [body(45.0)])
		now += 17
	check(AdaptiveDelay.target_msec(clean) == 75.0, "clean stream left 75 ms")

	var pressured := configured()
	now = warm(pressured)
	for i in 8:
		batch(pressured, 50 + i, 100 + i * 2, now + i * 55)
	for i in 20:
		AdaptiveDelay.observe_frame(pressured, now + 1000 + i * 17, 16.7,
			[body(5.0, "extra")])
	check(AdaptiveDelay.target_msec(pressured) == 100.0,
		"sustained pressure did not raise one tier")

	var saturated := configured()
	now = warm(saturated)
	saturated["target_msec"] = 150.0
	for i in 20:
		AdaptiveDelay.observe_frame(saturated, now + 1000 + i * 17, 16.7,
			[body(-50.0, "hold", 150.0)])
	check(AdaptiveDelay.target_msec(saturated) == 150.0,
		"controller exceeded maximum")
	check(str(saturated["controller_state"]) == AdaptiveDelay.STATE_SATURATED,
		"maximum pressure was not reported saturated")

	AdaptiveDelay.reset_epoch(saturated, now + 30000)
	check(AdaptiveDelay.target_msec(saturated) == 75.0,
		"epoch reset did not restore minimum")
	print("ADAPTIVE PRESENTATION DELAY: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
