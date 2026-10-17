extends AnimatableBody2D

@export_group("Oscilação")
## Distancia maxima para cada lado do ponto central, em pixels. Zero deixa parada.
@export_range(0.0, 1000.0, 1.0, "or_greater", "suffix:px") var amplitude := 48.0
## Duracao de uma ida e volta completa.
@export_range(0.1, 30.0, 0.1, "or_greater", "suffix:s") var periodo := 4.0
## (1, 0) move na horizontal; (0, 1) move na vertical.
@export var eixo := Vector2.RIGHT
## Permite desencontrar o movimento de plataformas vizinhas.
@export_range(0.0, 360.0, 1.0, "suffix:deg") var fase_inicial := 0.0

var _center := Vector2.ZERO
var _elapsed := 0.0


func _ready() -> void:
	_center = position
	_update_position()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_update_position()


func _update_position() -> void:
	var phase := TAU * _elapsed / maxf(periodo, 0.1) + deg_to_rad(fase_inicial)
	position = _center + eixo.normalized() * maxf(amplitude, 0.0) * sin(phase)
