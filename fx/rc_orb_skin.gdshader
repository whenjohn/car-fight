shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 deep_color : source_color = vec3(0.015, 0.12, 0.48);
uniform vec3 energy_color : source_color = vec3(0.03, 0.75, 1.0);
uniform vec3 hot_color : source_color = vec3(0.48, 1.0, 1.0);
uniform vec3 warning_color : source_color = vec3(1.0, 0.08, 0.015);
uniform float warning : hint_range(0.0, 1.0) = 0.0;
uniform bool satellite_mode = false;

void fragment() {
	float longitude = (UV.x - 0.5) * TAU;
	float latitude = (UV.y - 0.5) * PI;
	float slow_flow = sin(longitude * 3.0 + latitude * 5.0 - TIME * 2.6);
	float counter_flow = sin(longitude * -5.0 + latitude * 3.0 + TIME * 1.8);
	float filaments = smoothstep(0.48, 0.96, 0.5 + 0.27 * slow_flow + 0.23 * counter_flow);
	float cells = smoothstep(0.70, 0.98, 0.5 + 0.5 * sin(longitude * 7.0 - TIME * 3.2) * sin(latitude * 6.0 + TIME * 1.4));
	float facing = max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	float rim = pow(1.0 - facing, 2.2);
	float warning_wave = 0.5 + 0.5 * sin(TIME * mix(11.0, 23.0, warning));
	float warning_flash = warning * smoothstep(0.42, 0.92, warning_wave);
	vec3 color = mix(mix(deep_color, energy_color, clamp(0.34 + filaments * 0.56 + cells * 0.22, 0.0, 1.0)), hot_color, rim * 0.72);
	color = mix(color, warning_color, warning * 0.58);
	color = mix(color, vec3(1.0, 0.72, 0.42), warning_flash * 0.82);
	float energy = 2.25 + filaments * 2.1 + cells * 0.8 + rim * 2.8;
	if (satellite_mode) {
		color = mix(hot_color, warning_color, warning * 0.70);
		energy = 5.4 + warning_flash * 5.0;
	} else {
		energy = energy * (0.82 + 0.18 * sin(TIME * 5.0)) + warning_flash * 6.5;
	}
	ALBEDO = color * 0.62;
	EMISSION = color * energy;
}
