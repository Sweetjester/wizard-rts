shader_type spatial;
render_mode cull_disabled;
uniform sampler2D paint : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float repeats_per_cell = 0.333333;
varying vec3 world_point;
varying vec3 world_normal;
void vertex() {
    world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    vec3 weights = pow(abs(world_normal), vec3(12.0));
    weights /= max(dot(weights, vec3(1.0)), 0.0001);
    vec3 p = world_point * repeats_per_cell;
    vec3 color = texture(paint, p.zy).rgb * weights.x
        + texture(paint, p.xz).rgb * weights.y
        + texture(paint, p.xy).rgb * weights.z;
    ALBEDO = color * tint.rgb;
    ROUGHNESS = 1.0;
    SPECULAR = 0.1;
}
