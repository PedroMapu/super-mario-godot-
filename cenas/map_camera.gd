extends Camera2D

## Zoom desejado. A camera aumenta esse valor se a janela exceder o mapa.
@export_range(0.1, 4.0, 0.1, "or_greater") var base_zoom := 1.0

var _map_bounds := Rect2()


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_viewport)


func set_map_bounds(bounds: Rect2) -> void:
	_map_bounds = bounds
	limit_left = ceili(bounds.position.x)
	limit_top = ceili(bounds.position.y)
	limit_right = floori(bounds.end.x)
	limit_bottom = floori(bounds.end.y)
	_fit_viewport()


func _fit_viewport() -> void:
	if not _map_bounds.has_area():
		return
	var viewport_size := get_viewport_rect().size
	var map_size := Vector2(limit_right - limit_left, limit_bottom - limit_top)
	var fitted_zoom := maxf(base_zoom, maxf(viewport_size.x / map_size.x, viewport_size.y / map_size.y))
	zoom = Vector2.ONE * fitted_zoom
	force_update_scroll()
