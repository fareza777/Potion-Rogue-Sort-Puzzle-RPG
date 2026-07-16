shader_type canvas_item;

uniform vec4 liquid_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform float selected_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	float wave = sin(uv.x * 18.0 + TIME * 2.2) * 0.008;
	float surface = smoothstep(0.49 + wave, 0.47 + wave, uv.y);
	float edge = smoothstep(0.48, 0.08, abs(uv.x - 0.5));
	float sparkle = pow(max(0.0, sin((uv.x + uv.y) * 42.0 + TIME * 1.8)), 20.0) * 0.15;
	vec3 rgb = liquid_color.rgb * (0.72 + edge * 0.35) + sparkle;
	rgb += liquid_color.rgb * selected_amount * 0.22;
	COLOR = vec4(rgb, liquid_color.a * surface);
}
