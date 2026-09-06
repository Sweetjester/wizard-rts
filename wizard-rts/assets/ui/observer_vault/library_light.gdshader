shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float clock = 0.0;

void fragment() {
	vec4 paint = texture(TEXTURE, UV);
	float candle = 0.86 + 0.08 * sin(clock * 2.3) + 0.035 * sin(clock * 5.7);
	float warm = smoothstep(0.07, 0.36, paint.r - paint.b);
	float glass = smoothstep(0.06, 0.3, paint.g - paint.r);
	// Relight the painted glass and candle pigments, never the menu text.
	vec3 lit = paint.rgb * (1.0 + strength * warm * candle * 0.24);
	lit += strength * glass * vec3(0.012, 0.052, 0.056) * (0.8 + 0.2 * sin(clock * 0.4));
	float beam_x = 0.60 + (UV.y - 0.32) * 0.3;
	float beam = max(0.0, 1.0 - abs(UV.x - beam_x) / 0.13);
	beam *= smoothstep(0.32, 0.44, UV.y) * (1.0 - smoothstep(0.65, 0.96, UV.y));
	lit += strength * beam * vec3(0.012, 0.024, 0.026);
	COLOR = vec4(lit, paint.a);
}
