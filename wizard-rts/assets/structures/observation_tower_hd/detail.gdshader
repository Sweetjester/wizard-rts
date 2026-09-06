shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform int item = 0;
uniform float glow = 1.3;
uniform bool animate = true;
void vertex() {
    if (item == 2 && animate) {
        VERTEX.z += sin(TIME * 1.2 + UV.y * 4.0) * UV.y * UV.y * 0.055;
    }
}
void fragment() {
    vec2 q = vec2(0.0);
    vec2 low = vec2(0.235,0.013);
    vec2 high = vec2(0.777,0.983);
    float mask = 1.0;
    if (item == 0 || item == 3) {
        if (item == 3) { q=vec2(1.0); low=vec2(0.17,0.008); high=vec2(0.82,0.985); }
        float half_width = min(0.5, 0.06 + UV.y * 1.20);
        mask = step(abs(UV.x-0.5), half_width);
    }
    if (item == 1) {
        q=vec2(1.0,0.0); low=vec2(0.04); high=vec2(0.96);
        mask=step(length(UV-0.5),0.495);
    }
    if (item == 2) {
        q=vec2(0.0,1.0); low=vec2(0.32,0.045); high=vec2(0.65,0.98);
        mask=step(UV.y,0.79+abs(UV.x-0.5)*0.42);
    }
    if (mask < 0.5) { discard; }
    vec3 paint = texture(atlas,(q+mix(low,high,UV))*0.5).rgb;
    ALBEDO=paint;
    ROUGHNESS=0.94;
    EMISSION=paint*0.10;
    if (item == 0) {
        float cyan=smoothstep(0.05,0.22,min(paint.g,paint.b)-paint.r);
        float pulse=animate ? 0.96+0.04*sin(TIME*0.8) : 1.0;
        EMISSION += paint * cyan * glow * pulse;
    }
}
