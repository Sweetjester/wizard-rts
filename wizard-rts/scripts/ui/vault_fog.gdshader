shader_type canvas_item;
render_mode unshaded;
void fragment() {
	float band = sin(UV.y * 13.0 + sin(UV.x * 7.0 + TIME * .13) * 1.8 - TIME * .16);
	float second = sin(UV.x * 9.0 - UV.y * 5.0 + TIME * .11);
	float edge = smoothstep(0.0, .14, UV.x) * smoothstep(0.0, .14, 1.0-UV.x);
	edge *= smoothstep(0.0, .12, UV.y) * smoothstep(0.0, .12, 1.0-UV.y);
	vec3 tint = mix(vec3(.19,.28,.28), vec3(.43,.53,.48), .5 + band*.18 + second*.1);
	COLOR = vec4(tint, edge * (.52 + band*.09));
}
