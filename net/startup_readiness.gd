extends RefCounted
## Startup-only admission to local input, not an authority or simulation clock.

const TIMEOUT_MSEC := 30000
enum Phase { JOINING, READY, FAILED }
var phase := Phase.JOINING
var failure := ""
var _started_msec := -1
var _clock_ready_msec := -1
var _body_id := 0
var _connected := false

func begin(now_msec: int) -> void:
	phase = Phase.JOINING
	failure = ""
	_started_msec = now_msec
	_clock_ready_msec = -1
	_body_id = 0
	_connected = false

func fail(message: String) -> void:
	phase = Phase.FAILED
	failure = message

func is_ready() -> bool:
	return phase == Phase.READY

func permits_body(body_id: int) -> bool:
	return is_ready() and body_id != 0 and body_id == _body_id

func is_failed() -> bool:
	return phase == Phase.FAILED

func observe(now_msec: int, connected: bool, clock_ready: bool, body_id: int,
		state_tick: int, consumed_tick: int, tick: int, history_start: int,
		received_msec: int) -> void:
	if is_failed() or _started_msec < 0:
		return
	if not connected:
		if _connected:
			fail("Connection lost")
		elif now_msec - _started_msec >= TIMEOUT_MSEC:
			fail("Connection timed out")
		return
	_connected = true
	if is_ready() and body_id == _body_id and body_id != 0:
		return
	if body_id != _body_id:
		if is_ready():
			begin(now_msec)
			_connected = true
		_body_id = body_id
		_clock_ready_msec = -1
	if now_msec - _started_msec >= TIMEOUT_MSEC:
		fail("Game synchronization timed out")
		return
	if not clock_ready or body_id == 0:
		_clock_ready_msec = -1
		return
	if _clock_ready_msec < 0:
		_clock_ready_msec = now_msec
	# A locally seeded history tick is not proof of a received server snapshot.
	# Require a post-validation packet and a completed rollback consumption.
	if received_msec > _clock_ready_msec and state_tick >= maxi(0, history_start) \
			and state_tick <= tick and consumed_tick >= state_tick:
		phase = Phase.READY
