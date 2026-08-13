shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

// A quiet glass shell at rest; incoming hits briefly reveal a localized
// blue-white hot spot and an expanding ring across the curved surface.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float shield_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 impact_direction = vec3(0.0, 0.0, 1.0);
uniform float impact_age : hint_range(0.0, 1.2) = 1.2;
uniform vec4 rim_color : source_color = vec4(0.24, 0.72, 1.0, 1.0);
uniform vec4 impact_color : source_color = vec4(0.72, 0.94, 1.0, 1.0);
uniform float distortion_strength : hint_range(0.0, 0.03) = 0.0045;
uniform float displacement_strength : hint_range(0.0, 0.20) = 0.07;

varying vec3 sphere_direction;
varying float vertex_ripple;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	vec3 local_direction = normalize(VERTEX);
	vec3 hit_direction = normalize(impact_direction);
	float chord = length(local_direction - hit_direction);
	float wave_front = impact_age * 1.65;
	float ring = 1.0 - smoothstep(0.055, 0.16, abs(chord - wave_front));
	float life = 1.0 - smoothstep(0.62, 1.0, impact_age);
	vertex_ripple = ring * life;
	VERTEX += NORMAL * vertex_ripple * displacement_strength * shield_strength;
	sphere_direction = local_direction;
}

void fragment() {
	vec3 hit_direction = normalize(impact_direction);
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 2.25);
	float interference = 0.5 + 0.5 * sin(
		sphere_direction.y * 38.0 + sphere_direction.x * 17.0
		- sphere_direction.z * 23.0 + TIME * 1.8
		+ hash31(sphere_direction * 11.0) * 5.0);
	float chord = length(normalize(sphere_direction) - hit_direction);
	float wave_front = impact_age * 1.65;
	float ripple = 1.0 - smoothstep(0.035, 0.12, abs(chord - wave_front));
	float impact_life = 1.0 - smoothstep(0.64, 1.0, impact_age);
	float hot_spot = (1.0 - smoothstep(0.0, 0.34, chord))
		* (1.0 - smoothstep(0.0, 0.42, impact_age));
	float impact = max(ripple * impact_life, hot_spot);
	vec2 distortion = normalize(SCREEN_UV - vec2(0.5) + vec2(0.0001))
		* distortion_strength * (0.18 + fresnel + impact * 1.8) * shield_strength;
	vec3 refracted = texture(screen_texture, SCREEN_UV + distortion).rgb;
	float glass_mix = clamp(fresnel * 0.42 + interference * 0.025 + impact * 0.82, 0.0, 1.0);
	vec3 glass_color = mix(rim_color.rgb, impact_color.rgb, impact);
	ALBEDO = mix(refracted, glass_color, glass_mix);
	EMISSION = rim_color.rgb * (fresnel * 0.50 + interference * 0.025)
		+ impact_color.rgb * impact * 3.2;
	ALPHA = shield_strength * clamp(0.025 + fresnel * 0.22
		+ interference * 0.012 + impact * 0.70, 0.0, 0.88);
}
