extends SceneTree

const MAP_LAYOUT := preload("res://world/map_layout.gd")
const COURSE := preload("res://world/driving_course.gd")
const ARENA_CONFIG := preload("res://world/arena_config.gd")


func _init() -> void:
	if MAP_LAYOUT.COURSE_CENTER.x <= ARENA_CONFIG.HALF_EXTENT \
			+ MAP_LAYOUT.COURSE_HALF_EXTENT + 40.0:
		_fail("separate maps need a clear physical gap")
		return
	var sections := COURSE.sections()
	if sections.size() != 7:
		_fail("expected seven stable A-G test sections")
		return
	var ids := ""
	for section in sections:
		ids += str(section["id"])
		var points: Array = section["points"]
		if points.size() < 2:
			_fail("section %s has no driveable leg" % section["id"])
			return
		for point in points:
			var local := point as Vector2
			if maxf(absf(local.x), absf(local.y)) \
					>= MAP_LAYOUT.COURSE_HALF_EXTENT - 5.0:
				_fail("section %s leaves the course walls" % section["id"])
				return
	if ids != "ABCDEFG":
		_fail("section vocabulary must remain A-G")
		return
	for index in range(sections.size() - 1):
		var current_points: Array = sections[index]["points"]
		var next_points: Array = sections[index + 1]["points"]
		if not (current_points.back() as Vector2).is_equal_approx(next_points.front()):
			_fail("track must be continuous between %s and %s" % [
				sections[index]["id"], sections[index + 1]["id"]])
			return
	var final_points: Array = sections.back()["points"]
	var first_points: Array = sections.front()["points"]
	if not (final_points.back() as Vector2).is_equal_approx(first_points.front()):
		_fail("section G must close the circuit back to A")
		return
	if COURSE.legs().size() < 16:
		_fail("course needs enough legs for sweepers, hairpin, and slalom")
		return
	if COURSE.off_track(MAP_LAYOUT.course_start()):
		_fail("jump arrival must land safely on section A")
		return
	if not COURSE.off_track(MAP_LAYOUT.COURSE_CENTER):
		_fail("open interior must flash instead of becoming a shortcut")
		return
	var c_mid := COURSE.world_point(Vector2(82.0, -5.0))
	if str(COURSE.section_at(c_mid)["id"]) != "C":
		_fail("the tight 90 must report stable section C vocabulary")
		return
	var to_course := MAP_LAYOUT.transition(MAP_LAYOUT.ARENA,
		MAP_LAYOUT.ARENA_GATE, 1.2)
	if int(to_course.get("map_id", -1)) != MAP_LAYOUT.DRIVING_COURSE \
			or COURSE.off_track(to_course.get("position", Vector3.ZERO)):
		_fail("arena gate must land on the driving course")
		return
	var to_arena := MAP_LAYOUT.transition(MAP_LAYOUT.DRIVING_COURSE,
		MAP_LAYOUT.course_gate(), 1.2)
	if int(to_arena.get("map_id", -1)) != MAP_LAYOUT.ARENA \
			or MAP_LAYOUT.gate_index_at(MAP_LAYOUT.ARENA,
				to_arena.get("position", Vector3.ZERO)) >= 0:
		_fail("return gate must land in the arena clear of immediate retrigger")
		return
	if not MAP_LAYOUT.transition(MAP_LAYOUT.ARENA, Vector3.ZERO, 1.2).is_empty():
		_fail("ordinary arena driving must never trigger a jump")
		return
	var course_visual := COURSE.new()
	course_visual.build_presentation()
	var section_label_count := 0
	for child in course_visual.get_children():
		if child is Label3D and str(child.name).begins_with("Section"):
			section_label_count += 1
	if course_visual.get_node_or_null("DrivingCourseBand") == null \
			or section_label_count != 7:
		course_visual.free()
		_fail("course presentation must draw its path and all A-G labels")
		return
	course_visual.free()
	print("DRIVING_COURSE_TEST PASS sections=%s legs=%d" % [ids, COURSE.legs().size()])
	quit()


func _fail(message: String) -> void:
	push_error("DRIVING_COURSE_TEST FAIL: %s" % message)
	quit(1)
