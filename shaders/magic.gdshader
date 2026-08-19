shader_type spatial;

render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

void fragment() {
    // Center UV (0.5, 0.5)
    vec2 center = UV - vec2(0.5);
    float dist = length(center);

    // Soft circular falloff
    float alpha = smoothstep(0.5, 0.1, dist);

    // Magical color (tweak this)
    vec3 color = vec3(0.9, 0.3, 0.3);

    ALBEDO = color;
    ALPHA = alpha;
}