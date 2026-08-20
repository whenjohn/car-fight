shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.12, 0.015);
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float radius = length(p);
	float edge = 1.0 - smoothstep(0.78, 0.86, radius);
	float outer_ring = 1.0 - smoothstep(0.025, 0.065, abs(radius - 0.80));
	float closing_radius = mix(0.72, 0.12, progress);
	float closing_ring = 1.0 - smoothstep(0.025, 0.065, abs(radius - closing_radius));
	float spokes = pow(max(0.0, cos(atan(p.y, p.x) * 8.0 + TIME * 1.8)), 18.0);
	spokes *= smoothstep(0.25, 0.42, radius) * (1.0 - smoothstep(0.64, 0.76, radius));
	float pulse = 0.72 + 0.28 * sin(TIME * 7.0 + progress * 5.0);
	float alpha = max(outer_ring, closing_ring * pulse);
	alpha = max(alpha, spokes * 0.32);
	alpha *= edge * smoothstep(1.02, 0.90, radius);
	vec3 radiance = color * alpha * mix(1.4, 3.0, progress);
	ALBEDO = radiance;
	EMISSION = radiance;
	ALPHA = alpha * 0.82;
}
