shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size = vec2(1152.0, 648.0);
uniform vec2 iris_center = vec2(576.0, 324.0);
uniform float iris_radius = 0.0;

void fragment() {
	// Distancia em pixels: a iris continua circular em qualquer proporcao.
	float distance_to_mario = length(UV * viewport_size - iris_center);
	float cover = iris_radius <= 0.0 ? 1.0 : smoothstep(iris_radius - 1.0, iris_radius + 1.0, distance_to_mario);
	COLOR = vec4(0.0, 0.0, 0.0, cover);
}
