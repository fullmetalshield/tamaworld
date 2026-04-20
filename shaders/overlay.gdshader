shader_type canvas_item;

// CSS mix-blend-mode: overlay
// Samples whatever is drawn behind this sprite via the back buffer,
// then outputs the overlay-blended color with the sprite's alpha.
// Godot's default blend_mix will then mix it over the base using that alpha,
// which matches the CSS semantics.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

vec3 css_overlay(vec3 base, vec3 blend) {
	vec3 low = 2.0 * base * blend;
	vec3 high = 1.0 - 2.0 * (1.0 - base) * (1.0 - blend);
	return mix(low, high, step(0.5, base));
}

void fragment() {
	vec4 top = texture(TEXTURE, UV);
	vec4 back = texture(screen_tex, SCREEN_UV);
	vec3 blended = css_overlay(back.rgb, top.rgb);
	// Mask by back.a so the blend only shows over opaque pixels (the body).
	COLOR = vec4(blended, top.a * back.a);
}
