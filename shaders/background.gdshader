shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.16, 0.11, 0.36, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.03, 0.03, 0.09, 1.0);
uniform vec4 glow_color : source_color = vec4(0.30, 0.17, 0.52, 1.0);
uniform float glow_power : hint_range(0.0, 2.0) = 0.55;

void fragment() {
	float t = clamp(UV.y, 0.0, 1.0);
	vec3 col = mix(top_color.rgb, bottom_color.rgb, t);

	float d = distance(UV, vec2(0.5, 0.45));
	float glow = pow(max(0.0, 1.0 - d), 2.5) * glow_power;
	glow *= 0.9 + 0.1 * sin(TIME * 0.6);

	COLOR = vec4(col + glow_color.rgb * glow, 1.0);
}
