shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.15, 0.11, 0.34, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.02, 0.02, 0.07, 1.0);
uniform vec4 glow_color : source_color = vec4(0.38, 0.22, 0.66, 1.0);
uniform float glow_power : hint_range(0.0, 2.0) = 0.62;
uniform float vignette : hint_range(0.0, 1.0) = 0.42;

void fragment() {
	float t = clamp(UV.y, 0.0, 1.0);
	vec3 col = mix(top_color.rgb, bottom_color.rgb, t);

	// Soft radial glow behind the tower, slowly breathing.
	float d = distance(UV, vec2(0.5, 0.44));
	float breathe = 0.9 + 0.1 * sin(TIME * 0.5);
	col += glow_color.rgb * pow(max(0.0, 1.0 - d), 2.4) * glow_power * breathe;

	// Faint vertical beam.
	float beam = exp(-pow((UV.x - 0.5) * 4.5, 2.0)) * 0.06;
	col += glow_color.rgb * beam;

	// Vignette keeps the focus in the middle.
	col *= 1.0 - vignette * pow(distance(UV, vec2(0.5)) * 0.98, 2.2);

	COLOR = vec4(col, 1.0);
}
