shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque, shadows_disabled;
stencil_mode write, compare_always, 1;

uniform float seed = 1.0;

varying vec3 world_position;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7)) + seed * 17.31) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float angle = atan(point.y, point.x);
	float radius = length(point);
	float wobble = sin(angle * 3.0 + seed) * 0.075
		+ sin(angle * 7.0 - seed * 1.7) * 0.035
		+ sin(angle * 11.0 + seed * 0.6) * 0.018;
	float edge = 0.84 + wobble;
	float mask = 1.0 - smoothstep(edge - 0.09, edge, radius);
	float breakup = hash(floor((point + 1.0) * 15.0));
	mask *= smoothstep(0.02, 0.16, mask + breakup * 0.055);
	if (mask < 0.012) {
		discard;
	}

	float ribbon = 0.5 + 0.5 * sin(angle * 5.0 + radius * 22.0 + seed * 2.3);
	float rainbow = smoothstep(0.62, 0.97, radius / max(edge, 0.001)) * ribbon;
	vec3 oil = mix(vec3(0.008, 0.011, 0.013), vec3(0.025, 0.032, 0.037),
		hash(floor(world_position.xz * 1.7)) * 0.55);
	vec3 sheen_a = vec3(0.10, 0.17, 0.22);
	vec3 sheen_b = vec3(0.23, 0.08, 0.19);
	oil = mix(oil, mix(sheen_a, sheen_b, ribbon), rainbow * 0.52);
	ALBEDO = oil;
	METALLIC = 0.78;
	ROUGHNESS = mix(0.12, 0.28, ribbon);
	SPECULAR = 0.92;
	ALPHA = mask * 0.94;
}
