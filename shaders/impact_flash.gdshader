shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, blend_mix;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    ALBEDO = flash_color.rgb;
    ALPHA = intensity;
}