shader_type canvas_item;
// Procedural dungeon backdrop: vertical gradient, two warm torch glows
// near the top corners, subtle animated ember flicker, and a vignette.

uniform vec3 top_color: source_color = vec3(0.11, 0.075, 0.18);
uniform vec3 bottom_color: source_color = vec3(0.035, 0.025, 0.07);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color, bottom_color, uv.y);

	// Torch glows (slow flicker)
	float flicker = 0.85 + 0.15 * sin(TIME * 3.7) * sin(TIME * 1.3);
	float g1 = smoothstep(0.55, 0.0, distance(uv, vec2(0.08, 0.06)));
	float g2 = smoothstep(0.55, 0.0, distance(uv, vec2(0.92, 0.06)));
	col += vec3(0.30, 0.14, 0.04) * (g1 + g2) * 0.55 * flicker;

	// Faint magical haze around the lower play area
	float g3 = smoothstep(0.7, 0.0, distance(uv, vec2(0.5, 0.78)));
	col += vec3(0.06, 0.04, 0.12) * g3;

	// Stone speckle
	float n = hash(floor(uv * 90.0));
	col += (n - 0.5) * 0.012;

	// Vignette
	float v = distance(uv, vec2(0.5, 0.45));
	col *= 1.0 - v * 0.55;

	COLOR = vec4(col, 1.0);
}
