shader_type canvas_item;
render_mode unshaded;
varying vec4 part_colour;
void vertex() { part_colour=COLOR; }
void fragment() {
    vec4 c=texture(TEXTURE,UV);
    float key=min(c.r,c.b)-c.g;
    float alpha=1.0-smoothstep(0.10,0.30,key);
    COLOR=vec4(c.rgb, c.a*alpha)*part_colour;
}
