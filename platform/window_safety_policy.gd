extends Node
## Keeps rendered Car Fight windows away from the affected Intel Mac's known
## edge-to-edge presentation path. The geometry decision is pure so it can be
## regression-tested without opening a window.

signal enforced(action: String, details: Dictionary)

const CHECK_INTERVAL_SECONDS := 0.20
const SAFE_MARGIN := 48
# macOS reports a decorated window a few pixels away from the position Godot
# just requested. Treat that small, stable correction as settled; otherwise the
# safety loop moves the main window every 0.2 seconds and churns native popup
# focus forever.
const WINDOW_MANAGER_POSITION_TOLERANCE := 24

var _elapsed := 0.0
var _enabled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enabled = should_enable(OS.get_name(), Engine.get_architecture_name(),
		DisplayServer.get_name())
	if not _enabled:
		set_process(false)
		return
	_enforce_now()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < CHECK_INTERVAL_SECONDS:
		return
	_elapsed = 0.0
	_enforce_now()


func _enforce_now() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var current_mode := int(DisplayServer.window_get_mode())
	var current_borderless := DisplayServer.window_get_flag(
		DisplayServer.WINDOW_FLAG_BORDERLESS)
	var current_size := DisplayServer.window_get_size()
	var current_position := DisplayServer.window_get_position()
	var desired := desired_state(current_mode, current_borderless,
		DisplayServer.screen_get_usable_rect(screen), current_size, current_position)
	if not bool(desired["changed"]):
		return

	# Leave ordinary minimization alone, but undo every expanded presentation
	# mode before applying size and position. Rechecking is intentional because
	# macOS can report the mode transition one frame before its final geometry.
	if int(desired["mode"]) != current_mode:
		DisplayServer.window_set_mode(int(desired["mode"]))
	if bool(desired["borderless"]) != current_borderless:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,
			bool(desired["borderless"]))
	if Vector2i(desired["size"]) != current_size:
		DisplayServer.window_set_size(Vector2i(desired["size"]))
	if Vector2i(desired["position"]) != current_position:
		DisplayServer.window_set_position(Vector2i(desired["position"]))

	var details := {
		"reasons": desired["reasons"],
		"screen": screen,
		"usable_rect": _rect_array(DisplayServer.screen_get_usable_rect(screen)),
		"previous_mode": current_mode,
		"previous_borderless": current_borderless,
		"previous_size": _vector_array(current_size),
		"previous_position": _vector_array(current_position),
		"safe_mode": int(desired["mode"]),
		"safe_borderless": bool(desired["borderless"]),
		"safe_size": _vector_array(Vector2i(desired["size"])),
		"safe_position": _vector_array(Vector2i(desired["position"])),
	}
	push_warning("Intel Mac window safety enforced: %s" % ", ".join(desired["reasons"]))
	enforced.emit("window_safety_enforced", details)


static func should_enable(os_name: String, architecture: String,
		display_name: String) -> bool:
	return os_name == "macOS" and architecture == "x86_64" \
		and display_name != "headless"


static func desired_state(mode: int, borderless: bool, usable_rect: Rect2i,
		window_size: Vector2i, window_position: Vector2i) -> Dictionary:
	var reasons: Array[String] = []
	var safe_mode := mode
	if mode == DisplayServer.WINDOW_MODE_MAXIMIZED \
			or mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		safe_mode = DisplayServer.WINDOW_MODE_WINDOWED
		reasons.append("expanded_mode")

	var safe_borderless := borderless
	if borderless:
		safe_borderless = false
		reasons.append("borderless")

	var inset := Rect2i(
		usable_rect.position + Vector2i(SAFE_MARGIN, SAFE_MARGIN),
		usable_rect.size - Vector2i(SAFE_MARGIN * 2, SAFE_MARGIN * 2))
	# Very small or unusual displays still receive a positive window rectangle.
	if inset.size.x < 1 or inset.size.y < 1:
		inset = usable_rect
	# Manual resizing is unrestricted inside the safe inset. Only trim a window
	# when it would become larger than the usable inset itself; the former fixed
	# 1280x720 cap made every larger resize snap back immediately.
	var safe_size := Vector2i(
		mini(window_size.x, inset.size.x),
		mini(window_size.y, inset.size.y))
	safe_size.x = maxi(safe_size.x, 1)
	safe_size.y = maxi(safe_size.y, 1)
	if safe_size != window_size:
		reasons.append("oversize")

	var maximum_position := inset.position + inset.size - safe_size
	var safe_position := Vector2i(
		clampi(window_position.x, inset.position.x, maximum_position.x),
		clampi(window_position.y, inset.position.y, maximum_position.y))
	if absi(safe_position.x - window_position.x) <= WINDOW_MANAGER_POSITION_TOLERANCE:
		safe_position.x = window_position.x
	if absi(safe_position.y - window_position.y) <= WINDOW_MANAGER_POSITION_TOLERANCE:
		safe_position.y = window_position.y
	if safe_position != window_position:
		reasons.append("near_edge")

	return {
		"changed": not reasons.is_empty(),
		"reasons": reasons,
		"mode": safe_mode,
		"borderless": safe_borderless,
		"size": safe_size,
		"position": safe_position,
	}


static func _vector_array(value: Vector2i) -> Array[int]:
	return [value.x, value.y]


static func _rect_array(value: Rect2i) -> Array[int]:
	return [value.position.x, value.position.y, value.size.x, value.size.y]
