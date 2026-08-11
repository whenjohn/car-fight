shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 ground_color : source_color = vec4(0.055, 0.085, 0.105, 1.0);
uniform vec4 fine_color : source_color = vec4(0.12, 0.24, 0.28, 1.0);
uniform vec4 major_color : source_color = vec4(0.22, 0.52, 0.58, 1.0);
uniform vec4 axis_color : source_color = vec4(0.82, 0.48, 0.20, 1.0);
uniform float fine_spacing = 1.0;
uniform float major_spacing = 4.0;

varying vec3 world_position;

float grid_line(vec2 position, float spacing, float width) {
	vec2 coordinate = position / spacing;
	vec2 derivative = max(fwidth(coordinate), vec2(0.00001));
	vec2 distance_to_line = abs(fract(coordinate - 0.5) - 0.5) / derivative;
	float closest = min(distance_to_line.x, distance_to_line.y);
	return 1.0 - smoothstep(width, width + 1.0, closest);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fine = grid_line(world_position.xz, fine_spacing, 0.55);
	float major = grid_line(world_position.xz, major_spacing, 0.9);
	vec2 axis_width = max(fwidth(world_position.xz), vec2(0.00001)) * 1.25;
	float axis_x = 1.0 - smoothstep(axis_width.y, axis_width.y * 2.0, abs(world_position.z));
	float axis_z = 1.0 - smoothstep(axis_width.x, axis_width.x * 2.0, abs(world_position.x));
	float axis = max(axis_x, axis_z);

	vec3 color = mix(ground_color.rgb, fine_color.rgb, fine * 0.42);
	color = mix(color, major_color.rgb, major * 0.82);
	color = mix(color, axis_color.rgb, axis * 0.9);
	ALBEDO = color;
	EMISSION = color * (fine * 0.05 + major * 0.16 + axis * 0.24);
	ROUGHNESS = 0.9;
}

