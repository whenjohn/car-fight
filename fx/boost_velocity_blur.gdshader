shader_type canvas_item;
render_mode unshaded;

// Six weighted current-frame taps trail opposite the local Jeep's screen-space travel.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 motion_direction = vec2(0.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float max_blur_pixels : hint_range(0.0, 40.0) = 18.0;

void fragment() {
	vec4 current = texture(screen_texture, SCREEN_UV);
	vec2 blur_step = motion_direction * SCREEN_PIXEL_SIZE * max_blur_pixels * strength;
	vec3 blurred = current.rgb * 0.30;
	blurred += texture(screen_texture, clamp(SCREEN_UV - blur_step * 0.20, vec2(0.001), vec2(0.999))).rgb * 0.20;
	blurred += texture(screen_texture, clamp(SCREEN_UV - blur_step * 0.42, vec2(0.001), vec2(0.999))).rgb * 0.16;
	blurred += texture(screen_texture, clamp(SCREEN_UV - blur_step * 0.66, vec2(0.001), vec2(0.999))).rgb * 0.13;
	blurred += texture(screen_texture, clamp(SCREEN_UV - blur_step * 0.84, vec2(0.001), vec2(0.999))).rgb * 0.11;
	blurred += texture(screen_texture, clamp(SCREEN_UV - blur_step, vec2(0.001), vec2(0.999))).rgb * 0.10;
	COLOR = vec4(mix(current.rgb, blurred, strength * 0.82), current.a);
}
