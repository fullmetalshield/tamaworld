shader_type canvas_item;

// CSS mix-blend-mode: soft-light (W3C Compositing spec)

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

vec3 css_soft_light(vec3 base, vec3 blend) {
	vec3 d = mix(((16.0 * base - 12.0) * base + 4.0) * base, sqrt(base), step(0.25, base));
	vec3 low  = base - (1.0 - 2.0 * blend) * base * (1.0 - base);
	vec3 high = base + (2.0 * blend - 1.0) * (d - base);
	return mix(low, high, step(0.5, blend));
}

void fragment() {
	vec4 top = texture(TEXTURE, UV);
	vec4 back = texture(screen_tex, SCREEN_UV);
	vec3 blended = css_soft_light(back.rgb, top.rgb);
	// Mask by back.a so the blend only shows over opaque pixels (the body).
	COLOR = vec4(blended, top.a * back.a);
}
