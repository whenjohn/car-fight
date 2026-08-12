shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;

// Faint owner-only steering reference after the opaque dissolve has completed.
// The material is present from spawn with strength zero, keeping its GL
// Compatibility pipeline warm instead of compiling it on the first Q press.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float cloak_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rim_color : source_color = vec4(0.28, 0.72, 1.0, 1.0);
uniform float distortion_strength : hint_range(0.0, 0.03) = 0.0035;
uniform float body_alpha : hint_range(0.0, 1.0) = 0.12;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.25;
uniform float interference_alpha : hint_range(0.0, 0.1) = 0.012;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}

void fragment() {
	float coarse = value_noise(UV * 17.0 + vec2(TIME * 0.55, -TIME * 0.37));
	float fine = value_noise(UV * 53.0 + vec2(-TIME * 0.83, TIME * 0.62));
	vec2 distortion = (vec2(coarse, fine) - vec2(0.5))
		* distortion_strength * cloak_strength;
	vec3 refracted = texture(screen_texture, SCREEN_UV + distortion).rgb;
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 2.15);
	float sweep_distance = abs(fract(UV.y - TIME * 0.23) - 0.5);
	float sweep = 1.0 - smoothstep(0.015, 0.075, sweep_distance);
	float interference = 0.5 + 0.5 * sin(UV.y * 155.0 + TIME * 7.0 + coarse * 9.0);
	float edge = clamp((fresnel * 0.9 + sweep * 0.42) * rim_strength, 0.0, 1.0);
	ALBEDO = mix(refracted, rim_color.rgb, edge);
	EMISSION = rim_color.rgb * (fresnel * 0.72 + sweep * 0.48)
		* rim_strength * cloak_strength;
	ALPHA = cloak_strength * clamp(
		body_alpha + (fresnel * 0.66 + sweep * 0.28) * rim_strength
		+ interference * interference_alpha, 0.0, 1.0);
}
