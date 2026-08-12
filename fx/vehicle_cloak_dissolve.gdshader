shader_type spatial;
render_mode cull_disabled;

// The cut plane is expressed in the vehicle's moving coordinate frame. This
// keeps the wipe attached to the Jeep while it turns, rolls, jumps, or lands.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform bool use_albedo_texture = false;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float roughness_value = 0.62;
uniform float metallic_value = 0.0;
uniform vec3 vehicle_origin = vec3(0.0);
uniform vec3 vehicle_forward = vec3(0.0, 0.0, -1.0);
uniform vec3 vehicle_right = vec3(1.0, 0.0, 0.0);
uniform vec3 vehicle_up = vec3(0.0, 1.0, 0.0);
uniform float cut_position = 2.2;
uniform float edge_width = 0.16;
uniform float noise_scale = 5.8;
uniform float noise_strength = 0.20;
uniform vec3 edge_color : source_color = vec3(0.30, 0.72, 1.0);
uniform float emission_power = 4.6;

varying vec3 world_vertex;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise_3d(vec3 p) {
	vec3 cell = floor(p);
	vec3 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	float x00 = mix(hash31(cell), hash31(cell + vec3(1.0, 0.0, 0.0)), blend.x);
	float x10 = mix(hash31(cell + vec3(0.0, 1.0, 0.0)),
		hash31(cell + vec3(1.0, 1.0, 0.0)), blend.x);
	float x01 = mix(hash31(cell + vec3(0.0, 0.0, 1.0)),
		hash31(cell + vec3(1.0, 0.0, 1.0)), blend.x);
	float x11 = mix(hash31(cell + vec3(0.0, 1.0, 1.0)),
		hash31(cell + vec3(1.0, 1.0, 1.0)), blend.x);
	return mix(mix(x00, x10, blend.y), mix(x01, x11, blend.y), blend.z);
}

void vertex() {
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 offset = world_vertex - vehicle_origin;
	vec3 vehicle_vertex = vec3(
		dot(offset, vehicle_right),
		dot(offset, vehicle_up),
		dot(offset, vehicle_forward));
	float noise_value = value_noise_3d(vehicle_vertex * noise_scale);
	// Positive longitudinal distance is the nose. Lowering cut_position removes
	// the Jeep nose-to-tail; raising it reveals the Jeep tail-to-nose.
	float visible_distance = cut_position - vehicle_vertex.z
		+ (noise_value - 0.5) * noise_strength;
	if (visible_distance < 0.0) {
		discard;
	}
	float edge = 1.0 - smoothstep(0.0, edge_width, visible_distance);
	float edge_core = 1.0 - smoothstep(0.0, edge_width * 0.24, visible_distance);
	// A quick irregular pulse keeps the advancing boundary visibly electric
	// without changing which fragments the deterministic cut removes.
	float electric_pulse = 0.72 + 0.28 * sin(
		vehicle_vertex.x * 19.0 + vehicle_vertex.y * 13.0
		+ noise_value * 8.0 + TIME * 24.0);
	float electric_edge = max(edge_core, edge * electric_pulse);
	vec4 surface_color = base_color;
	if (use_albedo_texture) {
		surface_color *= texture(albedo_texture, UV);
	}
	ALBEDO = mix(surface_color.rgb, edge_color, edge);
	ROUGHNESS = mix(roughness_value, 0.18, edge);
	METALLIC = mix(metallic_value, 0.0, edge);
	// A small source-color fill prevents the lit transition from going black;
	// the much stronger blue-white emission remains confined to the cut line.
	EMISSION = surface_color.rgb * 0.18
		+ edge_color * electric_edge * emission_power;
}
