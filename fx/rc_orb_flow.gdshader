shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 flow_color : source_color = vec3(0.04, 0.66, 1.0);
uniform vec3 hot_color : source_color = vec3(0.52, 1.0, 1.0);
uniform vec3 warning_color : source_color = vec3(1.0, 0.10, 0.015);
uniform float warning : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(INV_VIEW_MATRIX[0].xyz, 0.0), vec4(INV_VIEW_MATRIX[1].xyz, 0.0), vec4(INV_VIEW_MATRIX[2].xyz, 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float annulus = smoothstep(0.34, 0.49, radius) * (1.0 - smoothstep(0.77, 1.0, radius));
	float a = 0.5 + 0.5 * sin(angle * 4.0 - TIME * 4.6 + radius * 14.0);
	float b = 0.5 + 0.5 * sin(angle * -3.0 + TIME * 3.2 + radius * 21.0);
	float strands = smoothstep(0.60, 0.95, a) * 0.72 + smoothstep(0.72, 0.98, b) * 0.34;
	float warning_flash = warning * smoothstep(0.42, 0.92, 0.5 + 0.5 * sin(TIME * mix(11.0, 23.0, warning)));
	float alpha = annulus * strands * (0.76 + 0.24 * sin(radius * 24.0 - TIME * 7.0));
	vec3 color = mix(flow_color, hot_color, b * 0.55);
	color = mix(color, warning_color, warning * 0.65);
	ALBEDO = color * alpha;
	EMISSION = color * alpha * (3.4 + warning_flash * 4.2);
	ALPHA = alpha * 0.78;
}
