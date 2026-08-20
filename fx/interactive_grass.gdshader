shader_type spatial;
render_mode cull_disabled, world_vertex_coords, unshaded;

uniform vec3 vehicle_positions[4];
uniform vec3 vehicle_trail_positions[4];
uniform vec3 bolt_positions[3];
uniform vec3 bolt_trail_positions[3];
uniform vec3 shockwave_position = vec3(10000.0);
uniform float shockwave_radius = 4.0;
uniform float shockwave_age = 2.1;
uniform float shockwave_active = 0.0;
uniform vec2 wind_direction = vec2(0.78, 0.42);
uniform float wind_strength : hint_range(0.0, 1.0) = 0.07;
uniform float wind_speed : hint_range(0.0, 5.0) = 0.82;
uniform vec3 root_color : source_color = vec3(0.045, 0.13, 0.05);
uniform vec3 tip_color : source_color = vec3(0.17, 0.42, 0.11);
uniform vec3 ember_color : source_color = vec3(2.1, 0.24, 0.01);

varying float blade_height;
varying float variation;
varying float heat;

float hash(float value) { return fract(sin(value * 91.173 + 17.41) * 43758.5453); }

vec2 closest_on_segment(vec2 point, vec2 start, vec2 end) {
	vec2 segment = end - start;
	float length_squared = dot(segment, segment);
	if (length_squared < 0.0001) return start;
	return start + segment * clamp(dot(point - start, segment) / length_squared, 0.0, 1.0);
}

void vertex() {
	blade_height = UV.y;
	variation = INSTANCE_CUSTOM.z;
	float phase = INSTANCE_CUSTOM.x;
	vec2 anchor = MODEL_MATRIX[3].xz;
	float tip = pow(clamp(UV.y, 0.0, 1.0), 1.55);
	float gust = smoothstep(0.72, 0.96, sin(TIME * 0.31 + dot(anchor, vec2(.15, .105))) * .5 + .5);
	vec2 bend = normalize(wind_direction) * sin(TIME * wind_speed + dot(anchor, vec2(.34, .19)) + phase)
		* gust * wind_strength;
	float flatten = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 closest = closest_on_segment(anchor, vehicle_trail_positions[i].xz, vehicle_positions[i].xz);
		vec2 away = anchor - closest;
		float distance = length(away);
		vec2 direction = distance > .001 ? away / distance : vec2(1.0, 0.0);
		// The gameplay collider is a 3 m Jeep sphere. This deliberately wider
		// visible footprint clears a channel through the tall, dense field.
		float radius = 2.15 * mix(.82, 1.18, hash(phase + float(i) * 31.0));
		float influence = 1.0 - smoothstep(radius * .08, radius, distance);
		influence *= influence * mix(.72, 1.0, hash(phase + 9.0));
		bend += direction * influence * mix(1.85, 2.65, hash(phase + 14.0));
		flatten = max(flatten, influence * mix(.38, .62, hash(phase + 23.0)));
	}
	heat = 0.0;
	for (int i = 0; i < 3; i++) {
		vec2 closest = closest_on_segment(anchor, bolt_trail_positions[i].xz, bolt_positions[i].xz);
		vec2 away = anchor - closest;
		float distance = length(away);
		vec2 direction = distance > .001 ? away / distance : vec2(1.0, 0.0);
		float radius = mix(.34, .62, hash(phase + float(i) * 19.7));
		float wake = 1.0 - smoothstep(radius * .16, radius, distance);
		wake *= wake;
		bend += direction * wake * .76;
		heat = max(heat, (1.0 - smoothstep(radius * .2, radius * 1.35, distance))
			* mix(.72, 1.0, hash(phase + 313.7)));
	}
	if (shockwave_active > .5) {
		vec2 offset = anchor - shockwave_position.xz;
		float distance = length(offset);
		vec2 direction = distance > .001 ? offset / distance : vec2(cos(phase), sin(phase));
		float progress = 1.0 - pow(1.0 - clamp(shockwave_age / .68, 0.0, 1.0), 2.4);
		float front_radius = shockwave_radius * progress;
		float ring = 1.0 - smoothstep(.08, .62, abs(distance - front_radius));
		float arrival = .68 * (1.0 - pow(1.0 - clamp(distance / max(shockwave_radius, .001), 0.0, 1.0), .42));
		float since_arrival = shockwave_age - arrival;
		float settle = smoothstep(.0, .12, since_arrival)
			* pow(clamp(1.0 - since_arrival / 1.25, 0.0, 1.0), 1.35);
		float wobble = sin(since_arrival * mix(7.0, 12.0, hash(phase + 207.5)) + phase)
			* settle * mix(.28, .58, hash(phase + 218.7));
		float effect = ring * .76 + wobble;
		bend += direction * effect * mix(.72, 1.22, hash(phase + 183.9));
		flatten = max(flatten, max(ring * .20, settle * .11));
	}
	VERTEX.xz += bend * tip;
	VERTEX.y -= flatten * tip;
}

void fragment() {
	vec3 base = mix(root_color, tip_color, smoothstep(0.0, 1.0, blade_height));
	base *= mix(.80, 1.13, variation);
	float singe = heat * smoothstep(.30, .68, blade_height);
	float ember = heat * smoothstep(.68, .92, blade_height) * step(.42, variation);
	ALBEDO = mix(base, vec3(.19, .035, .006), singe);
	ALBEDO = mix(ALBEDO, ember_color, ember * .90);
	EMISSION = ember_color * ember * 1.45;
}
