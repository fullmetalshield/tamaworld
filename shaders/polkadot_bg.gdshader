shader_type canvas_item;

// Tiled scatter of pink and light-blue dots on a white background.
// Uses FRAGCOORD so the dot size stays consistent regardless of the
// rect size, and the pattern fills any screen dimensions cleanly.

uniform vec3 bg_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 pink : source_color = vec3(0.984, 0.820, 0.831);
uniform vec3 blue : source_color = vec3(0.780, 0.890, 0.972);
uniform float cell_size = 42.0;
uniform float density : hint_range(0.0, 1.0) = 0.60;
uniform float min_radius : hint_range(0.0, 0.5) = 0.11;
uniform float max_radius : hint_range(0.0, 0.5) = 0.34;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 pos = FRAGCOORD.xy / cell_size;
	vec2 cell = floor(pos);

	vec3 col = bg_color;
	float best = 999.0;
	vec3 best_col = vec3(0.0);

	for (int dx = -1; dx <= 1; dx++) {
		for (int dy = -1; dy <= 1; dy++) {
			vec2 n = cell + vec2(float(dx), float(dy));
			if (hash2(n) > density) continue;
			vec2 c = n + vec2(hash2(n + vec2(7.0, 0.0)), hash2(n + vec2(0.0, 13.0)));
			float r = mix(min_radius, max_radius, hash2(n + vec2(21.0, 21.0)));
			float d = distance(pos, c);
			if (d < r && d < best) {
				best = d;
				best_col = hash2(n + vec2(33.0, 33.0)) > 0.5 ? pink : blue;
			}
		}
	}

	if (best < 999.0) col = best_col;
	COLOR = vec4(col, 1.0);
}
