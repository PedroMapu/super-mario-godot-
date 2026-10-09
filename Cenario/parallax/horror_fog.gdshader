shader_type canvas_item;
render_mode unshaded;

uniform vec4 fog_tint : source_color = vec4(0.50, 0.28, 0.38, 0.18);
uniform vec2 viewport_size = vec2(1152.0, 648.0);
uniform float elapsed = 0.0;
uniform float camera_shift = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 fraction = fract(p);
	vec2 blend = fraction * fraction * (3.0 - 2.0 * fraction);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

void fragment() {
	// Blocos de tres pixels integram a nevoa ao estilo do cenario.
	vec2 uv = floor(UV * viewport_size / 3.0) * 3.0 / viewport_size;
	vec2 p = vec2(uv.x * viewport_size.x / viewport_size.y * 3.0, uv.y * 4.0);
	p.x += elapsed * 0.055 + camera_shift;
	float cloud = noise(p) * 0.58 + noise(p * 2.05 + vec2(2.0, elapsed * 0.013)) * 0.29;
	cloud += noise(p * 4.1) * 0.13;
	float low_fog = smoothstep(0.28, 0.92, uv.y);
	float wisps = smoothstep(0.26, 0.78, cloud);
	COLOR = vec4(fog_tint.rgb, fog_tint.a * low_fog * wisps);
}
