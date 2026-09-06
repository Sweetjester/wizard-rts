shader_type spatial;
render_mode cull_disabled, specular_disabled;
void fragment() {
    float vein=1.0-smoothstep(0.012,0.029,abs(UV.x-0.5));
    float ribs=1.0-smoothstep(0.025,0.065,abs(fract(UV.y*5.0-abs(UV.x-0.5)*2.5)-0.5));
    ALBEDO=pow(COLOR.rgb,vec3(2.2))*(0.92+0.28*UV.y);
    ALBEDO=mix(ALBEDO,vec3(0.13,0.035,0.045),max(vein,ribs*.4)*.65);
    EMISSION=ALBEDO*.24;
    ROUGHNESS=1.0;
}
