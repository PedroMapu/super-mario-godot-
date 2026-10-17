extends TileMapLayer

enum Liquid { WATER, LAVA }

@export_group("Animação")
@export var liquid_type: Liquid = Liquid.WATER
@export_range(1.0, 24.0, 0.5, "suffix:fps") var animation_fps := 6.0


func _ready() -> void:
	# Os sprites animam so a imagem; os tiles continuam cuidando da fisica.
	# A copia evita esconder a superficie das outras instancias da fase.
	tile_set = tile_set.duplicate(true)
	var source := tile_set.get_source(0) as TileSetAtlasSource
	var row := 5 if liquid_type == Liquid.WATER else 2
	var frames := SpriteFrames.new()
	frames.rename_animation(&"default", &"flow")
	frames.set_animation_speed(&"flow", animation_fps)
	frames.set_animation_loop(&"flow", true)
	for column in 4:
		var coords := Vector2i(9 + column, row)
		var texture := AtlasTexture.new()
		texture.atlas = source.texture
		texture.region = source.get_tile_texture_region(coords)
		texture.filter_clip = true
		frames.add_frame(&"flow", texture)
		# Transparencia visual nao altera os poligonos de colisao.
		source.get_tile_data(coords, 0).modulate.a = 0.0
	var visuals := Node2D.new()
	visuals.name = "SurfaceAnimation"
	add_child(visuals)
	for cell in get_used_cells():
		var atlas := get_cell_atlas_coords(cell)
		if get_cell_source_id(cell) != 0 or atlas.y != row or atlas.x < 9 or atlas.x > 12:
			continue
		var sprite := AnimatedSprite2D.new()
		sprite.name = "Flow_%d_%d" % [cell.x, cell.y]
		sprite.position = map_to_local(cell)
		sprite.sprite_frames = frames
		visuals.add_child(sprite)
		sprite.play(&"flow")
		# Conserva a fase de cada coluna para as ondas percorrerem a faixa.
		sprite.frame = atlas.x - 9
