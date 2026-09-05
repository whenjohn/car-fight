extends RefCounted
## Server-only decisions. Inputs are simulation facts, never animation state.
const PROFILES := ["basic", "attacker", "evader", "ambusher"]

static func initial(id: int, profile: String, home: Vector3) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = id * 7919 + 17
	return {"id": id, "profile": profile, "home": home, "state": "wander",
		"destination": home, "target": 0, "last_seen": home, "lost": 4.0,
		"cooldown": float(id % 10) * 0.1, "aim": 0.0, "wander": 0,
		"evading": false, "cover": Vector3.INF, "peek": Vector3.INF,
		"hidden": 0.0, "burst": 0, "cover_retry": 0.0,
		"pace": random.randf_range(0.88, 1.12), "motion_age": 0.0,
		"drift_phase": random.randf_range(0.0, TAU), "drift_period": random.randf_range(3.0, 6.0),
		"drift_bias": random.randf_range(-0.18, 0.18)}

static func decide(s: Dictionary, position: Vector3, car: Dictionary,
		delta: float, settings: Dictionary) -> Dictionary:
	s.cooldown = maxf(0.0, s.cooldown - delta)
	s.cover_retry = maxf(0.0, s.cover_retry - delta)
	var visible := not car.is_empty() and bool(car.get("visible", false))
	if visible:
		s.last_seen = car.position
		s.lost = 0.0
	else:
		s.lost += delta
	var destination: Vector3 = s.last_seen
	var distance := planar(position, destination).length()
	var result := {"state": "wander", "destination": position, "fire": false,
		"speed": float(settings.speed), "seek_cover": false, "steer": 0.0}
	var profile: String = s.profile
	if profile == "attacker":
		# The hunter knows the eligible player's current position, including
		# behind cover. Shooting still requires actual sight and weapon range.
		result.speed *= 1.5 * s.pace
		s.motion_age += delta
		result.state = "hunt"
		if not car.is_empty():
			s.last_seen = car.position
			distance = planar(position, car.position).length()
			if not visible or distance > 6.0:
				result.destination = car.position
				result.state = "pursue"
				result.steer = s.drift_bias + 0.18 * sin(s.motion_age * TAU / s.drift_period + s.drift_phase)
			if visible and distance <= 18.0:
				_aim(s, result, delta, settings)
				if distance > 6.0 and not result.fire:
					result.state = "pursue"
			else:
				s.aim = 0.0
		else:
			s.aim = 0.0
		s.state = result.state
		return result
	if profile == "ambusher" and s.cover != Vector3.INF and not car.is_empty():
		if s.state in ["peek", "aim", "fire"] and s.burst < 3:
			result.destination = s.peek
			result.state = "peek"
			if planar(position, s.peek).length() < 0.6 and visible:
				_aim(s, result, delta, settings)
				if result.fire:
					s.burst += 1
		else:
			result.destination = s.cover
			result.state = "cover"
			if planar(position, s.cover).length() < 0.6:
				result.state = "hide"
				s.hidden += delta
				if s.hidden >= 1.0 and planar(position, car.position).length() <= 18.0:
					s.burst = 0
					s.hidden = 0.0
					result.state = "peek"
					result.destination = s.peek
		if result.state not in ["aim", "fire"]:
			s.aim = 0.0
		s.state = result.state
		return result
	if profile == "ambusher" and visible and s.cover_retry <= 0.0:
		result.seek_cover = true
		s.cover_retry = 2.0
	if profile == "evader" and not car.is_empty():
		var away := planar(car.position, position)
		var velocity: Vector3 = car.velocity
		velocity.y = 0.0
		var crossing := false
		if velocity.length_squared() > 0.01:
			var t := clampf(away.dot(velocity) / velocity.length_squared(), 0.0, 1.0)
			crossing = t > 0.0 and (away - velocity * t).length() < float(car.get("clearance", 2.5))
		s.evading = away.length() < (14.0 if s.evading else 10.0) or crossing
		if s.evading:
			var direction := away.normalized()
			if crossing:
				direction = Vector3(-velocity.z, 0, velocity.x).normalized()
				if direction.dot(away) < 0 or (is_zero_approx(direction.dot(away)) and s.id % 2 == 0):
					direction = -direction
			if direction.is_zero_approx():
				direction = Vector3.RIGHT
			result.destination = position + direction * 8.0
			result.speed *= 1.5
			result.state = "evade"
			s.aim = 0.0
			s.state = result.state
			return result
	if visible and distance <= 24.0:
		_aim(s, result, delta, settings)
	else:
		if s.lost <= 3.0:
			result.state = "watch"
		else:
			if planar(position, s.destination).length() < 0.7 or s.state != "wander":
				s.wander += 1
				var angle := fmod(float(s.id * 37 + s.wander * 137), 360.0) * PI / 180.0
				s.destination = s.home + Vector3(sin(angle), 0, cos(angle)) * 8.0
			result.destination = s.destination
			result.state = "wander"
	if result.state not in ["aim", "fire"]:
		s.aim = 0.0
	s.state = result.state
	return result

static func _aim(s: Dictionary, result: Dictionary, delta: float, settings: Dictionary) -> void:
	s.aim += delta
	result.state = "aim"
	if s.aim >= 0.35 and s.cooldown <= 0.0:
		result.fire = true
		result.state = "fire"
		s.cooldown = settings.interval

static func planar(from: Vector3, to: Vector3) -> Vector3:
	var difference := to - from
	difference.y = 0.0
	return difference
