extends Control
## Fixed-screen heartbeat plot for one client's view of the other human Jeep.

const MAX_POINTS := 1800
const PLOT_LEFT := 132.0
const RESIDUAL_PIXELS_PER_UNIT := 900.0

var _longitudinal: Array[float] = []
var _lateral: Array[float] = []
var _frame_excess: Array[float] = []


func clear_samples() -> void:
	_longitudinal.clear()
	_lateral.clear()
	_frame_excess.clear()
	queue_redraw()


func add_sample(longitudinal: float, lateral: float, frame_excess_ms: float) -> void:
	_longitudinal.append(longitudinal)
	_lateral.append(lateral)
	_frame_excess.append(frame_excess_ms)
	if _longitudinal.size() > MAX_POINTS:
		_longitudinal.pop_front()
		_lateral.pop_front()
		_frame_excess.pop_front()
	queue_redraw()


func _draw() -> void:
	var panel := Rect2(Vector2.ZERO, size)
	draw_rect(panel, Color(0.025, 0.045, 0.055, 0.88), true)
	draw_rect(panel, Color("58717b"), false, 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(10.0, 49.0), "FORWARD TUG",
		HORIZONTAL_ALIGNMENT_LEFT, 116.0, 13, Color("a8efe1"))
	draw_string(font, Vector2(10.0, 113.0), "SIDE VIBRATION",
		HORIZONTAL_ALIGNMENT_LEFT, 116.0, 13, Color("f4a6dc"))
	var top_center := 43.0
	var bottom_center := 107.0
	draw_line(Vector2(PLOT_LEFT, top_center), Vector2(size.x - 8.0, top_center),
		Color(0.42, 0.57, 0.61, 0.55), 1.0)
	draw_line(Vector2(PLOT_LEFT, bottom_center), Vector2(size.x - 8.0, bottom_center),
		Color(0.42, 0.57, 0.61, 0.55), 1.0)
	if _longitudinal.size() < 2:
		return
	var width := maxf(size.x - PLOT_LEFT - 8.0, 1.0)
	var step := width / float(MAX_POINTS - 1)
	var first_x := size.x - 8.0 - step * float(_longitudinal.size() - 1)
	var longitudinal_points := PackedVector2Array()
	var lateral_points := PackedVector2Array()
	var stall_lines := PackedVector2Array()
	longitudinal_points.resize(_longitudinal.size())
	lateral_points.resize(_lateral.size())
	for index in range(_longitudinal.size()):
		var current_x := first_x + step * float(index)
		if _frame_excess[index] > 0.0:
			stall_lines.append(Vector2(current_x, 22.0))
			stall_lines.append(Vector2(current_x, size.y - 8.0))
		var top_current := top_center - clampf(
			_longitudinal[index] * RESIDUAL_PIXELS_PER_UNIT, -28.0, 28.0)
		var side_current := bottom_center - clampf(
			_lateral[index] * RESIDUAL_PIXELS_PER_UNIT, -28.0, 28.0)
		longitudinal_points[index] = Vector2(current_x, top_current)
		lateral_points[index] = Vector2(current_x, side_current)
	if not stall_lines.is_empty():
		draw_multiline(stall_lines, Color(1.0, 0.55, 0.22, 0.8), 1.0)
	# Keep the live diagnostic to a fixed number of canvas draw calls. Drawing
	# every segment separately made the graph itself depress browser frame rate.
	draw_polyline(longitudinal_points, Color("70e1c1"), 1.0, true)
	draw_polyline(lateral_points, Color("ef79c5"), 1.0, true)
