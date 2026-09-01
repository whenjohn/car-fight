shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 shadow_color : source_color = vec4(0.015, 0.022, 0.026, 0.34);

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radius = length(centered);
	float softness = 1.0 - smoothstep(0.18, 1.0, radius);
	ALBEDO = shadow_color.rgb;
	ALPHA = shadow_color.a * softness;
}
