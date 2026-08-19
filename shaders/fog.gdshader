shader_type spatial;
render_mode unshaded, depth_draw_never, cull_front, blend_mix;

uniform float fog_density = 0.9;
uniform vec3 fog_color = vec3(1.0,1.0,1.0);

void fragment()
{
	float dist = length(VERTEX);
	float fog = smoothstep(0.5, 4.0, dist) * fog_density;

	ALBEDO = fog_color;
	ALPHA = fog;
}