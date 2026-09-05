shader_type spatial;
render_mode cull_disabled, specular_disabled;
void fragment() {
    float w = 0.32*min(UV.y/0.22,(1.0-UV.y)/0.78);
    float edge = smoothstep(0.005,0.035,w-abs(UV.x-0.5));
    float vein = 1.0-smoothstep(0.005,0.018,abs(UV.x-0.5));
    float ribs = 1.0-smoothstep(0.02,0.08,abs(fract(UV.y*7.0-abs(UV.x-0.5)*5.0)-0.5));
    ALBEDO = COLOR.rgb * mix(0.23,1.0,edge) * (0.85+0.15*sin(UV.y*19.0));
    ALBEDO = mix(ALBEDO, COLOR.rgb*1.35,max(vein,ribs*0.35)*edge*0.45);
    EMISSION = ALBEDO*0.12;
    ROUGHNESS = 1.0;
}
