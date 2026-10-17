extends CanvasLayer

const HEIGHT_FACTORS := [1.0, 1.0, 0.86, 1.15]
const HORIZONTAL_OFFSETS := [0.0, 0.0, -0.31, -0.65]
const MIN_REPEAT_TIMES := 2
const FOG_CAMERA_SHIFT_FACTOR := 0.30

## Cada fase pode ajustar a paleta pelo Inspetor.
@export var camera_path := NodePath("../Mario/Camera2D")
@export var sky_tint := Color(1.0, 0.78, 0.83)
@export var distant_tint := Color(0.88, 0.69, 0.82, 0.52)
@export var near_tint := Color(0.85, 0.80, 0.95, 0.90)
@export var fog_tint := Color(0.50, 0.28, 0.38, 0.18)

@onready var _layers: Array[Parallax2D] = [$Sky, $Clouds, $DistantGraves, $NearGraves]
@onready var _fog: ColorRect = $Fog
@onready var _fog_material: ShaderMaterial = $Fog.material

var _camera: Camera2D
var _camera_origin := Vector2.ZERO
var _origin_initialized := false
var _elapsed := 0.0


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera2D
	_apply_palette()
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()


func _apply_palette() -> void:
	(_layers[0].get_child(0) as Sprite2D).modulate = sky_tint
	(_layers[1].get_child(0) as Sprite2D).modulate = sky_tint
	(_layers[2].get_child(0) as Sprite2D).modulate = distant_tint
	(_layers[3].get_child(0) as Sprite2D).modulate = near_tint
	_fog_material.set_shader_parameter("fog_tint", fog_tint)


func _fit_viewport() -> void:
	var view_size := get_viewport().get_visible_rect().size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return
	for index in _layers.size():
		_fit_layer(index, view_size)
	_fog.size = view_size
	_fog_material.set_shader_parameter("viewport_size", view_size)


func _fit_layer(index: int, view_size: Vector2) -> void:
	var parallax := _layers[index]
	var image := parallax.get_child(0) as Sprite2D
	var height_factor: float = HEIGHT_FACTORS[index]
	var image_scale := view_size.y * height_factor / image.texture.get_height()
	image.scale = Vector2.ONE * image_scale
	image.position.y = view_size.y * (1.0 - height_factor)
	parallax.repeat_size = Vector2(image.texture.get_width() * image_scale, 0.0)
	parallax.repeat_times = maxi(MIN_REPEAT_TIMES, ceili(view_size.x / parallax.repeat_size.x) + 1)
	parallax.scroll_offset = Vector2(view_size.x * HORIZONTAL_OFFSETS[index], 0.0)


func _process(delta: float) -> void:
	# O tempo da nevoa acompanha a pausa da sequencia de morte.
	_elapsed += delta
	_fog_material.set_shader_parameter("elapsed", _elapsed)
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()
		_origin_initialized = false
	if _camera == null:
		return
	var camera_center := _camera.get_screen_center_position()
	if not _origin_initialized:
		_camera_origin = camera_center
		_origin_initialized = true
	var displacement := (camera_center - _camera_origin) * _camera.zoom
	# CanvasLayer cobre a tela; Parallax2D repete as artes e aplica as velocidades.
	for parallax in _layers:
		parallax.screen_offset = Vector2(displacement.x, 0.0)
	_fog_material.set_shader_parameter(
		"camera_shift", displacement.x / maxf(_fog.size.y, 1.0) * FOG_CAMERA_SHIFT_FACTOR
	)
