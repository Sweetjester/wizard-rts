shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D surfaces : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool animate = true;
void fragment() {
    vec2 p=vec2(UV.x*4.0,1.0-UV.y);
    vec3 paint=textureGrad(surfaces,vec2(0.003,0.503)+fract(p)*0.494,dFdx(p)*0.494,dFdy(p)*0.494).rgb;
    paint=mix(paint,vec3(0.06,0.30,0.35),0.43);
    float pulse=animate ? 0.95+0.05*sin(TIME*0.7+UV.y*3.0) : 1.0;
    ALBEDO=paint*0.85;
    EMISSION=paint*0.72*pulse;
    ROUGHNESS=0.72;
}
