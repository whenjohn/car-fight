shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

uniform float age = 0.0;
uniform float duration = 3.6;
varying vec2 local_position;

void vertex() {
	local_position = VERTEX.xz;
}

void fragment() {
	float r = length(local_position);
	float edge = 1.0 - smoothstep(0.84, 1.0, r);
	float angle = atan(local_position.y, local_position.x);
	float arcs = smoothstep(0.80, 0.98, 0.5 + 0.5 * sin(angle * 11.0 + r * 17.0 - TIME * 2.2));
	float rings = smoothstep(0.70, 0.98, 0.5 + 0.5 * sin(r * 38.0 - TIME * 5.5));
	float ignition = smoothstep(0.0, 0.22, age);
	float fade = 1.0 - smoothstep(duration - 0.7, duration, age);
	float alpha = max(arcs * 0.55, rings * 0.35) * edge * ignition * fade;
	vec3 radiance = mix(vec3(1.0, 0.08, 0.01), vec3(1.0, 0.58, 0.045), arcs) * alpha * 3.2;
	ALBEDO = radiance;
	EMISSION = radiance;
	ALPHA = alpha * 0.75;
}
