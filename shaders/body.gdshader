shader_type canvas_item;

// Body sprite shader:
//   opaque white   → transparent (outside character silhouette)
//   transparent    → body_color  (interior fill where color shows through)
//   opaque colored → passthrough (outline and detail)

uniform vec4 body_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float white_threshold : hint_range(0.9, 1.0) = 0.99;

void fragment() {
	vec4 px = texture(TEXTURE, UV);
	float min_rgb = min(px.r, min(px.g, px.b));
	bool is_white = px.a > white_threshold && min_rgb > white_threshold;

	if (is_white) {
		COLOR = vec4(0.0);
	} else if (px.a < 0.01) {
		COLOR = body_color;
	} else {
		COLOR = px;
	}
}
