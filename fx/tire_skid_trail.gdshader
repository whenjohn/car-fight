shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
stencil_mode write, compare_always, 1;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(91.7, 173.3))) * 43758.5453);
}

void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float soft_edge = 1.0 - smoothstep(0.72, 1.0, across);
	float shoulder = smoothstep(0.18, 0.58, across) * (1.0 - smoothstep(0.72, 0.96, across));
	float center_tread = 0.62 + 0.38 * smoothstep(0.13, 0.32,
		abs(sin(UV.y * 13.5 + across * 2.6)));
	float broken_rubber = 0.88 + hash(floor(vec2(UV.y * 8.0, UV.x * 5.0))) * 0.12;
	float mask = soft_edge * mix(center_tread, 1.0, shoulder * 0.45) * broken_rubber;
	if (mask * COLOR.a < 0.012) {
		discard;
	}
	vec3 dry_rubber = vec3(0.006, 0.007, 0.008);
	vec3 oily_rubber = vec3(0.018, 0.024, 0.030);
	ALBEDO = mix(dry_rubber, oily_rubber, clamp(COLOR.b - 0.72, 0.0, 0.28) / 0.28);
	ROUGHNESS = mix(0.96, 0.58, clamp(COLOR.b - 0.72, 0.0, 0.28) / 0.28);
	METALLIC = 0.0;
	ALPHA = mask * COLOR.a * 0.88;
}
