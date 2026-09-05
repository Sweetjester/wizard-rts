shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform sampler2D masonry : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform int family = 0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float paint_scale = 1.0;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    vec3 n = abs(world_normal);
    vec2 p = world_position.xy;
    if (n.x > 0.5) { p = world_position.zy; }
    if (n.y > 0.5) { p = world_position.xz; }
    p *= paint_scale;
    vec3 paint = texture(masonry, p / 9.0).rgb;
    ALBEDO = paint * tint.rgb;
    ROUGHNESS = 0.96;
    // A little baked colour retains the brushwork on the unlit side.
    EMISSION = ALBEDO * 0.12;
    if (family == 2) {
        float grain = sin(p.x * 45.0 + sin(p.y * 1.7) * 1.8);
        float seam = smoothstep(0.03, 0.08, min(fract(p.x * 2.0), 1.0-fract(p.x * 2.0)));
        ALBEDO = mix(vec3(0.012, 0.019, 0.02), vec3(0.10, 0.075, 0.065) * (0.85 + grain * 0.15), seam);
        EMISSION = ALBEDO * 0.1;
    }
    if (family == 3) {
        ALBEDO = vec3(0.025, 0.048, 0.052) + paint * 0.09;
        EMISSION = vec3(0.0);
    }
    if (family == 4 || family == 5) {
        vec2 pane = fract(p / vec2(1.6, 2.4));
        vec2 edge = min(pane, 1.0-pane);
        float lead = 1.0-smoothstep(0.025, 0.055, min(edge.x, edge.y));
        float diagonal = abs(fract(p.x / 1.6 + p.y / 2.4)-0.5);
        lead = max(lead, 1.0-smoothstep(0.014, 0.035, diagonal));
        float cloud = 0.5 + 0.25*sin(p.x * 3.4 + sin(p.y * 2.1)) + 0.15*sin(p.y*6.0+p.x*2.0);
        vec3 glass = mix(vec3(0.012, 0.18, 0.21), vec3(0.12, 0.7, 0.72), cloud);
        ALBEDO = mix(glass, vec3(0.016, 0.033, 0.038), lead);
        EMISSION = glass * (1.0-lead) * 0.7;
        ROUGHNESS = 0.65;
    }
}
