shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
stencil_mode write, compare_always, 1;

void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float soft_edge = 1.0 - smoothstep(0.82, 1.0, across);
	float shoulder = smoothstep(0.34, 0.68, across)
		* (1.0 - smoothstep(0.76, 0.96, across));
	float fine_rubber_variation = 0.94 + 0.06
		* sin(UV.y * 22.0 + across * 3.0);
	float mask = soft_edge * mix(fine_rubber_variation, 1.0, shoulder * 0.55);
	if (mask * COLOR.a < 0.012) {
		discard;
	}
	vec3 dry_rubber = vec3(0.003, 0.004, 0.005);
	vec3 oily_rubber = vec3(0.018, 0.024, 0.030);
	ALBEDO = mix(dry_rubber, oily_rubber, clamp(COLOR.b - 0.72, 0.0, 0.28) / 0.28);
	ROUGHNESS = mix(0.96, 0.58, clamp(COLOR.b - 0.72, 0.0, 0.28) / 0.28);
	METALLIC = 0.0;
	ALPHA = mask * COLOR.a * 0.62;
}
