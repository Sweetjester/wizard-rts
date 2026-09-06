shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D masonry : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surfaces : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform int family = 0;
uniform vec4 tint : source_color = vec4(1.0);
varying vec3 point;
varying vec3 normal_world;

void vertex() {
    point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

vec3 swatch(vec2 p, vec2 quadrant) {
    return textureGrad(surfaces, quadrant * 0.5 + 0.003 + fract(p) * 0.494,
        dFdx(p) * 0.494, dFdy(p) * 0.494).rgb;
}

void fragment() {
    vec3 n = abs(normal_world);
    vec2 p = point.xy;
    if (n.x > 0.5) { p = point.zy; }
    if (n.y > 0.5) { p = point.xz; }
    vec3 paint = texture(masonry, vec2(p.x, -p.y) / 6.0).rgb;
    if (family == 2) { paint = swatch(vec2(p.x,-p.y) / 3.5, vec2(0.0)); }
    if (family == 3) { paint = swatch(p / 4.0, vec2(1.0)); }
    if (family == 7) { paint = vec3(0.035,0.053,0.061) + paint * 0.045; }
    if (family == 6) { paint = swatch(vec2(p.x,-p.y) / 4.0, vec2(1.0,0.0)); }
    ALBEDO = paint * tint.rgb;
    ROUGHNESS = 0.95;
    EMISSION = ALBEDO * 0.11;
    if (family == 4 || family == 5) {
        paint = swatch(p / 5.0, vec2(0.0,1.0));
        ALBEDO = paint;
        EMISSION = paint * 0.8;
    }
    if (family == 8) {
        paint=mix(swatch(p/5.0,vec2(0.0,1.0)),vec3(0.04,0.16,0.18),0.7);
        ALBEDO=paint*0.6;
        EMISSION=paint*0.28;
    }
}
