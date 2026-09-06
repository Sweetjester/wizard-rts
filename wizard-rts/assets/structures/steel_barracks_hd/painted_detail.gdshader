shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 quadrant = vec2(0.0);
uniform float glow = 0.0;
uniform float wind = 0.0;
void vertex() {
    VERTEX.z += sin(TIME * 1.3 + UV.x * 5.0) * UV.y * wind;
}
void fragment() {
    vec2 uv = quadrant * 0.5 + vec2(0.006) + UV * 0.488;
    vec3 color = texture(atlas, uv).rgb;
    ALBEDO = color;
    ROUGHNESS = 1.0;
    SPECULAR = 0.05;
    float amber = smoothstep(0.09, 0.4, color.r - color.b);
    EMISSION = color * amber * glow;
}
