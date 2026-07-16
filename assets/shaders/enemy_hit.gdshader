shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 tinted = mix(tex.rgb, tex.rgb * tint_color.rgb, tint_amount);
	tinted = mix(tinted, vec3(1.0), flash_amount);
	COLOR = vec4(tinted, tex.a * COLOR.a);
}
