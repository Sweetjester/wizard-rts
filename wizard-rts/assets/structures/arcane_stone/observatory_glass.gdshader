shader_type spatial;
render_mode cull_disabled, specular_disabled;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
    float brush=noise(UV*vec2(80.0,12.0))*0.55+noise(UV*vec2(150.0,35.0))*0.2+noise(UV*8.0)*0.25;
    vec3 glass=mix(vec3(0.015,0.12,0.17),vec3(0.14,0.57,0.6),brush);
    ALBEDO=glass;
    EMISSION=glass*0.45;
    ROUGHNESS=0.65;
}
