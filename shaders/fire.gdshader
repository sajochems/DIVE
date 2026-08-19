shader_type spatial;

render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform sampler2D noise_tex;
uniform float speed = 2.0;
uniform float noise_scale = 5.0;
uniform float distortion = 0.2;
uniform float height_fade = 1.5;

void fragment() {
    vec2 uv = UV;

    float t = TIME * speed;

    // Animate noise upward
    vec2 noise_uv = uv * noise_scale;
    noise_uv.y -= t;

    float n = texture(noise_tex, noise_uv).r;

    // Distort horizontally for flicker
    uv.x += (n - 0.5) * distortion * uv.y;

    // Shape flame vertically
    float mask = pow(1.0 - uv.y, height_fade);

    float intensity = n * mask;

    // Fire gradient
    vec3 color = vec3(0.0);

    if (intensity > 0.7) {
        color = vec3(1.0, 1.0, 0.8);
    } else if (intensity > 0.4) {
        color = vec3(1.0, 0.5, 0.1);
    } else if (intensity > 0.2) {
        color = vec3(0.8, 0.1, 0.0);
    }

    ALBEDO = color;
    ALPHA = intensity;
}