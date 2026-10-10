extends StaticBody2D

enum State { IDLE, SHAKING, FALLING, DESTROYED }

@export_range(0.1, 5.0, 0.1, "suffix:s") var collapse_delay := 1.5
@export_range(0.0, 64.0, 1.0, "suffix:px") var fall_distance := 24.0
@export_range(0.01, 1.0, 0.01, "suffix:s") var fall_duration := 0.22
@export_range(0.1, 1.0, 0.05, "suffix:s") var destruction_duration := 0.35
@export_range(0.1, 10.0, 0.1, "suffix:s") var respawn_delay := 4.0

@onready var visuals: Node2D = $Visuals

var state := State.IDLE
var _elapsed := 0.0
var _rest_position := Vector2.ZERO
var _animation: Tween
var _debris: Node2D


func _ready() -> void:
	add_to_group("falling_platforms")
	_rest_position = position
	set_physics_process(false)


func configure_from_tiles(layer: TileMapLayer, cells: Array[Vector2i], ground_tiles: TileSet) -> void:
	position = layer.map_to_local(cells[0])
	var tile_visuals := get_node("Visuals") as Node2D
	for cell in cells:
		var source_id := layer.get_cell_source_id(cell)
		var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
		var atlas_coords := layer.get_cell_atlas_coords(cell)
		var offset := layer.map_to_local(cell) - position
		var texture := AtlasTexture.new()
		texture.atlas = source.texture
		texture.region = source.get_tile_texture_region(atlas_coords)
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.position = offset
		tile_visuals.add_child(sprite)
		# A fase 2 pinta estas mesmas plataformas na camada de perigos,
		# sem poligonos proprios. Usa a geometria de chao do mesmo atlas.
		var collision_source := source
		var collision_tiles := layer.tile_set
		if ground_tiles != null and ground_tiles.has_source(source_id):
			collision_source = ground_tiles.get_source(source_id) as TileSetAtlasSource
			collision_tiles = ground_tiles
		var tile_data := collision_source.get_tile_data(atlas_coords, 0)
		var has_shape := false
		for physics_layer in collision_tiles.get_physics_layers_count():
			if (collision_tiles.get_physics_layer_collision_layer(physics_layer) & 2) == 0:
				continue
			for polygon_index in tile_data.get_collision_polygons_count(physics_layer):
				var shape := CollisionPolygon2D.new()
				shape.position = offset
				shape.polygon = tile_data.get_collision_polygon_points(physics_layer, polygon_index)
				add_child(shape)
				has_shape = true
		if not has_shape:
			var shape := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(layer.tile_set.tile_size)
			shape.position = offset
			shape.shape = rectangle
			add_child(shape)


func start_collapse() -> void:
	if state != State.IDLE:
		return
	state = State.SHAKING
	_elapsed = 0.0
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if state == State.DESTROYED:
		if _elapsed >= respawn_delay:
			reset_platform()
		return
	var progress := clampf(_elapsed / collapse_delay, 0.0, 1.0)
	var strength := lerpf(0.6, 2.5, progress)
	# Apenas a imagem treme; Mario tem apoio estavel durante os 1,5 s.
	visuals.position = Vector2(sin(_elapsed * 65.0) * strength, sin(_elapsed * 83.0) * strength * 0.3)
	visuals.rotation = sin(_elapsed * 55.0) * 0.025 * progress
	if _elapsed >= collapse_delay:
		_begin_fall()


func _begin_fall() -> void:
	state = State.FALLING
	set_physics_process(false)
	visuals.position = Vector2.ZERO
	visuals.rotation = 0.0
	_set_collisions_disabled(true)
	_animation = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_animation.tween_property(self, "position", _rest_position + Vector2(0, fall_distance), fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_animation.tween_callback(_destroy)


func _destroy() -> void:
	visuals.hide()
	_debris = Node2D.new()
	_debris.name = "Debris"
	add_child(_debris)
	_animation = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	for tile in visuals.get_children():
		var sprite := tile as Sprite2D
		var size := sprite.texture.get_size()
		var piece_size := size * 0.5
		for row in 2:
			for column in 2:
				var piece := Sprite2D.new()
				var texture := AtlasTexture.new()
				texture.atlas = sprite.texture
				texture.region = Rect2(Vector2(column, row) * piece_size, piece_size)
				piece.texture = texture
				piece.position = sprite.position - size * 0.5 + Vector2(column + 0.5, row + 0.5) * piece_size
				_debris.add_child(piece)
				var direction := Vector2(randf_range(-28.0, 28.0), randf_range(20.0, 48.0))
				_animation.tween_property(piece, "position", piece.position + direction, destruction_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				_animation.tween_property(piece, "rotation", randf_range(-1.4, 1.4), destruction_duration)
				_animation.tween_property(piece, "scale", Vector2(0.3, 0.3), destruction_duration)
				_animation.tween_property(piece, "modulate:a", 0.0, destruction_duration)
	_animation.chain().tween_callback(_finish_destruction)


func _finish_destruction() -> void:
	state = State.DESTROYED
	_debris.queue_free()
	_debris = null
	_elapsed = 0.0
	set_physics_process(true)


func reset_platform() -> void:
	if _animation != null and _animation.is_valid():
		_animation.kill()
	if is_instance_valid(_debris):
		_debris.queue_free()
	_debris = null
	state = State.IDLE
	_elapsed = 0.0
	position = _rest_position
	visuals.position = Vector2.ZERO
	visuals.rotation = 0.0
	visuals.show()
	_set_collisions_disabled(false)
	set_physics_process(false)


func _set_collisions_disabled(disabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", disabled)
