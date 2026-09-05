shader_type spatial;
render_mode specular_disabled, cull_disabled;
uniform sampler2D masonry : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float bays = 1.0;
uniform vec2 panel_size = vec2(2.0, 4.0);

void fragment() {
    vec2 p = vec2(fract(UV.x*bays), 1.0-UV.y);
    float x = abs((p.x-0.5)/0.41);
    float ceiling = 0.63 + 0.34*(1.0-pow(min(x,1.0),0.8));
    float d = min(min((0.41-abs(p.x-0.5)),p.y-0.09),ceiling-p.y);
    float aa = max(fwidth(d),0.002);
    float inside = smoothstep(0.025-aa,0.025+aa,d);
    float rim = smoothstep(-0.024-aa,-0.024+aa,d)*(1.0-inside);
    vec3 stone = texture(masonry,UV*panel_size/9.0).rgb;
    vec3 surround = mix(stone,vec3(0.035,0.07,0.075),rim);
    float bar = 1.0-smoothstep(0.012,0.023,abs(p.x-0.5));
    float diamond = abs(fract(p.x*3.0+p.y*4.0)-0.5);
    float diamond2 = abs(fract(p.x*3.0-p.y*4.0)-0.5);
    bar = max(bar,1.0-smoothstep(0.018,0.035,min(diamond,diamond2)));
    float cloud = 0.55+0.18*sin(p.x*23.0+sin(p.y*17.0))+0.1*sin(p.y*39.0);
    vec3 glass = mix(vec3(0.02,0.30,0.37),vec3(0.33,0.94,0.89),cloud);
    ALBEDO = mix(surround,mix(glass,vec3(0.018,0.052,0.057),bar),inside);
    EMISSION = glass*inside*(1.0-bar)*0.62;
    ROUGHNESS = 0.86;
}
