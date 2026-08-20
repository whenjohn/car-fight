shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// Ported from G2's isometric homing-missile seeker skin.
uniform vec3 shell_color : source_color = vec3(0.92, 0.035, 0.58);
uniform vec3 hot_color : source_color = vec3(0.32, 0.92, 1.0);

void fragment() {
	float scan = 0.5 + 0.5 * sin((UV.y * 5.0 - TIME * 3.2) * 6.2831853);
	float chevron = smoothstep(0.56, 0.96, 1.0 - abs(fract(UV.x * 2.0 + UV.y * 1.7 - TIME * 0.8) - 0.5) * 2.0);
	float nose = 1.0 - smoothstep(0.02, 0.45, UV.y);
	vec3 color = mix(shell_color, hot_color, max(nose, scan * chevron * 0.75));
	ALBEDO = color;
	EMISSION = color * (2.1 + nose * 1.8 + scan * 0.35);
}
