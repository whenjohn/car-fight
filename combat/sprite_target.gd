extends StaticBody3D
const MATH := preload("res://player/impact_controller.gd")
const VISUAL := preload("res://fx/directional_sprite.gd")
var target_id := 10000
var hit_count := 0
var health := 3
var body_scale := 1.0
var heading := Vector3.FORWARD
var walking := false
var home := Vector3.ZERO
var age := 0.0
var visual
var _flash := 0.0
var _collision: CollisionShape3D
var network_position := Vector3.INF

func setup(id: int, size: float, with_presentation: bool) -> void:
	target_id = id
	body_scale = size
	name = "Target_%02d" % id
	add_to_group("sprite_test_target")
	collision_layer = 8
	collision_mask = 0
	_collision = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = radius()
	shape.height = height()
	_collision.shape = shape
	add_child(_collision)
	if with_presentation:
		visual = VISUAL.new()
		visual.world_height = height()
		visual.position.y = -height() * 0.5
		add_child(visual)

func radius() -> float:
	return 0.35 * body_scale

func height() -> float:
	return 1.8 * body_scale

func segment_entry(from: Vector3, to: Vector3) -> float:
	return MATH.segment_capsule_entry(from, to, global_position, Vector3.UP, radius(), height()) \
		if health > 0 else 1.01

func set_hit_count(value: int) -> void:
	hit_count = clampi(value, 0, 3)
	health = 3 - hit_count
	collision_layer = 8 if health > 0 else 0
	if visual != null and health == 0:
		visual.clip = "death"
		visual.frozen = false

func register_hit() -> void:
	if health <= 0:
		return
	set_hit_count(hit_count + 1)
	_flash = 0.13

func _process(delta: float) -> void:
	if network_position != Vector3.INF and health > 0:
		position = position.lerp(network_position, 1.0 - exp(-20.0 * delta))
	_flash = maxf(0.0, _flash - delta)
	if visual != null:
		visual.heading = heading
		visual.modulate = Color(2.0, 2.0, 2.0) if _flash > 0.0 else Color.WHITE

## Conservative advancement along two translating/rotating capsules. The
## separation bound includes translation, rotation and target movement, so a
## fast crossing cannot tunnel between endpoint overlap tests.
static func swept_vehicle_contact(previous: Transform3D, current: Transform3D,
		vehicle_radius: float, vehicle_height: float, target_from: Vector3,
		target_to: Vector3, target_radius: float, target_height: float) -> bool:
	var half_car := maxf(vehicle_height * 0.5 - vehicle_radius, 0.0)
	var half_target := maxf(target_height * 0.5 - target_radius, 0.0)
	var rotation_distance := previous.basis.get_rotation_quaternion().angle_to(current.basis.get_rotation_quaternion())
	var travel := (current.origin - previous.origin - target_to + target_from).length() \
		+ rotation_distance * half_car
	var fraction := 0.0
	for _step in 128:
		var transform := previous.interpolate_with(current, fraction)
		var axis := transform.basis.y.normalized() * half_car
		var centre := target_from.lerp(target_to, fraction)
		var closest := Geometry3D.get_closest_points_between_segments(
			transform.origin - axis, transform.origin + axis,
			centre - Vector3.UP * half_target, centre + Vector3.UP * half_target)
		var gap := closest[0].distance_to(closest[1]) - vehicle_radius - target_radius
		if gap <= 0.001:
			return true
		if travel <= 0.000001 or fraction >= 1.0:
			return false
		fraction += maxf(gap / travel * 0.9, 0.000001)
		if fraction > 1.0:
			return false
	return false
